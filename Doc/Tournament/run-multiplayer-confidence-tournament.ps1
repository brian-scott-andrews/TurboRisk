param(
  [Parameter(Mandatory = $true)][string]$MasterResults,
  [string]$PlayersDirectory = (Join-Path (Get-Location).Path 'players'),
  [string]$SimulatorSnapshot = (Join-Path $env:TEMP 'trtourney\doomstack_all_sizes_20261014_121421\snapshot'),
  [string]$RunDirectory = '',
  [ValidateSet(2,3,4,5,6,7,8,9,10)][int[]]$PlayerCounts = (2..10),
  [int]$Workers = 24,
  [int]$TimeLimitSeconds = 180,
  [int]$MinimumGamesPerPair = 20,
  [ValidateRange(1, 100)][double]$HalfWidthGoalPercent = 20,
  [int]$SeedBase = 20261026,
  [int]$BatchGamesPerSize = 500,
  [int]$MaxAttempts = 3,
  [string]$FocusBot = '',
  [string[]]$FocusBots = @(),
  [string]$VersionCutoffsFile = '',
  [string]$HistoricalResults = '',
  [int]$RepresentativeGamesPerBotSize = 0,
  [int]$TurnLimit = 0,
  [switch]$StageResults,
  [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
$sizes = @($PlayerCounts | Sort-Object -Unique)
if ($sizes.Count -eq 0) { throw 'At least one player count is required.' }
$z95 = 1.959963984540054
$goal = $HalfWidthGoalPercent / 100
$brainlessVersionCutoff = '20261027110000'
$masterPath = (Resolve-Path $MasterResults).Path
$playersPath = (Resolve-Path $PlayersDirectory).Path
$snapshotPath = (Resolve-Path $SimulatorSnapshot).Path
if ($Workers -lt 1) { throw 'Workers must be at least 1.' }
if ($TimeLimitSeconds -lt 1) { throw 'TimeLimitSeconds must be positive.' }
if ($MinimumGamesPerPair -lt 2) { throw 'MinimumGamesPerPair must be at least 2.' }
if ($BatchGamesPerSize -lt 1) { throw 'BatchGamesPerSize must be positive.' }
if ($MaxAttempts -lt 1) { throw 'MaxAttempts must be positive.' }
if ($RepresentativeGamesPerBotSize -lt 0 -or $TurnLimit -lt 0) { throw 'Sample and turn limits cannot be negative.' }

$bots = @(Get-ChildItem $playersPath -Filter '*.trp' | ForEach-Object BaseName | Sort-Object)
if ($bots.Count -lt 10) { throw "Expected at least 10 current bot files in $playersPath." }
if ($FocusBot -and $FocusBot -notin $bots) { throw "Focus bot '$FocusBot' is not in $playersPath." }
$focus = @($FocusBots)
if ($FocusBot) { $focus += $FocusBot }
$focus = @($focus | Select-Object -Unique)
foreach ($bot in $focus) { if ($bot -notin $bots) { throw "Unknown focus bot: $bot" } }
if ($RepresentativeGamesPerBotSize -gt 0 -and $focus.Count -eq 0) {
  throw 'Representative sampling requires named focus bots.'
}
$versionCutoffs = @{}
if ($VersionCutoffsFile) {
  foreach ($entry in (Import-Csv -LiteralPath $VersionCutoffsFile)) {
    if ($entry.Bot -notin $bots -or $entry.Cutoff -notmatch '^\d{14}$') { throw 'Invalid version cutoff.' }
    $versionCutoffs[$entry.Bot] = $entry.Cutoff
  }
}
$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }

if (-not $RunDirectory) {
  $RunDirectory = Join-Path $env:TEMP ('trtourney\multiplayer_confidence_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
$runPath = [IO.Path]::GetFullPath($RunDirectory)
if (-not $PlanOnly) { New-Item -ItemType Directory -Path $runPath -Force | Out-Null }
$workerRoot = Join-Path $runPath 'workers'
$resultPath = Join-Path $runPath 'results.sgl'
$attemptPath = Join-Path $runPath 'attempts.csv'
$schedulePath = Join-Path $runPath 'schedule.csv'
$progressPath = Join-Path $runPath 'progress.json'
$backupDirectory = Join-Path (Split-Path $masterPath) 'raw_backup'
$masterHash = (Get-FileHash $masterPath -Algorithm SHA256).Hash
if ($StageResults -and -not (Test-Path (Join-Path $runPath 'input-hashes.csv'))) {
  throw 'Staged study requires a frozen input-hashes.csv manifest.'
}
if (-not $PlanOnly -and -not $StageResults) {
  New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
  $masterBackup = Join-Path $backupDirectory ('master_results-before-multiplayer-confidence-{0}.sgl' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Copy-Item $masterPath $masterBackup
  if ((Get-FileHash $masterBackup -Algorithm SHA256).Hash -ne $masterHash) { throw 'Master backup hash verification failed.' }
}

$pairStats = @{}
$newMasterLines = New-Object System.Collections.Generic.List[string]
$masterLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$pairFailures = @{}
$seatCounts = @{}
$representative = @{}
$representativeWins = @{}
$representativeAttempts = @{}
foreach ($size in $sizes) {
  $seatCounts[$size] = @{}
  foreach ($bot in $bots) { $seatCounts[$size][$bot] = New-Object 'int[]' $size }
  foreach ($bot in $focus) {
    $representative["$size|$bot"] = 0
    $representativeWins["$size|$bot"] = 0
    $representativeAttempts["$size|$bot"] = 0
  }
}

function Test-FocusPair([string]$a, [string]$b) {
  return ($focus.Count -eq 0 -or $a -in $focus -or $b -in $focus)
}

function Get-PairKey([int]$size, [string]$first, [string]$second) {
  if ([string]::CompareOrdinal($first, $second) -lt 0) { return "$size|$first|$second" }
  return "$size|$second|$first"
}

function Append-MasterLines([string]$path, [string[]]$lines) {
  for ($attempt = 1; $attempt -le 120; $attempt++) {
    try {
      [IO.File]::AppendAllLines($path, $lines, [Text.Encoding]::ASCII)
      return
    } catch [IO.IOException] {
      if ($attempt -eq 120) { throw }
      Start-Sleep -Seconds 1
    }
  }
}

function Append-RunResultLine([string]$path, [string]$line) {
  for ($attempt = 1; $attempt -le 120; $attempt++) {
    try {
      [IO.File]::AppendAllText($path, ($line + [Environment]::NewLine), [Text.Encoding]::ASCII)
      return
    } catch [System.IO.IOException] {
      if ($attempt -eq 120) { throw }
      Start-Sleep -Seconds 1
    }
  }
}

function Get-WilsonHalfWidth([double]$score, [int]$count) {
  if ($count -le 0) { return 0.5 }
  $z2 = $z95 * $z95
  return ($z95 / ($count + $z2)) * [Math]::Sqrt(($score * ($count - $score) / $count) + ($z2 / 4))
}

function Add-ResultLine([string]$line) {
  $x = $line.Split(',')
  $size = 0
  if ($x.Count -lt 14 -or $x[2] -notin @('1','4') -or
      -not [int]::TryParse($x[5], [ref]$size) -or $size -lt 2 -or $size -gt 10 -or
      $x.Count -lt (6 + 4 * $size)) { return }

  $names = New-Object 'string[]' $size
  $turns = New-Object 'int[]' $size
  for ($i = 0; $i -lt $size; $i++) {
    $names[$i] = $x[6 + 4 * $i]
    $turns[$i] = [int]$x[7 + 4 * $i]
    if ($versionCutoffs.ContainsKey($names[$i]) -and
        ($x[0] + $x[1]) -lt $versionCutoffs[$names[$i]]) {
      $names[$i] += ' pre-current-version'
    }
    if ($x[0] -lt '20261023') {
      if ($names[$i] -eq 'actuary') { return }
      if ($names[$i] -eq 'doomstack') { $names[$i] = 'challenger' }
    }
    if (($x[0] + $x[1]) -lt $brainlessVersionCutoff) {
      if ($names[$i] -eq 'brainless V') { $names[$i] = 'brainless V legacy' }
      if ($names[$i] -eq 'brainless vi') { $names[$i] = 'brainless vi legacy' }
    }
  }
  for ($i = 0; $i -lt $size; $i++) {
    if (-not $botSet.Contains($names[$i])) { continue }
    for ($j = $i + 1; $j -lt $size; $j++) {
      if (-not $botSet.Contains($names[$j])) { continue }
      $key = Get-PairKey $size $names[$i] $names[$j]
      if (-not (Test-FocusPair $names[$i] $names[$j])) { continue }
      if (-not $pairStats.ContainsKey($key)) {
        $pairStats[$key] = [pscustomobject]@{N=0;Score=0.0}
      }
      $score = if ($x[2] -eq '4') { 0.5 }
        elseif ($i -eq 0) { 1.0 }
        elseif ($j -eq 0) { 0.0 }
        elseif ($turns[$i] -gt $turns[$j]) { 1.0 }
        elseif ($turns[$i] -lt $turns[$j]) { 0.0 }
        else { 0.5 }
      if ([string]::CompareOrdinal($names[$i], $names[$j]) -gt 0) { $score = 1.0 - $score }
      $pairStats[$key].N++
      $pairStats[$key].Score += $score
    }
  }
}

function Test-EligibleHistoricalLine([string]$line) {
  $x = $line.Split(',')
  $size = 0
  if ($x.Count -lt 14 -or $x[2] -notin @('1','4') -or
      -not [int]::TryParse($x[5], [ref]$size) -or $size -lt 2 -or $size -gt 10 -or
      $x.Count -lt (6 + 4 * $size)) { return $false }
  for ($i = 0; $i -lt $size; $i++) {
    $bot = $x[6 + 4 * $i]
    if ($x[0] -lt '20261023') {
      if ($bot -eq 'actuary') { return $false }
      if ($bot -eq 'doomstack') { $bot = 'challenger' }
    }
    if (($x[0] + $x[1]) -lt $brainlessVersionCutoff) {
      if ($bot -eq 'brainless V') { $bot = 'brainless V legacy' }
      if ($bot -eq 'brainless vi') { $bot = 'brainless vi legacy' }
    }
    # Old code may still supply evidence for unchanged opponents, not for itself.
    if ($bot -notmatch ' legacy$' -and -not $botSet.Contains($bot)) { return $false }
  }
  return $true
}

foreach ($line in [IO.File]::ReadLines($masterPath)) {
  if (-not $masterLines.Add($line)) { continue }
  if (Test-EligibleHistoricalLine $line) { Add-ResultLine $line }
}

if (Test-Path $resultPath) {
  $stagedLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $stagedPath = Join-Path $runPath 'master-import-pending.sgl'
  if ($StageResults -and (Test-Path $stagedPath)) {
    foreach ($line in [IO.File]::ReadLines($stagedPath)) { [void]$stagedLines.Add($line) }
  }
  foreach ($line in [IO.File]::ReadLines($resultPath)) {
    if ((Test-EligibleHistoricalLine $line) -and $masterLines.Add($line)) {
      Add-ResultLine $line
      if (-not $stagedLines.Contains($line)) { $newMasterLines.Add($line) }
    }
  }
}
if ($HistoricalResults) {
  foreach ($line in [IO.File]::ReadLines((Resolve-Path $HistoricalResults).Path)) {
    if ((Test-EligibleHistoricalLine $line) -and $masterLines.Add($line)) { Add-ResultLine $line }
  }
}
if (Test-Path $attemptPath) {
  foreach ($row in (Import-Csv $attemptPath)) {
    if ($row.Purpose -ne 'representative' -or $row.AnchorBot -notin $focus) { continue }
    $key = "$($row.N)|$($row.AnchorBot)"
    $representativeAttempts[$key]++
    if ($row.Status -eq '1') {
      $representative[$key]++
      if (($row.Line.Split(','))[6] -eq $row.AnchorBot) { $representativeWins[$key]++ }
    }
  }
}

function Get-RequiredGames([int]$count, [double]$score) {
  $target = [Math]::Max($MinimumGamesPerPair, $count)
  $rate = if ($count -gt 0) { $score / $count } else { 0.5 }
  while ((Get-WilsonHalfWidth ($rate * $target) $target) -gt $goal) {
    $target++
    if ($target -gt 100000) { throw 'Confidence target requires more than 100,000 games for a matchup.' }
  }
  return $target
}

function Get-HistoricalRates {
  $samples = @{}
  foreach ($size in $sizes) {
    $samples[$size] = New-Object 'System.Collections.Generic.List[double]'
  }
  $historyRoot = Join-Path $env:TEMP 'trtourney'
  foreach ($attemptFile in (Get-ChildItem $historyRoot -Directory | ForEach-Object {
    Get-ChildItem $_.FullName -Filter 'attempts.csv' -File -ErrorAction SilentlyContinue
  })) {
    if ((Split-Path $attemptFile.DirectoryName -Leaf) -eq (Split-Path $runPath -Leaf)) { continue }
    $validCounts = @{}
    $firstTimes = @{}
    $lastTimes = @{}
    foreach ($row in (Import-Csv $attemptFile.FullName)) {
      $size = 0
      if (-not [int]::TryParse($row.N, [ref]$size) -or $size -lt 2 -or $size -gt 10 -or
          $row.Status -notin @('1','4') -or [string]::IsNullOrWhiteSpace($row.Line)) { continue }
      $fields = $row.Line.Split(',')
      if ($fields.Count -lt 2) { continue }
      $time = [datetime]::MinValue
      if (-not [datetime]::TryParseExact(
        ($fields[0] + $fields[1]), 'yyyyMMddHHmmss',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$time
      )) { continue }
      $validCounts[$size] = [int]$validCounts[$size] + 1
      if (-not $firstTimes.ContainsKey($size) -or $time -lt $firstTimes[$size]) { $firstTimes[$size] = $time }
      if (-not $lastTimes.ContainsKey($size) -or $time -gt $lastTimes[$size]) { $lastTimes[$size] = $time }
    }
    foreach ($size in $sizes) {
      if ([int]$validCounts[$size] -lt 20) { continue }
      $spanMinutes = ($lastTimes[$size] - $firstTimes[$size]).TotalMinutes
      if ($spanMinutes -ge 1) {
        $samples[$size].Add([double]$validCounts[$size] / $spanMinutes)
      }
    }
  }

  $rates = @{}
  foreach ($size in $sizes) {
    if ($samples[$size].Count -gt 0) {
      $sorted = @($samples[$size] | Sort-Object)
      $rates[$size] = [double]$sorted[[int][Math]::Floor(($sorted.Count - 1) / 2)]
    } else {
      $rates[$size] = $Workers * 60 / 28.44
    }
  }
  return $rates
}

$historicalRates = Get-HistoricalRates

function Get-RosterHalfWidth([int]$size, [string[]]$roster) {
  $maxWidth = 0.0
  foreach ($i in 0..($roster.Count - 2)) {
    for ($j = $i + 1; $j -lt $roster.Count; $j++) {
      if (-not (Test-FocusPair $roster[$i] $roster[$j])) { continue }
      $key = Get-PairKey $size $roster[$i] $roster[$j]
      $stat = $pairStats[$key]
      if (-not $stat -or $stat.N -lt $MinimumGamesPerPair) { return 1.0 }
      $score = if ([string]::CompareOrdinal($roster[$i], $roster[$j]) -lt 0) {
        $stat.Score
      } else {
        $stat.N - $stat.Score
      }
      $width = Get-WilsonHalfWidth $score $stat.N
      if ($width -gt $maxWidth) { $maxWidth = $width }
    }
  }
  return $maxWidth
}

function New-Batch([int]$firstId) {
  $rng = New-Object System.Random ($SeedBase + $firstId)
  $batch = New-Object System.Collections.ArrayList
  foreach ($size in $sizes) {
    $remainingTotal = 0
    $count = $bots.Count
    $need = New-Object 'int[,]' $count,$count
    $deficit = New-Object 'int[]' $count
    for ($i = 0; $i -lt $count; $i++) {
      for ($j = $i + 1; $j -lt $count; $j++) {
        if (-not (Test-FocusPair $bots[$i] $bots[$j])) { continue }
        $key = Get-PairKey $size $bots[$i] $bots[$j]
        $stat = $pairStats[$key]
        $seen = if ($stat) { $stat.N } else { 0 }
        $score = if ($stat) { $stat.Score } else { 0.0 }
        $missing = [Math]::Max(0, (Get-RequiredGames $seen $score) - $seen)
        if ($missing -gt 0 -and [int]$pairFailures[$key] -ge 5) {
          throw "Repeated simulator failures for $key; stopping rather than silently claiming its confidence target."
        }
        $need[$i,$j] = $missing
        $need[$j,$i] = $missing
        $deficit[$i] += $missing
        $deficit[$j] += $missing
        $remainingTotal += $missing
      }
    }

    $scheduled = 0
    # Representative games use uniform opponents, not adaptive matchup selection.
    foreach ($bot in $focus) {
      $missing = [Math]::Max(0, $RepresentativeGamesPerBotSize - [int]$representative["$size|$bot"])
      if ($RepresentativeGamesPerBotSize -gt 0 -and
          [int]$representativeAttempts["$size|$bot"] -ge 3 * $RepresentativeGamesPerBotSize -and $missing -gt 0) {
        throw "Too many incomplete representative games for $size|$bot."
      }
      for ($sample = 0; $sample -lt $missing -and $scheduled -lt $BatchGamesPerSize; $sample++) {
        $opponents = @($bots | Where-Object { $_ -ne $bot })
        for ($i = $opponents.Count - 1; $i -gt 0; $i--) {
          $j = $rng.Next($i + 1); $tmp = $opponents[$i]; $opponents[$i] = $opponents[$j]; $opponents[$j] = $tmp
        }
        $rosterNames = @($bot) + @($opponents | Select-Object -First ($size - 1))
        $seat = ([int]$representativeAttempts["$size|$bot"] + $sample) % $size
        $tmp = $rosterNames[0]; $rosterNames[0] = $rosterNames[$seat]; $rosterNames[$seat] = $tmp
        [void]$batch.Add([pscustomobject]@{
          Id=($firstId + $batch.Count); N=$size; Roster=($rosterNames -join ',')
          Map='std_map_small'; MaxPairHalfWidthPercent=0
          Purpose='representative'; AnchorBot=$bot
        })
        for ($i = 0; $i -lt $size; $i++) {
          $a = [array]::IndexOf($bots, $rosterNames[$i])
          $seatCounts[$size][$rosterNames[$i]][$i]++
          for ($j = $i + 1; $j -lt $size; $j++) {
            $b = [array]::IndexOf($bots, $rosterNames[$j])
            if ($need[$a,$b] -gt 0) { $need[$a,$b]--; $need[$b,$a]--; $remainingTotal-- }
          }
        }
        $scheduled++
      }
    }
    while ($remainingTotal -gt 0 -and $scheduled -lt $BatchGamesPerSize) {
      $maxDeficit = 0
      $candidatePairs = New-Object System.Collections.ArrayList
      for ($i = 0; $i -lt $count; $i++) {
        for ($j = $i + 1; $j -lt $count; $j++) {
          if ($need[$i,$j] -gt $maxDeficit) { $maxDeficit = $need[$i,$j]; $candidatePairs.Clear() }
          if ($need[$i,$j] -eq $maxDeficit -and $maxDeficit -gt 0) {
            [void]$candidatePairs.Add(@($i,$j))
          }
        }
      }
      if ($candidatePairs.Count -eq 0) { break }
      $anchor = $candidatePairs[$rng.Next($candidatePairs.Count)]
      $roster = New-Object System.Collections.Generic.List[int]
      $roster.Add([int]$anchor[0]); $roster.Add([int]$anchor[1])
      while ($roster.Count -lt $size) {
        $available = New-Object System.Collections.ArrayList
        $bestCoverage = -1
        $bestDeficit = -1
        for ($i = 0; $i -lt $count; $i++) {
          if ($roster.Contains($i)) { continue }
          $coverage = 0
          $candidateDeficit = 0
          foreach ($member in $roster) {
            if ($need[$i,$member] -gt 0) {
              $coverage++
              $candidateDeficit += $need[$i,$member]
            }
          }
          if ($coverage -gt $bestCoverage -or
              ($coverage -eq $bestCoverage -and $candidateDeficit -gt $bestDeficit)) {
            $bestCoverage = $coverage
            $bestDeficit = $candidateDeficit
            $available.Clear()
          }
          if ($coverage -eq $bestCoverage -and $candidateDeficit -eq $bestDeficit) {
            [void]$available.Add($i)
          }
        }
        $roster.Add([int]$available[$rng.Next($available.Count)])
      }

      $ordered = New-Object System.Collections.Generic.List[string]
      $remaining = New-Object System.Collections.Generic.List[int]
      foreach ($index in $roster) { $remaining.Add($index) }
      for ($seat = 0; $seat -lt $size; $seat++) {
        $minimum = [int]::MaxValue
        foreach ($index in $remaining) {
          $value = $seatCounts[$size][$bots[$index]][$seat]
          if ($value -lt $minimum) { $minimum = $value }
        }
        $choices = New-Object System.Collections.ArrayList
        foreach ($index in $remaining) {
          if ($seatCounts[$size][$bots[$index]][$seat] -eq $minimum) { [void]$choices.Add($index) }
        }
        $selected = [int]$choices[$rng.Next($choices.Count)]
        $ordered.Add($bots[$selected])
        $seatCounts[$size][$bots[$selected]][$seat]++
        [void]$remaining.Remove($selected)
      }

      $rosterNames = [string[]]$ordered.ToArray()
      $width = Get-RosterHalfWidth $size $rosterNames
      if ($width -gt $goal) {
        [void]$batch.Add([pscustomobject]@{
          Id=($firstId + $batch.Count); N=$size; Roster=($rosterNames -join ',')
          Map='std_map_small'; MaxPairHalfWidthPercent=[Math]::Round($width * 100, 2)
          Purpose='coverage'; AnchorBot=''
        })
      }
      for ($i = 0; $i -lt $size; $i++) {
        $a = [array]::IndexOf($bots, $rosterNames[$i])
        for ($j = $i + 1; $j -lt $size; $j++) {
          $b = [array]::IndexOf($bots, $rosterNames[$j])
          if ($need[$a,$b] -gt 0) {
            $need[$a,$b]--; $need[$b,$a]--
            $deficit[$a]--; $deficit[$b]--; $remainingTotal--
          }
        }
      }
      $scheduled++
    }
  }
  # Interleave sizes so large games do not wait for an entire duel batch.
  $interleaved = New-Object System.Collections.ArrayList
  $bySize = @{}
  $maximum = 0
  foreach ($size in $sizes) {
    $bySize[$size] = @($batch | Where-Object N -eq $size)
    if ($bySize[$size].Count -gt $maximum) { $maximum = $bySize[$size].Count }
  }
  for ($round = 0; $round -lt $maximum; $round++) {
    foreach ($size in $sizes) {
      if ($round -lt $bySize[$size].Count) { [void]$interleaved.Add($bySize[$size][$round]) }
    }
  }
  return ,$interleaved
}

function Update-TournamentBotProgress(
  [string]$RunDirectory,
  [string[]]$FocusBot,
  [string]$OutputPath
) {
  if (-not $OutputPath) { $OutputPath = Join-Path $RunDirectory 'index.html' }
  $html = [IO.File]::ReadAllText((Join-Path $RunDirectory 'index.html'))
  $counts = @{}
  $rates = @(Import-Csv (Join-Path $RunDirectory 'representative-win-rates.csv'))
  foreach ($rate in $rates) {
    if ($rate.Bot -notin $FocusBot) { continue }
    $counts["$($rate.Size)|$($rate.Bot)"] = [pscustomobject]@{
      Size=[int]$rate.Size; Bot=$rate.Bot; Completed=0; Wins=0; Losses=0
      Timeouts=0; OtherIncompleteAttempts=0; FinishedAttempts=0
    }
  }
  $attemptPath = Join-Path $RunDirectory 'attempts.csv'
  if (Test-Path -LiteralPath $attemptPath) {
    foreach ($attempt in (Import-Csv -LiteralPath $attemptPath)) {
      foreach ($bot in ($attempt.Roster -split ',')) {
        $key = "$($attempt.N)|$bot"
        if (-not $counts.ContainsKey($key)) { continue }
        $row = $counts[$key]
        $row.FinishedAttempts++
        if ($attempt.Status -eq '1') {
          $row.Completed++
          if (($attempt.Line -split ',')[6] -eq $bot) { $row.Wins++ }
          else { $row.Losses++ }
        } elseif ($attempt.Status -eq '4') { $row.Timeouts++ }
        else { $row.OtherIncompleteAttempts++ }
      }
    }
  }
  $rows = @($counts.Values | Sort-Object Size,Bot)
  $rows | Export-Csv (Join-Path $RunDirectory 'bot-game-progress.csv') -NoTypeInformation
  $section = "<!-- bot-progress-start --><h2>Games played by focus bot (this run)</h2><p>Completed means games with a winner. Timeouts and other incomplete attempts are separate; retries count as separate attempts. Wins are descriptive matchup results, not uniformly sampled win rates.</p>$(($rows | ConvertTo-Html -Fragment) -join '')<!-- bot-progress-end -->"
  $html = [regex]::Replace($html, '(?s)<!-- bot-progress-start -->.*?<!-- bot-progress-end -->', '')
  $heading = '<h2>Representative outright wins (new uniformly sampled rosters only)</h2>'
  if ($html.Contains($heading)) {
    if (@($rates | Where-Object { [int]$_.Target -gt 0 }).Count -eq 0) {
      $html = [regex]::Replace($html, '(?s)<h2>Representative outright wins \(new uniformly sampled rosters only\)</h2>.*?(?=</body>)', '')
      $html = $html.Replace('</body>', "$section</body>")
    } else { $html = $html.Replace($heading, "$section$heading") }
  } else { $html = $html.Replace('</body>', "$section</body>") }
  [IO.File]::WriteAllText($OutputPath, $html)
}

function Write-Progress(
  [int]$batchNumber,
  [int]$gamesDone,
  [int]$gamesPlanned,
  [int]$timeouts,
  [int]$failed,
  [object[]]$batch,
  [hashtable]$batchDoneBySize,
  [int]$gamesPending,
  [int]$gamesRunning
) {
  $widePairs = 0
  $totalPairs = 0
  $widest = 0.0
  $bySize = New-Object 'System.Collections.Generic.List[object]'
  $estimatedTotalMinutes = 0.0
  foreach ($size in $sizes) {
    $sizeWidePairs = 0
    $sizeTotalPairs = 0
    $requiredGameDeficit = 0
    for ($i = 0; $i -lt $bots.Count; $i++) {
      for ($j = $i + 1; $j -lt $bots.Count; $j++) {
        if (-not (Test-FocusPair $bots[$i] $bots[$j])) { continue }
        $totalPairs++
        $sizeTotalPairs++
        $key = Get-PairKey $size $bots[$i] $bots[$j]
        $stat = $pairStats[$key]
        $count = if ($stat) { $stat.N } else { 0 }
        $score = if ($stat) { $stat.Score } else { 0.0 }
        $width = if (-not $stat -or $stat.N -lt $MinimumGamesPerPair) { 1.0 } else {
          Get-WilsonHalfWidth $stat.Score $stat.N
        }
        if ($width -gt $goal) {
          $widePairs++
          $sizeWidePairs++
          $requiredGameDeficit += [Math]::Max(0, (Get-RequiredGames $count $score) - $count)
        }
        if ($width -gt $widest) { $widest = $width }
      }
    }
    $sizeBatchPlanned = @($batch | Where-Object { $_.N -eq $size }).Count
    $sizeBatchDone = [int]$batchDoneBySize[$size]
    $estimatedGames = [int][Math]::Ceiling($requiredGameDeficit / (($size * ($size - 1)) / 2.0))
    $representativeDeficit = 0
    foreach ($bot in $focus) {
      $representativeDeficit += [Math]::Max(0, $RepresentativeGamesPerBotSize - [int]$representative["$size|$bot"])
    }
    $estimatedGames = [Math]::Max($estimatedGames, $representativeDeficit)
    $historicalRate = [double]$historicalRates[$size]
    $etaMinutes = if ($RepresentativeGamesPerBotSize -gt 0) { $null }
    elseif ($estimatedGames -gt 0 -and $historicalRate -gt 0) {
      $estimatedGames / $historicalRate
    } else { 0.0 }
    if ($null -ne $etaMinutes) { $estimatedTotalMinutes += $etaMinutes }
    $bySize.Add([pscustomobject]@{
      N=$size; PairsMeetingTarget=($sizeTotalPairs - $sizeWidePairs)
      TotalPairs=$sizeTotalPairs; PairsAboveTarget=$sizeWidePairs
      BatchGamesCompleted=$sizeBatchDone; BatchGamesPlanned=$sizeBatchPlanned
      BatchGamesPending=[Math]::Max(0, $sizeBatchPlanned - $sizeBatchDone)
      EstimatedGamesRemaining=$estimatedGames
      HistoricalGamesPerMinute=[Math]::Round($historicalRate, 2)
      EtaMinutes=$(if ($null -ne $etaMinutes) { [Math]::Ceiling($etaMinutes) } else { $null })
    })
  }
  $batchGamesCompleted = 0
  foreach ($size in $sizes) { $batchGamesCompleted += [int]$batchDoneBySize[$size] }
  $summary = [pscustomobject]@{
    Batch=$batchNumber; GamesCompleted=$gamesDone; GamesPlanned=$gamesPlanned
    BatchGamesCompleted=$batchGamesCompleted
    GamesPending=$gamesPending; GamesRunning=$gamesRunning
    Timeouts=$timeouts; FailedGames=$failed; PairsMeetingTarget=($totalPairs - $widePairs)
    TotalPairs=$totalPairs; PairsAboveTarget=$widePairs
    BySize=$bySize.ToArray()
    GoalHalfWidthPercent=$HalfWidthGoalPercent
    WidestHalfWidthPercent=[Math]::Round($widest * 100, 2)
    EstimatedRemainingMinutes=$(if ($RepresentativeGamesPerBotSize -gt 0) { $null } else { [Math]::Ceiling($estimatedTotalMinutes) })
    Updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }
  if (-not $PlanOnly) {
    $summary | ConvertTo-Json -Depth 5 | Set-Content $progressPath -Encoding UTF8
    $rates = @(foreach ($size in $sizes) { foreach ($bot in $focus) {
      $key = "$size|$bot"; $completed = [int]$representative[$key]; $attempts = [int]$representativeAttempts[$key]
      $wins = [int]$representativeWins[$key]
      [pscustomobject]@{Size=$size;Bot=$bot;Completed=$completed;Target=$RepresentativeGamesPerBotSize;
        Attempts=$attempts;Wins=$wins;CompletedWinRate=$(if($completed){$wins/$completed}else{$null});
        AllAttemptWinRate=$(if($attempts){$wins/$attempts}else{$null})}
    } })
    $rates | Export-Csv (Join-Path $runPath 'representative-win-rates.csv') -NoTypeInformation
    $html = "<html><head><meta charset='utf-8'><meta http-equiv='refresh' content='30'><title>Current-bot tournament study</title></head><body><h1>Current-bot tournament study</h1><p>Player counts: $($sizes -join ', '). Focus bots: $($focus -join ', '). Updated $($summary.Updated). $Workers isolated workers. Master import pending review. Reused Vexer-focused/alias games supply coverage only, not representative win rates.</p><p>Batch $batchNumber; completed $batchGamesCompleted/$gamesPlanned; running $gamesRunning; pending $gamesPending; timeouts $timeouts; failures $failed.</p><h2>Version-aware pair coverage</h2>$(($bySize|ConvertTo-Html -Fragment)-join '')<h2>Representative outright wins (new uniformly sampled rosters only)</h2>$(($rates|ConvertTo-Html -Fragment)-join '')</body></html>"
    try {
      [IO.File]::WriteAllText((Join-Path $runPath 'index.html'),$html)
      Update-TournamentBotProgress -RunDirectory $runPath -FocusBot $focus
    }
    catch [IO.IOException] { Write-Warning "Dashboard locked; retrying next update: $($_.Exception.Message)" }
  }
  $sizeSummary = ($bySize | ForEach-Object {
    "N=$($_.N):$($_.PairsMeetingTarget)/$($_.TotalPairs) CIs; batch $($_.BatchGamesCompleted)/$($_.BatchGamesPlanned)"
  }) -join '; '
  $etaText = if ($null -eq $summary.EstimatedRemainingMinutes) { 'not estimated' } else { "$($summary.EstimatedRemainingMinutes)m (approximate)" }
  Write-Output ("Batch {0}: finished {1}/{2}; pending {3}; running {4}; timeouts {5}; failed {6}; pairs meeting CI {7}/{8}; widest +/-{9}%; ETA {10}; by size: {11}" -f
    $batchNumber, $batchGamesCompleted, $gamesPlanned, $gamesPending, $gamesRunning, $timeouts, $failed,
    $summary.PairsMeetingTarget, $totalPairs, $summary.WidestHalfWidthPercent,
    $etaText, $sizeSummary)
}

$script:Rng = New-Object System.Random $SeedBase
$batchNumber = 0
$gamesDone = 0
$timeouts = 0
$failedGames = 0
$nextId = 1
if (Test-Path $schedulePath) {
  $scheduledIds = @(Import-Csv $schedulePath | ForEach-Object { [int]$_.Id })
  if ($scheduledIds.Count) { $nextId = ($scheduledIds | Measure-Object -Maximum).Maximum + 1 }
}

while ($true) {
  if ($StageResults) {
    if ((Get-FileHash $masterPath).Hash -ne $masterHash) { throw 'Master changed during staged study.' }
    foreach ($hash in (Import-Csv (Join-Path $runPath 'input-hashes.csv'))) {
      if ((Get-FileHash -LiteralPath $hash.Path).Hash -ne $hash.Hash) { throw "Frozen input changed: $($hash.Path)" }
    }
  }
  if ($newMasterLines.Count -gt 0 -and -not $PlanOnly) {
    $destination = if ($StageResults) { Join-Path $runPath 'master-import-pending.sgl' } else { $masterPath }
    Append-MasterLines $destination ([string[]]$newMasterLines)
    $newMasterLines.Clear()
  }
  $batchNumber++
  $batch = New-Batch $nextId
  if ($batch.Count -eq 0) {
    Write-Output "All player-size pairings meet the minimum sample and approximate 95% Wilson half-width target."
    break
  }
  $nextId += $batch.Count
  if (-not $PlanOnly) { $batch | Export-Csv $schedulePath -NoTypeInformation -Append:(Test-Path $schedulePath) }
  Write-Output ("Batch {0}: planned {1} games ({2})" -f $batchNumber, $batch.Count,
    (($batch | Group-Object N | ForEach-Object { "N=$($_.Name):$($_.Count)" }) -join ', '))

  if ($PlanOnly) {
    Write-Progress $batchNumber 0 $batch.Count 0 0 ([object[]]$batch.ToArray()) @{} $batch.Count 0
    $batch | Select-Object -First 12 | Format-Table Id,N,Roster,MaxPairHalfWidthPercent -AutoSize | Out-String | Write-Output
    break
  }

  $simulator = Join-Path $snapshotPath 'TRSimCLI.exe'
  $snapshotMaps = Join-Path $snapshotPath 'maps'
  $smallMapBitmap = Join-Path $snapshotMaps 'std_map_small.bmp'
  if (-not (Test-Path $simulator)) { throw 'Simulator snapshot is missing TRSimCLI.exe.' }
  if (-not (Test-Path $smallMapBitmap)) { throw 'Simulator snapshot is missing maps\std_map_small.bmp.' }
  $mapFiles = @(Get-ChildItem $snapshotMaps -Filter '*.trm' -File)
  $playerFiles = @(Get-ChildItem $playersPath -Filter '*.trp' -File)
  if ($StageResults -and -not (Test-Path (Join-Path $snapshotPath 'TurboRisk.INI'))) {
    throw 'Staged current-version studies require an explicit frozen INI.'
  }
  if ($mapFiles.Count -eq 0) { throw 'Simulator snapshot contains no .trm maps.' }
  if ($playerFiles.Count -lt 10) { throw "Expected at least 10 player scripts in $playersPath." }

  New-Item -ItemType Directory -Path $workerRoot -Force | Out-Null
  foreach ($i in 0..($Workers - 1)) {
    $dir = Join-Path $workerRoot "w$i"
    $mapsDir = Join-Path $dir 'maps'
    $playersDir = Join-Path $dir 'players'
    New-Item -ItemType Directory -Path $mapsDir, $playersDir -Force | Out-Null
    if (-not (Test-Path (Join-Path $dir 'TRSimCLI.exe'))) {
      Copy-Item $simulator $dir
    }
    foreach ($file in (Get-ChildItem -LiteralPath $snapshotMaps -File)) {
      $target = Join-Path $mapsDir $file.Name
      if (-not (Test-Path $target)) { Copy-Item $file.FullName $target }
    }
    $bitmapTarget = Join-Path $mapsDir 'std_map_small.bmp'
    if (-not (Test-Path $bitmapTarget)) { Copy-Item $smallMapBitmap $bitmapTarget }
    foreach ($file in $playerFiles) {
      $target = Join-Path $playersDir $file.Name
      if (-not (Test-Path $target)) { Copy-Item $file.FullName $target }
    }
    $ini = Join-Path $snapshotPath 'TurboRisk.INI'
    if (Test-Path $ini) { Copy-Item -LiteralPath $ini -Destination (Join-Path $dir 'TurboRisk.INI') -Force }
    if ($StageResults) {
      foreach ($hash in (Import-Csv (Join-Path $runPath 'input-hashes.csv'))) {
        $relative = $hash.Path.Substring(($snapshotPath.TrimEnd('\') + '\').Length)
        if ((Get-FileHash -LiteralPath (Join-Path $dir $relative)).Hash -ne $hash.Hash) {
          throw "Worker input mismatch: $relative"
        }
      }
    }
  }

  $pending = New-Object System.Collections.Queue
  foreach ($game in $batch) { $pending.Enqueue($game) }
  $batchDoneBySize = @{}
  foreach ($size in $sizes) { $batchDoneBySize[$size] = 0 }
  $active = @()
  $lastProgress = Get-Date
  while ($pending.Count -gt 0 -or $active.Count -gt 0) {
    while ($pending.Count -gt 0 -and $active.Count -lt $Workers) {
      $game = $pending.Dequeue()
      $rosterNames = [string[]]($game.Roster -split ',')
      if ($game.Purpose -ne 'representative' -and (Get-RosterHalfWidth $game.N $rosterNames) -le $goal) {
        $gamesDone++
        $batchDoneBySize[$game.N]++
        continue
      }
      $worker = 0
      $used = @($active | ForEach-Object Worker)
      while ($worker -lt $Workers -and $worker -in $used) { $worker++ }
      $dir = Join-Path $workerRoot "w$worker"
      $gameDir = Join-Path $runPath ("game-{0}" -f $game.Id)
      New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
      $scheduleFile = Join-Path $dir 'schedule.csv'
      [IO.File]::WriteAllText($scheduleFile, ($game.Roster + [Environment]::NewLine), [Text.Encoding]::ASCII)
      $attempt = 1
      $seed = $SeedBase + [int]$game.Id * 101 + $attempt * 7
      $logName = "game-$($game.Id)-attempt-$attempt.sgl"
      $arguments = "--schedule schedule.csv --map std_map_small.trm --turn-limit $TurnLimit --time-limit $TimeLimitSeconds --seed $seed --error-dump --game-log $logName --cpu-log game-$($game.Id)-attempt-$attempt.scl --action-log game-$($game.Id)-attempt-$attempt.jsonl"
      $process = Start-Process (Join-Path $dir 'TRSimCLI.exe') -WorkingDirectory $dir `
        -ArgumentList $arguments -RedirectStandardOutput (Join-Path $gameDir "stdout-$attempt.txt") `
        -RedirectStandardError (Join-Path $gameDir "stderr-$attempt.txt") -WindowStyle Hidden -PassThru
      $active += [pscustomobject]@{Worker=$worker;Game=$game;Attempt=$attempt;Seed=$seed;Process=$process;Directory=$dir;GameDirectory=$gameDir;LogName=$logName;Started=(Get-Date)}
    }

    Start-Sleep -Milliseconds 500
    $stillRunning = New-Object System.Collections.ArrayList
    foreach ($job in $active) {
      if (-not $job.Process.HasExited -and ((Get-Date) - $job.Started).TotalSeconds -le ($TimeLimitSeconds + 90)) {
        [void]$stillRunning.Add($job); continue
      }
      if (-not $job.Process.HasExited) {
        Stop-Process -Id $job.Process.Id -Force
        $job.Process.WaitForExit()
      }
      $logPath = Join-Path $job.Directory $job.LogName
      $line = ''
      if (Test-Path $logPath) {
        foreach ($candidate in [IO.File]::ReadLines($logPath)) {
          if ($candidate -match '^\d{8},') { $line = $candidate; break }
        }
      }
      $status = if ($line) { ($line -split ',')[2] } else { 'setup-error' }
      if ($StageResults -and $status -in @('1','4')) {
        $actionPath = Join-Path $job.Directory "game-$($job.Game.Id)-attempt-$($job.Attempt).jsonl"
        $metadata = (Get-Content -LiteralPath $actionPath -TotalCount 1 | ConvertFrom-Json).metadata
        if ($metadata.card_values -ne 1 -or $metadata.assignment -ne 0 -or
            -not $metadata.immediate_trade -or $metadata.map -ne 'std_map_small.trm') {
          throw 'Recorded game rules do not match the approved study.'
        }
      }
      [pscustomobject]@{Id=$job.Game.Id;N=$job.Game.N;Attempt=$job.Attempt;Seed=$job.Seed;Status=$status;Line=$line;Log=$logPath;
        Purpose=$job.Game.Purpose;AnchorBot=$job.Game.AnchorBot;Roster=$job.Game.Roster} |
        Export-Csv $attemptPath -NoTypeInformation -Append
      if ($job.Game.Purpose -eq 'representative') {
        $key = "$($job.Game.N)|$($job.Game.AnchorBot)"
        $representativeAttempts[$key]++
        if ($status -eq '1') {
          $representative[$key]++
          if (($line.Split(','))[6] -eq $job.Game.AnchorBot) { $representativeWins[$key]++ }
        }
      }

      if ($status -in @('1','4') -and (Test-EligibleHistoricalLine $line)) {
        Append-RunResultLine $resultPath $line
        Add-ResultLine $line
        if ($status -eq '4') { $timeouts++ }
        if ($masterLines.Add($line)) { $newMasterLines.Add($line) }
        $gamesDone++
        $batchDoneBySize[$job.Game.N]++
      } elseif ($job.Game.Purpose -ne 'representative' -and $job.Attempt -lt $MaxAttempts) {
        $rotated = New-Object System.Collections.Generic.List[string]
        $original = [string[]]($job.Game.Roster -split ',')
        for ($k = 0; $k -lt $original.Count; $k++) { $rotated.Add($original[($k + $job.Attempt) % $original.Count]) }
        $job.Game.Roster = $rotated -join ','
        $job.Attempt++
        $job.Seed = $SeedBase + [int]$job.Game.Id * 101 + $job.Attempt * 7
        $job.LogName = "game-$($job.Game.Id)-attempt-$($job.Attempt).sgl"
        [IO.File]::WriteAllText((Join-Path $job.Directory 'schedule.csv'),
          ($job.Game.Roster + [Environment]::NewLine), [Text.Encoding]::ASCII)
        $arguments = "--schedule schedule.csv --map std_map_small.trm --turn-limit $TurnLimit --time-limit $TimeLimitSeconds --seed $($job.Seed) --error-dump --game-log $($job.LogName) --cpu-log game-$($job.Game.Id)-attempt-$($job.Attempt).scl --action-log game-$($job.Game.Id)-attempt-$($job.Attempt).jsonl"
        $job.Process = Start-Process (Join-Path $job.Directory 'TRSimCLI.exe') -WorkingDirectory $job.Directory `
          -ArgumentList $arguments -RedirectStandardOutput (Join-Path $job.GameDirectory "stdout-$($job.Attempt).txt") `
          -RedirectStandardError (Join-Path $job.GameDirectory "stderr-$($job.Attempt).txt") -WindowStyle Hidden -PassThru
        $job.Started = Get-Date
        [void]$stillRunning.Add($job)
      } else {
        $failedGames++
        $rosterNames = [string[]]($job.Game.Roster -split ',')
        for ($i = 0; $i -lt $rosterNames.Count; $i++) {
          for ($j = $i + 1; $j -lt $rosterNames.Count; $j++) {
            if (-not (Test-FocusPair $rosterNames[$i] $rosterNames[$j])) { continue }
            $key = Get-PairKey $job.Game.N $rosterNames[$i] $rosterNames[$j]
            $pairFailures[$key] = [int]$pairFailures[$key] + 1
          }
        }
      }
      if ($newMasterLines.Count -ge 100) {
        $destination = if ($StageResults) { Join-Path $runPath 'master-import-pending.sgl' } else { $masterPath }
        Append-MasterLines $destination ([string[]]$newMasterLines)
        $newMasterLines.Clear()
      }
    }
    $active = @($stillRunning.ToArray())
    if (((Get-Date) - $lastProgress).TotalSeconds -ge 30) {
      $lastProgress = Get-Date
      Write-Progress $batchNumber $gamesDone $batch.Count $timeouts $failedGames `
        ([object[]]$batch.ToArray()) $batchDoneBySize $pending.Count $active.Count
    }
  }
  if ($newMasterLines.Count) {
    $destination = if ($StageResults) { Join-Path $runPath 'master-import-pending.sgl' } else { $masterPath }
    Append-MasterLines $destination ([string[]]$newMasterLines)
    $newMasterLines.Clear()
  }
  Write-Progress $batchNumber $gamesDone $batch.Count $timeouts $failedGames `
    ([object[]]$batch.ToArray()) $batchDoneBySize 0 0
}

Write-Output ("Tournament run directory: {0}" -f $runPath)
if (-not $PlanOnly -and $StageResults) {
  if ((Get-FileHash $masterPath).Hash -ne $masterHash) { throw 'Master changed during staged study.' }
  Write-Output 'Study complete. Results staged; master import requires review.'
}
if (-not $PlanOnly -and -not $StageResults) {
  $analysisScript = Join-Path $PSScriptRoot 'run-opponent-overperformance-tournament.ps1'
  if (-not (Test-Path $analysisScript)) { throw "Overperformance analysis script is missing: $analysisScript" }
  $analysisRun = Join-Path $runPath 'overperformance-analysis'
  Write-Output 'Generating descriptive 2-player overperformance analysis from the shared tournament results.'
  & $analysisScript -MasterResults $masterPath -PlayersDirectory $playersPath `
    -SimulatorSnapshot $snapshotPath -RunDirectory $analysisRun -FinalizeOnly
}
