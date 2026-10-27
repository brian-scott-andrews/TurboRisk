param(
  [Parameter(Mandatory=$true)][string]$Run,
  [int]$RefreshSeconds = 5,
  [switch]$Once
)

$ErrorActionPreference = 'Stop'
$runPath = (Resolve-Path $Run).Path
$botPath = Join-Path $runPath 'players'
$bots = @(Get-ChildItem $botPath -Filter '*.trp' | ForEach-Object BaseName)
[Array]::Sort($bots, [StringComparer]::Ordinal)
$z95 = 1.959963984540054
$settings = @{}
foreach ($line in [IO.File]::ReadLines((Join-Path $runPath 'settings.txt'))) {
  $parts = $line.Split('=', 2)
  if ($parts.Count -eq 2) { $settings[$parts[0]] = $parts[1] }
}
$minimumGames = [int]$settings['MinimumGamesPerPair']
$pairGoal = [double]$settings['MatchupHalfWidthPercent'] / 100
$overallGoal = [double]$settings['OverallHalfWidthPercent'] / 100
$seedPath = Join-Path $runPath 'data\seed-results.sgl'
$cumulativePath = Join-Path $runPath 'data\results.sgl'
$round = 0
$previousRound = -1
$previousValid = 0
$previousTime = Get-Date

function Get-PairKey([string]$a, [string]$b) {
  if ([string]::CompareOrdinal($a, $b) -lt 0) { return "$a|$b" }
  return "$b|$a"
}

function Get-WilsonHalfWidth([double]$score, [int]$n) {
  if ($n -le 0) { return 0.5 }
  $z2 = $z95 * $z95
  return ($z95 / ($n + $z2)) * [Math]::Sqrt(($score * ($n - $score) / $n) + ($z2 / 4))
}

function Read-SharedLines([string]$path) {
  $stream = New-Object System.IO.FileStream(
    $path,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read,
    [System.IO.FileShare]::ReadWrite
  )
  try {
    $reader = New-Object System.IO.StreamReader($stream)
    try {
      while (($line = $reader.ReadLine()) -ne $null) { $line }
    } finally {
      $reader.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Add-Results([string]$path, [hashtable]$pairs, [ref]$validCount, [ref]$rowCount) {
  if (-not (Test-Path $path)) { return }
  foreach ($line in (Read-SharedLines $path)) {
    $x = $line.Split(',')
    if ($x.Count -lt 14 -or $x[5] -ne '2') { continue }
    $rowCount.Value++
    if ($x[2] -notin @('1','4')) { continue }
    $first = $x[6]
    $second = $x[10]
    if (-not $botSet.Contains($first) -or -not $botSet.Contains($second) -or $first -eq $second) { continue }
    $validCount.Value++
    $key = Get-PairKey $first $second
    if (-not $pairs.ContainsKey($key)) {
      $names = $key.Split('|')
      $pairs[$key] = [pscustomobject]@{A=$names[0];B=$names[1];N=0;ScoreA=0.0}
    }
    $p = $pairs[$key]
    $p.N++
    if ($x[2] -eq '4') {
      $p.ScoreA += 0.5
    } elseif ($first -eq $p.A) {
      $p.ScoreA++
    }
  }
}

$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }
$previousSeedCount = 0
foreach ($line in (Read-SharedLines $seedPath)) {
  $x = $line.Split(',')
  if ($x.Count -ge 14 -and $x[5] -eq '2' -and $x[2] -in @('1','4')) { $previousSeedCount++ }
}
$sourceSeed = $settings['SeedResults']
$previousRunPath = Join-Path (Split-Path $sourceSeed) 'statistical_2p_precision_20261023_143000'
$previousRound4Results = 0
if (Test-Path $previousRunPath) {
  foreach ($log in (Get-ChildItem $previousRunPath -Directory -Filter 'w*')) {
    $path = Join-Path $log.FullName 'games-round4.sgl'
    if (-not (Test-Path $path)) { continue }
    foreach ($line in (Read-SharedLines $path)) {
      $x = $line.Split(',')
      if ($x.Count -ge 14 -and $x[5] -eq '2' -and $x[2] -in @('1','4')) { $previousRound4Results++ }
    }
  }
}
while ($true) {
  $progress = $null
  $progressPath = Join-Path $runPath 'progress.json'
  if (Test-Path $progressPath) {
    $progress = Get-Content $progressPath -Raw | ConvertFrom-Json
    $round = [int]$progress.Round
  } else {
    $roundDirectories = Get-ChildItem $runPath -Directory -Filter 'round-*' -ErrorAction SilentlyContinue
    foreach ($directory in $roundDirectories) {
      if ($directory.Name -match '^round-(\d+)$') { $round = [Math]::Max($round, [int]$matches[1]) }
    }
  }

  $pairs = @{}
  $validCount = 0
  $activeRows = 0
  Add-Results $seedPath $pairs ([ref]$validCount) ([ref]$activeRows)
  Add-Results $cumulativePath $pairs ([ref]$validCount) ([ref]$activeRows)
  $roundRows = 0
  $roundValid = 0
  if ($round -gt 0) {
    foreach ($workerDir in (Get-ChildItem $runPath -Directory -Filter 'w*')) {
      $logPath = Join-Path $workerDir.FullName "games-round$round.sgl"
      if (-not (Test-Path $logPath)) { continue }
      $beforeValid = $validCount
      $beforeRows = $activeRows
      Add-Results $logPath $pairs ([ref]$validCount) ([ref]$activeRows)
      $roundValid += $validCount - $beforeValid
      $roundRows += $activeRows - $beforeRows
    }
  }

  $matchupsComplete = 0
  $matchupsWide = 0
  $gamesToMinimum = 0
  $widestPair = 0.5
  foreach ($i in 0..($bots.Count - 2)) {
    foreach ($j in (($i + 1)..($bots.Count - 1))) {
      $pair = $pairs[(Get-PairKey $bots[$i] $bots[$j])]
      $n = if ($pair) { $pair.N } else { 0 }
      $half = if ($pair) { Get-WilsonHalfWidth $pair.ScoreA $pair.N } else { 0.5 }
      $widestPair = [Math]::Max($widestPair, $half)
      $gamesToMinimum += [Math]::Max(0, $minimumGames - $n)
      if ($n -ge $minimumGames) {
        if ($half -gt $pairGoal) { $matchupsWide++ } else { $matchupsComplete++ }
      }
    }
  }

  $widestOverall = 0.0
  foreach ($bot in $bots) {
    $variance = 0.0
    foreach ($opponent in $bots) {
      if ($opponent -eq $bot) { continue }
      $pair = $pairs[(Get-PairKey $bot $opponent)]
      if (-not $pair -or $pair.N -eq 0) {
        $half = 0.5
      } else {
        $score = if ($bot -eq $pair.A) { $pair.ScoreA } else { $pair.N - $pair.ScoreA }
        $half = Get-WilsonHalfWidth $score $pair.N
      }
      $variance += ($half / $z95) * ($half / $z95)
    }
    $overallHalf = $z95 * [Math]::Sqrt($variance) / ($bots.Count - 1)
    $widestOverall = [Math]::Max($widestOverall, $overallHalf)
  }

  $now = Get-Date
  $elapsedMinutes = [Math]::Max(0.01, ($now - $previousTime).TotalMinutes)
  $rate = if ($progress) {
    [double]$progress.RatePerMinute
  } elseif ($round -eq $previousRound) {
    [Math]::Max(0, ($roundValid - $previousValid) / $elapsedMinutes)
  } else {
    0
  }
  $schedulePath = Join-Path $runPath "round-$round\schedule.csv"
  $scheduled = if (Test-Path $schedulePath) { @(Import-Csv $schedulePath).Count } else { 0 }
  $remaining = [Math]::Max(0, $scheduled - $roundRows)
  $eta = if ($rate -gt 0) { [Math]::Ceiling($remaining / $rate) } else { 0 }
  $percentage = if ($scheduled -gt 0) { [Math]::Round(100 * $roundRows / $scheduled, 1) } else { 0 }
  $activeWorkers = @(Get-CimInstance Win32_Process -Filter "Name='TRSimCLI.exe'" | Where-Object { $_.ExecutablePath -like "$runPath\w*\TRSimCLI.exe" }).Count

  Clear-Host
  Write-Output 'LIVE ADAPTIVE 2-PLAYER TOURNAMENT'
  Write-Output ("Round: {0} | Active workers: {1} | Updated: {2}" -f $round, $activeWorkers, $now.ToString('yyyy-MM-dd HH:mm:ss'))
  Write-Output ("Previously recovered valid results in seed: {0:N0}" -f $previousSeedCount)
  Write-Output ("Previously completed valid results from interrupted round 4: {0:N0}" -f $previousRound4Results)
  Write-Output ("Current batch: {0:N0}/{1:N0} results ({2}%) | Valid games this round: {3:N0}" -f $roundRows, $scheduled, $percentage, $roundValid)
  Write-Output ("Average valid-game rate: {0:N1}/min | Estimated batch time remaining: {1:N0} min" -f $rate, $eta)
  Write-Output ("Matchups within +/-{0}%: {1:N0}/{2:N0} | Matchups still wider than target: {3:N0} | Games to minimum: {4:N0}" -f $settings['MatchupHalfWidthPercent'], $matchupsComplete, ($bots.Count * ($bots.Count - 1) / 2), $matchupsWide, $gamesToMinimum)
  Write-Output ("Widest matchup interval: +/-{0}% | Widest bot overall interval: +/-{1}% (target +/-{2}%)" -f [Math]::Round(100 * $widestPair, 2), [Math]::Round(100 * $widestOverall, 2), $settings['OverallHalfWidthPercent'])

  $previousValid = $roundValid
  $previousTime = $now
  $previousRound = $round
  if ($Once) { break }
  Start-Sleep -Seconds ([Math]::Max(1, $RefreshSeconds))
}
