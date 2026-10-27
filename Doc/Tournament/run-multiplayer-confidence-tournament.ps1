param(
  [Parameter(Mandatory = $true)][string]$MasterResults,
  [string]$PlayersDirectory = (Join-Path (Get-Location).Path 'players'),
  [string]$SimulatorSnapshot = (Join-Path $env:TEMP 'trtourney\doomstack_all_sizes_20261014_121421\snapshot'),
  [string]$RunDirectory = '',
  [int]$Workers = 24,
  [int]$TimeLimitSeconds = 180,
  [int]$MinimumGamesPerPair = 20,
  [ValidateRange(1, 100)][double]$HalfWidthGoalPercent = 20,
  [int]$SeedBase = 20261026,
  [int]$BatchGamesPerSize = 500,
  [int]$MaxAttempts = 3,
  [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
$sizes = 2..10
$z95 = 1.959963984540054
$goal = $HalfWidthGoalPercent / 100
$masterPath = (Resolve-Path $MasterResults).Path
$playersPath = (Resolve-Path $PlayersDirectory).Path
$snapshotPath = (Resolve-Path $SimulatorSnapshot).Path
if ($Workers -lt 1) { throw 'Workers must be at least 1.' }
if ($TimeLimitSeconds -lt 1) { throw 'TimeLimitSeconds must be positive.' }
if ($MinimumGamesPerPair -lt 2) { throw 'MinimumGamesPerPair must be at least 2.' }
if ($BatchGamesPerSize -lt 1) { throw 'BatchGamesPerSize must be positive.' }
if ($MaxAttempts -lt 1) { throw 'MaxAttempts must be positive.' }

$bots = @(Get-ChildItem $playersPath -Filter '*.trp' | ForEach-Object BaseName | Sort-Object)
if ($bots.Count -lt 10) { throw "Expected at least 10 current bot files in $playersPath." }
$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }

if (-not $RunDirectory) {
  $RunDirectory = Join-Path $env:TEMP ('trtourney\multiplayer_confidence_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null
$runPath = (Resolve-Path $RunDirectory).Path
$workerRoot = Join-Path $runPath 'workers'
$resultPath = Join-Path $runPath 'results.sgl'
$attemptPath = Join-Path $runPath 'attempts.csv'
$schedulePath = Join-Path $runPath 'schedule.csv'
$progressPath = Join-Path $runPath 'progress.json'
$backupDirectory = Join-Path (Split-Path $masterPath) 'raw_backup'
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$masterHash = (Get-FileHash $masterPath -Algorithm SHA256).Hash
$masterBackup = Join-Path $backupDirectory ('master_results-before-multiplayer-confidence-{0}.sgl' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Copy-Item $masterPath $masterBackup
if ((Get-FileHash $masterBackup -Algorithm SHA256).Hash -ne $masterHash) {
  throw 'Master backup hash verification failed.'
}

$pairStats = @{}
$masterLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$pairFailures = @{}
$seatCounts = @{}
foreach ($size in $sizes) {
  $seatCounts[$size] = @{}
  foreach ($bot in $bots) { $seatCounts[$size][$bot] = New-Object 'int[]' $size }
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
    if ($x[0] -lt '20261023') {
      if ($names[$i] -eq 'actuary') { return }
      if ($names[$i] -eq 'doomstack') { $names[$i] = 'challenger' }
    }
  }
  for ($i = 0; $i -lt $size; $i++) {
    if (-not $botSet.Contains($names[$i])) { continue }
    for ($j = $i + 1; $j -lt $size; $j++) {
      if (-not $botSet.Contains($names[$j])) { continue }
      $key = Get-PairKey $size $names[$i] $names[$j]
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
    if (-not $botSet.Contains($bot)) { return $false }
  }
  return $true
}

foreach ($line in [IO.File]::ReadLines($masterPath)) {
  if (-not $masterLines.Add($line)) { continue }
  if (Test-EligibleHistoricalLine $line) { Add-ResultLine $line }
}

if (Test-Path $resultPath) {
  foreach ($line in [IO.File]::ReadLines($resultPath)) {
    if ((Test-EligibleHistoricalLine $line) -and -not $masterLines.Contains($line)) {
      Add-ResultLine $line
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
  $rng = New-Object System.Random ([int](Get-Date -Format 'HHmmss') + $firstId)
  $batch = New-Object System.Collections.ArrayList
  $remainingTotal = 0
  foreach ($size in $sizes) {
    $count = $bots.Count
    $need = New-Object 'int[,]' $count,$count
    $deficit = New-Object 'int[]' $count
    for ($i = 0; $i -lt $count; $i++) {
      for ($j = $i + 1; $j -lt $count; $j++) {
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
        for ($i = 0; $i -lt $count; $i++) { if (-not $roster.Contains($i)) { [void]$available.Add($i) } }
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
  return ,$batch
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
    $historicalRate = [double]$historicalRates[$size]
    $etaMinutes = if ($estimatedGames -gt 0 -and $historicalRate -gt 0) {
      $estimatedGames / $historicalRate
    } else { 0.0 }
    if ($etaMinutes -gt $estimatedTotalMinutes) { $estimatedTotalMinutes = $etaMinutes }
    $bySize.Add([pscustomobject]@{
      N=$size; PairsMeetingTarget=($sizeTotalPairs - $sizeWidePairs)
      TotalPairs=$sizeTotalPairs; PairsAboveTarget=$sizeWidePairs
      BatchGamesCompleted=$sizeBatchDone; BatchGamesPlanned=$sizeBatchPlanned
      BatchGamesPending=[Math]::Max(0, $sizeBatchPlanned - $sizeBatchDone)
      EstimatedGamesRemaining=$estimatedGames
      HistoricalGamesPerMinute=[Math]::Round($historicalRate, 2)
      EtaMinutes=[Math]::Ceiling($etaMinutes)
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
    EstimatedRemainingMinutes=[Math]::Ceiling($estimatedTotalMinutes)
    Updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }
  $summary | ConvertTo-Json | Set-Content $progressPath -Encoding UTF8
  $sizeSummary = ($bySize | ForEach-Object {
    "N=$($_.N):$($_.PairsMeetingTarget)/$($_.TotalPairs) CIs; batch $($_.BatchGamesCompleted)/$($_.BatchGamesPlanned); ETA $($_.EtaMinutes)m"
  }) -join '; '
  Write-Output ("Batch {0}: finished {1}/{2}; pending {3}; running {4}; timeouts {5}; failed {6}; pairs meeting CI {7}/{8}; widest +/-{9}%; ETA <= {10}m; by size: {11}" -f
    $batchNumber, $batchGamesCompleted, $gamesPlanned, $gamesPending, $gamesRunning, $timeouts, $failed,
    $summary.PairsMeetingTarget, $totalPairs, $summary.WidestHalfWidthPercent,
    $summary.EstimatedRemainingMinutes, $sizeSummary)
}

$script:Rng = New-Object System.Random $SeedBase
$newMasterLines = New-Object System.Collections.Generic.List[string]
$batchNumber = 0
$gamesDone = 0
$timeouts = 0
$failedGames = 0
$nextId = 1

while ($true) {
  $batchNumber++
  $batch = New-Batch $nextId
  if ($batch.Count -eq 0) {
    Write-Output "All player-size pairings meet the minimum sample and approximate 95% Wilson half-width target."
    break
  }
  $nextId += $batch.Count
  $batch | Export-Csv $schedulePath -NoTypeInformation -Append:(Test-Path $schedulePath)
  Write-Output ("Batch {0}: planned {1} games ({2})" -f $batchNumber, $batch.Count,
    (($batch | Group-Object N | ForEach-Object { "N=$($_.Name):$($_.Count)" }) -join ', '))

  if ($PlanOnly) {
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
    foreach ($file in $mapFiles) {
      $target = Join-Path $mapsDir $file.Name
      if (-not (Test-Path $target)) { Copy-Item $file.FullName $target }
    }
    $bitmapTarget = Join-Path $mapsDir 'std_map_small.bmp'
    if (-not (Test-Path $bitmapTarget)) { Copy-Item $smallMapBitmap $bitmapTarget }
    foreach ($file in $playerFiles) {
      $target = Join-Path $playersDir $file.Name
      if (-not (Test-Path $target)) { Copy-Item $file.FullName $target }
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
      if ((Get-RosterHalfWidth $game.N $rosterNames) -le $goal) {
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
      $arguments = "--schedule schedule.csv --map std_map_small.trm --turn-limit 0 --time-limit $TimeLimitSeconds --seed $seed --error-dump --game-log $logName --cpu-log game-$($game.Id)-attempt-$attempt.scl"
      $process = Start-Process (Join-Path $dir 'TRSimCLI.exe') -WorkingDirectory $dir `
        -ArgumentList $arguments -RedirectStandardOutput (Join-Path $gameDir "stdout-$attempt.txt") `
        -RedirectStandardError (Join-Path $gameDir "stderr-$attempt.txt") -WindowStyle Hidden -PassThru
      $active += [pscustomobject]@{Worker=$worker;Game=$game;Attempt=$attempt;Seed=$seed;Process=$process;Directory=$dir;GameDirectory=$gameDir;LogName=$logName;Started=(Get-Date)}
    }

    Start-Sleep -Milliseconds 500
    $stillRunning = New-Object System.Collections.ArrayList
    foreach ($job in $active) {
      if (-not $job.Process.HasExited -and ((Get-Date) - $job.Started).TotalSeconds -le ($TimeLimitSeconds + 45)) {
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
      [pscustomobject]@{Id=$job.Game.Id;N=$job.Game.N;Attempt=$job.Attempt;Seed=$job.Seed;Status=$status;Line=$line;Log=$logPath} |
        Export-Csv $attemptPath -NoTypeInformation -Append

      if ($status -in @('1','4') -and (Test-EligibleHistoricalLine $line)) {
        Append-RunResultLine $resultPath $line
        Add-ResultLine $line
        if ($status -eq '4') { $timeouts++ }
        if ($masterLines.Add($line)) { $newMasterLines.Add($line) }
        $gamesDone++
        $batchDoneBySize[$job.Game.N]++
      } elseif ($job.Attempt -lt $MaxAttempts) {
        $rotated = New-Object System.Collections.Generic.List[string]
        $original = [string[]]($job.Game.Roster -split ',')
        for ($k = 0; $k -lt $original.Count; $k++) { $rotated.Add($original[($k + $job.Attempt) % $original.Count]) }
        $job.Game.Roster = $rotated -join ','
        $job.Attempt++
        $job.Seed = $SeedBase + [int]$job.Game.Id * 101 + $job.Attempt * 7
        $job.LogName = "game-$($job.Game.Id)-attempt-$($job.Attempt).sgl"
        [IO.File]::WriteAllText((Join-Path $job.Directory 'schedule.csv'),
          ($job.Game.Roster + [Environment]::NewLine), [Text.Encoding]::ASCII)
        $arguments = "--schedule schedule.csv --map std_map_small.trm --turn-limit 0 --time-limit $TimeLimitSeconds --seed $($job.Seed) --error-dump --game-log $($job.LogName) --cpu-log game-$($job.Game.Id)-attempt-$($job.Attempt).scl"
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
            $key = Get-PairKey $job.Game.N $rosterNames[$i] $rosterNames[$j]
            $pairFailures[$key] = [int]$pairFailures[$key] + 1
          }
        }
      }
      if ($newMasterLines.Count -ge 100) {
        Append-MasterLines $masterPath ([string[]]$newMasterLines)
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
    Append-MasterLines $masterPath ([string[]]$newMasterLines)
    $newMasterLines.Clear()
  }
  Write-Progress $batchNumber $gamesDone $batch.Count $timeouts $failedGames `
    ([object[]]$batch.ToArray()) $batchDoneBySize 0 0
}

Write-Output ("Tournament run directory: {0}" -f $runPath)
if (-not $PlanOnly) {
  $analysisScript = Join-Path $PSScriptRoot 'run-opponent-overperformance-tournament.ps1'
  if (-not (Test-Path $analysisScript)) { throw "Overperformance analysis script is missing: $analysisScript" }
  $analysisRun = Join-Path $runPath 'overperformance-analysis'
  Write-Output 'Generating descriptive 2-player overperformance analysis from the shared tournament results.'
  & $analysisScript -MasterResults $masterPath -PlayersDirectory $playersPath `
    -SimulatorSnapshot $snapshotPath -RunDirectory $analysisRun -FinalizeOnly
}
