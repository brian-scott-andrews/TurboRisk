param(
  [Parameter(Mandatory=$true)][string]$SeedResults,
  [Parameter(Mandatory=$true)][string]$MasterResults,
  [string]$Run = '',
  [string]$PlayersDirectory = '',
  [string]$SimulatorSnapshot = '',
  [int]$Workers = 24,
  [int]$TimeLimit = 180,
  [int]$MinimumGamesPerPair = 20,
  [double]$MatchupHalfWidthPercent = 10,
  [double]$OverallHalfWidthPercent = 3,
  [int]$BatchSize = 20,
  [int]$MaxBatchSize = 40,
  [int]$Seed = 20261023,
  [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
$seedPath = (Resolve-Path $SeedResults).Path
$masterPath = (Resolve-Path $MasterResults).Path
if (-not $PlayersDirectory) { $PlayersDirectory = Join-Path (Get-Location).Path 'players' }
$playersPath = (Resolve-Path $PlayersDirectory).Path
if (-not $SimulatorSnapshot) {
  $SimulatorSnapshot = Join-Path $env:TEMP 'trtourney\doomstack_all_sizes_20261014_121421\snapshot'
}
$snapshotPath = (Resolve-Path $SimulatorSnapshot).Path
if (-not $Run) { $Run = Join-Path $env:TEMP ('trtourney\statistical_2p_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
New-Item -ItemType Directory -Path $Run -Force | Out-Null
$runPath = (Resolve-Path $Run).Path
$workerCount = [Math]::Max(1, $Workers)
$z95 = 1.959963984540054
$pairGoal = $MatchupHalfWidthPercent / 100
$overallGoal = $OverallHalfWidthPercent / 100
$started = Get-Date
$masterHash = (Get-FileHash $masterPath -Algorithm SHA256).Hash
$masterBackup = Join-Path (Split-Path $masterPath) 'raw_backup\master_results-before-statistical-tournament.sgl'
New-Item -ItemType Directory -Force (Split-Path $masterBackup) | Out-Null
if (-not (Test-Path $masterBackup)) { Copy-Item $masterPath $masterBackup }

$bots = @(Get-ChildItem $playersPath -Filter '*.trp' | ForEach-Object BaseName | Sort-Object)
if ($bots.Count -lt 2) { throw "Expected at least two bot files in $playersPath." }
[Array]::Sort($bots, [StringComparer]::Ordinal)
$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }

$dataRoot = Join-Path $runPath 'data'
$mapsRoot = Join-Path $runPath 'maps'
New-Item -ItemType Directory -Path $dataRoot, $mapsRoot -Force | Out-Null
$cumulativeResults = Join-Path $dataRoot 'results.sgl'
$attemptLog = Join-Path $dataRoot 'attempts.sgl'
$script:roundInFlight = $false
$script:activeRound = 0
Copy-Item $seedPath (Join-Path $dataRoot 'seed-results.sgl')
Copy-Item (Join-Path $snapshotPath 'TRSimCLI.exe') $runPath
Copy-Item (Join-Path $snapshotPath 'maps\*.trm') $mapsRoot
Copy-Item (Join-Path $snapshotPath 'maps\std_map_small.bmp') $mapsRoot
New-Item -ItemType Directory -Path (Join-Path $runPath 'players') -Force | Out-Null
Copy-Item (Join-Path $playersPath '*.trp') (Join-Path $runPath 'players') -Force
@(
  "SeedResults=$seedPath"
  "MasterResults=$masterPath"
  "Bots=$($bots.Count)"
  "Workers=$workerCount"
  "TimeLimitSeconds=$TimeLimit"
  "MinimumGamesPerPair=$MinimumGamesPerPair"
  "MatchupHalfWidthPercent=$MatchupHalfWidthPercent"
  "OverallHalfWidthPercent=$OverallHalfWidthPercent"
  "BatchSize=$BatchSize"
  "MaxBatchSize=$MaxBatchSize"
  "Seed=$Seed"
) | Set-Content (Join-Path $runPath 'settings.txt')

function Get-PairKey([string]$a, [string]$b) {
  if ([string]::CompareOrdinal($a, $b) -lt 0) { return "$a|$b" }
  return "$b|$a"
}

function Get-WilsonHalfWidth([double]$score, [int]$n) {
  if ($n -le 0) { return 0.5 }
  $z2 = $z95 * $z95
  $center = ($score + $z2 / 2) / ($n + $z2)
  return ($z95 / ($n + $z2)) * [Math]::Sqrt(($score * ($n - $score) / $n) + ($z2 / 4))
}

function Get-Statistics {
  $pairs = @{}
  $newValidCount = 0
  $sources = @((Join-Path $dataRoot 'seed-results.sgl'), $cumulativeResults)
  foreach ($source in $sources) {
    if (-not (Test-Path $source)) { continue }
    foreach ($line in [IO.File]::ReadLines($source)) {
      $x = $line.Split(',')
      if ($x.Count -lt 14 -or [int]$x[5] -ne 2 -or $x[2] -notin @('1','4')) { continue }
      if ($source -eq $cumulativeResults) { $newValidCount++ }
      $first = $x[6]; $second = $x[10]
      if (-not $botSet.Contains($first) -or -not $botSet.Contains($second) -or $first -eq $second) { continue }
      $key = Get-PairKey $first $second
      if (-not $pairs.ContainsKey($key)) {
        $names = $key.Split('|')
        $pairs[$key] = [pscustomobject]@{A=$names[0];B=$names[1];N=0;ScoreA=0.0;FirstA=0;SecondA=0;HalfWidth=0.5}
      }
      $p = $pairs[$key]
      $p.N++
      if ($first -eq $p.A) {
        $p.FirstA++
        if ($x[2] -eq '4') { $p.ScoreA += 0.5 } else { $p.ScoreA++ }
      } else {
        $p.SecondA++
        if ($x[2] -eq '4') { $p.ScoreA += 0.5 }
      }
    }
  }
  if ($script:roundInFlight) {
    foreach ($workerDir in (Get-ChildItem $runPath -Directory -Filter 'w*')) {
      $log = Join-Path $workerDir.FullName "games-round$script:activeRound.sgl"
      if (-not (Test-Path $log)) { continue }
      foreach ($line in [IO.File]::ReadLines($log)) {
        $x = $line.Split(',')
        if ($x.Count -lt 14 -or [int]$x[5] -ne 2 -or $x[2] -notin @('1','4')) { continue }
        $first = $x[6]; $second = $x[10]
        if (-not $botSet.Contains($first) -or -not $botSet.Contains($second) -or $first -eq $second) { continue }
        $key = Get-PairKey $first $second
        if (-not $pairs.ContainsKey($key)) {
          $names = $key.Split('|')
          $pairs[$key] = [pscustomobject]@{A=$names[0];B=$names[1];N=0;ScoreA=0.0;FirstA=0;SecondA=0;HalfWidth=0.5}
        }
        $p = $pairs[$key]
        $p.N++
        $newValidCount++
        if ($first -eq $p.A) {
          $p.FirstA++
          if ($x[2] -eq '4') { $p.ScoreA += 0.5 } else { $p.ScoreA++ }
        } else {
          $p.SecondA++
          if ($x[2] -eq '4') { $p.ScoreA += 0.5 }
        }
      }
    }
  }
  foreach ($key in @($pairs.Keys)) {
    $p = $pairs[$key]
    $p.HalfWidth = Get-WilsonHalfWidth $p.ScoreA $p.N
  }
  $overall = @{}
  foreach ($bot in $bots) {
    $mean = 0.0
    $variance = 0.0
    $opponents = 0
    foreach ($opponent in $bots) {
      if ($opponent -eq $bot) { continue }
      $key = Get-PairKey $bot $opponent
      $p = $pairs[$key]
      if (-not $p -or $p.N -eq 0) {
        $mean += 0.5
        $variance += (0.5 / $z95) * (0.5 / $z95)
      } else {
        $score = if ($bot -eq $p.A) { $p.ScoreA } else { $p.N - $p.ScoreA }
        $mean += $score / $p.N
        $variance += ($p.HalfWidth / $z95) * ($p.HalfWidth / $z95)
      }
      $opponents++
    }
    $overall[$bot] = [pscustomobject]@{
      Score=$mean / $opponents
      HalfWidth=$z95 * [Math]::Sqrt($variance) / $opponents
    }
  }
  return [pscustomobject]@{Pairs=$pairs;Overall=$overall;NewValidCount=$newValidCount}
}

function Write-ProgressSnapshot([int]$round, [int]$roundScheduled, [int]$running) {
  $stats = Get-Statistics
  $pairsComplete = 0
  $pairLeft = 0
  $minGamesLeft = 0
  $widePairs = 0
  $pairRows = New-Object 'System.Collections.Generic.List[object]'
  foreach ($i in 0..($bots.Count - 1)) {
    if ($i -ge ($bots.Count - 1)) { continue }
    foreach ($j in (($i + 1)..($bots.Count - 1))) {
      $a = $bots[$i]; $b = $bots[$j]; $key = Get-PairKey $a $b
      $p = $stats.Pairs[$key]
      $n = if ($p) { $p.N } else { 0 }
      $half = if ($p) { $p.HalfWidth } else { 0.5 }
      $minGamesLeft += [Math]::Max(0, $MinimumGamesPerPair - $n)
      $needsWidth = $n -ge $MinimumGamesPerPair -and $half -gt $pairGoal
      if ($needsWidth) { $widePairs++ }
      if ($n -ge $MinimumGamesPerPair -and -not $needsWidth) { $pairsComplete++ }
      $left = [Math]::Max(0, $MinimumGamesPerPair - $n)
      if ($n -ge $MinimumGamesPerPair -and $needsWidth) {
        $estimatedN = [Math]::Ceiling($n * [Math]::Pow($half / $pairGoal, 2))
        $left = [Math]::Max($BatchSize, [Math]::Min($MaxBatchSize, $estimatedN - $n))
      }
      $pairLeft += $left
      $pairRows.Add([pscustomobject]@{Pair=$key;Games=$n;Score=if($p -and $p.N){[Math]::Round(100*$p.ScoreA/$p.N,1)}else{50};HalfWidth=([Math]::Round(100*$half,1));Need=[int]$left})
    }
  }
  $overallComplete = @($stats.Overall.Values | Where-Object { $_.HalfWidth -gt $overallGoal }).Count -eq 0
  $allComplete = $minGamesLeft -eq 0 -and $widePairs -eq 0 -and $overallComplete
  $elapsed = [Math]::Max(0.1, ((Get-Date) - $started).TotalMinutes)
  $validNew = $stats.NewValidCount
  $rate = $validNew / $elapsed
  $eta = if ($rate -gt 0) { [Math]::Ceiling($pairLeft / $rate) } else { 0 }
  $overallMax = ($stats.Overall.Values | Measure-Object -Property HalfWidth -Maximum).Maximum
  $state = [pscustomobject]@{
    Round=$round; NewGamesLogged=$validNew; MatchupsComplete=$pairsComplete
    TotalMatchups=($bots.Count * ($bots.Count - 1) / 2)
    MatchupsNeedingPrecision=$widePairs; GamesToMinimum=$minGamesLeft
    EstimatedNextBatch=$roundScheduled; WorkersRunning=$running
    OverallGoalPercent=$OverallHalfWidthPercent; MaxOverallHalfWidthPercent=[Math]::Round(100*$overallMax,2)
    MatchupGoalPercent=$MatchupHalfWidthPercent; MinimumGamesPerPair=$MinimumGamesPerPair
    RatePerMinute=[Math]::Round($rate,1); EtaMinutes=$eta; Complete=$allComplete
    Updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }
  $json = $state | ConvertTo-Json
  $progressJson = Join-Path $runPath 'progress.json'
  $progressTxt = Join-Path $runPath 'progress.txt'
  $tmpJson = "$progressJson.tmp"; $tmpTxt = "$progressTxt.tmp"
  [IO.File]::WriteAllText($tmpJson, $json)
  [IO.File]::WriteAllText($tmpTxt, @(
    'STATISTICALLY PLANNED 2-PLAYER TOURNAMENT'
    ('Updated: {0}   Adaptive round: {1}   Workers running: {2}' -f $state.Updated, $round, $running)
    ('New run games: {0:N0}   Minimum-game top-ups remaining: {1:N0}' -f $validNew, $minGamesLeft)
    ('Matchups within precision goal: {0:N0}/{1:N0}   Still wider than +/-{2}%: {3:N0}' -f $pairsComplete, $state.TotalMatchups, $MatchupHalfWidthPercent, $widePairs)
    ('Overall goal: every bot +/-{0}% over equally weighted opponents   Current widest: +/-{1}%' -f $OverallHalfWidthPercent, $state.MaxOverallHalfWidthPercent)
    ('This batch: {0:N0}   Valid-game rate: {1:N1}/min   Estimated remaining games: {2:N0}' -f $roundScheduled, $rate, $pairLeft)
    ('ETA at current rate: {0:N0} min   Complete: {1}' -f $eta, $allComplete)
    ''
    'Largest remaining matchup intervals (games, score, approximate 95% Wilson half-width):'
  ) -join [Environment]::NewLine)
  foreach ($pair in @(@($tmpJson, $progressJson), @($tmpTxt, $progressTxt))) {
    $replaced = $false
    for ($attempt = 0; $attempt -lt 20 -and -not $replaced; $attempt++) {
      try {
        Move-Item $pair[0] $pair[1] -Force
        $replaced = $true
      } catch [System.IO.IOException] {
        Start-Sleep -Milliseconds 250
      }
    }
    if (-not $replaced) { throw "Could not atomically replace progress file: $($pair[1])" }
  }
  $pairRows | Sort-Object HalfWidth -Descending | Select-Object -First 12 | Export-Csv (Join-Path $runPath 'wide-matchups.csv') -NoTypeInformation
  return [pscustomobject]@{Stats=$stats;State=$state;Complete=$allComplete;PairLeft=$pairLeft}
}

function Add-PhaseResultsToMaster([int]$round, [string[]]$lines) {
  if ((Get-FileHash $masterPath -Algorithm SHA256).Hash -ne $script:masterHash) {
    throw 'The master results changed outside this tournament; refusing to append more results.'
  }
  if ($lines.Count -eq 0) { return }
  $appendable = @($lines | Where-Object {
    $f = $_.Split(',')
    $f.Count -ge 14 -and $f[5] -eq '2' -and $f[2] -in @('1','2','3','4')
  })
  if ($appendable.Count -gt 0) {
    [IO.File]::AppendAllLines($masterPath, [string[]]$appendable)
    $script:masterHash = (Get-FileHash $masterPath -Algorithm SHA256).Hash
  }
}

$round = 0
$lastStatus = $null
while ($true) {
  $stats = Get-Statistics
  $jobs = New-Object 'System.Collections.Generic.List[object]'
  $id = 0
  for ($i = 0; $i -lt $bots.Count; $i++) {
    for ($j = $i + 1; $j -lt $bots.Count; $j++) {
      $a = $bots[$i]; $b = $bots[$j]; $key = Get-PairKey $a $b
      $p = $stats.Pairs[$key]
      $n = if ($p) { $p.N } else { 0 }
      $half = if ($p) { $p.HalfWidth } else { 0.5 }
      $addCount = 0
      if ($n -lt $MinimumGamesPerPair) {
        $addCount = $MinimumGamesPerPair - $n
      } elseif ($half -gt $pairGoal) {
        $estimatedN = [Math]::Ceiling($n * [Math]::Pow($half / $pairGoal, 2))
        $addCount = [Math]::Max($BatchSize, [Math]::Min($MaxBatchSize, $estimatedN - $n))
      }
      if ($addCount -gt 0) {
        $firstA = if ($p) { $p.FirstA } else { 0 }
        $secondA = if ($p) { $p.SecondA } else { 0 }
        $canonicalA = if ($p) { $p.A } else { ($key.Split('|'))[0] }
        $loopAIsCanonical = [string]::CompareOrdinal($a, $canonicalA) -eq 0
        for ($g = 0; $g -lt $addCount; $g++) {
          $canonicalAFirst = if ($firstA -lt $secondA) { $true } elseif ($secondA -lt $firstA) { $false } else { (($g % 2) -eq 0) }
          $loopAFirst = if ($loopAIsCanonical) { $canonicalAFirst } else { -not $canonicalAFirst }
          $roster = if ($loopAFirst) { "$a,$b" } else { "$b,$a" }
          if ($canonicalAFirst) { $firstA++ } else { $secondA++ }
          $id++
          $jobs.Add([pscustomobject]@{Id=$id;Pair=$key;Roster=$roster})
        }
      }
    }
  }
  if ($jobs.Count -eq 0) {
    $snapshot = Write-ProgressSnapshot $round 0 0
    if ($snapshot.Complete) { break }
    throw 'Statistical stopping rules are unmet, but the planner produced no games.'
  }
  $round++
  $script:activeRound = $round
  $roundDir = Join-Path $runPath "round-$round"
  New-Item -ItemType Directory -Path $roundDir -Force | Out-Null
  $roundPath = Join-Path $roundDir 'schedule.csv'
  $jobs | Select-Object Id,Pair,Roster | Export-Csv $roundPath -NoTypeInformation
  if ($PlanOnly) {
    "Plan only: round $round schedules $($jobs.Count) games; output $roundPath"
    break
  }
  $active = New-Object 'System.Collections.Generic.List[object]'
  for ($worker = 0; $worker -lt $workerCount; $worker++) {
    $workerDir = Join-Path $runPath "w$worker"
    New-Item -ItemType Directory -Path (Join-Path $workerDir 'maps'), (Join-Path $workerDir 'players') -Force | Out-Null
    if (-not (Test-Path (Join-Path $workerDir 'TRSimCLI.exe'))) {
      Copy-Item (Join-Path $runPath 'TRSimCLI.exe') $workerDir
      Copy-Item (Join-Path $mapsRoot '*') (Join-Path $workerDir 'maps')
      Copy-Item (Join-Path $runPath 'players\*') (Join-Path $workerDir 'players')
    }
    $mine = @($jobs | Where-Object { ([int]$_.Id % $workerCount) -eq $worker })
    if ($mine.Count -eq 0) { continue }
    $mine | ForEach-Object Roster | Set-Content (Join-Path $workerDir 'schedule.csv') -Encoding ASCII
    $logName = "games-round$round.sgl"
    $args = "--schedule schedule.csv --map std_map_small.trm --turn-limit 0 --time-limit $TimeLimit --seed $($Seed + $round * 1000 + $worker) --game-log $logName --cpu-log cpu-round$round.scl"
    $proc = Start-Process -FilePath (Join-Path $workerDir 'TRSimCLI.exe') -ArgumentList $args -WorkingDirectory $workerDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $workerDir "out-round$round.txt") -RedirectStandardError (Join-Path $workerDir "err-round$round.txt")
    $active.Add([pscustomobject]@{Worker=$worker;Process=$proc})
  }
  $script:roundInFlight = $true
  do {
    Start-Sleep -Seconds 15
    $running = @($active | Where-Object { -not $_.Process.HasExited }).Count
    $lastStatus = Write-ProgressSnapshot $round $jobs.Count $running
  } while ($running -gt 0)
  $script:roundInFlight = $false
  foreach ($item in $active) {
    $item.Process.WaitForExit()
    if ($item.Process.ExitCode -ne 0) { Write-Warning "Worker $($item.Worker) exited with $($item.Process.ExitCode) in round $round." }
  }
  $roundLines = New-Object 'System.Collections.Generic.List[string]'
  foreach ($item in $active) {
    $log = Join-Path (Join-Path $runPath "w$($item.Worker)") "games-round$round.sgl"
    if (Test-Path $log) { foreach ($line in [IO.File]::ReadLines($log)) { $roundLines.Add($line) } }
  }
  if ($roundLines.Count -gt 0) {
    [IO.File]::AppendAllLines($attemptLog, [string[]]$roundLines)
    $accepted = @($roundLines | Where-Object {
      $x = $_.Split(',')
      $x.Count -ge 14 -and $x[5] -eq '2' -and $x[2] -in @('1','4')
    })
    if ($accepted.Count -gt 0) {
      [IO.File]::AppendAllLines($cumulativeResults, [string[]]$accepted)
      Add-PhaseResultsToMaster $round ([string[]]$roundLines)
    }
  }
  $lastStatus = Write-ProgressSnapshot $round $jobs.Count 0
}

if ($PlanOnly) { return }
$final = $lastStatus.State
$final | ConvertTo-Json | Set-Content (Join-Path $runPath 'final-summary.json')
@(
  'Statistical stopping rules met.'
  ('95% approximate Wilson half-width target per head-to-head: ±{0} percentage points' -f $MatchupHalfWidthPercent)
  ('95% approximate overall half-width target per bot (equal weight per opponent): ±{0} percentage points' -f $OverallHalfWidthPercent)
  ('Minimum games per pair: {0}' -f $MinimumGamesPerPair)
  ('New valid games from this run: {0}' -f $final.NewGamesLogged)
) | Set-Content (Join-Path $runPath 'result-summary.txt')
[IO.File]::WriteAllText((Join-Path $runPath 'progress.txt'), ("STATISTICAL STOPPING RULES MET`n" + (Get-Content (Join-Path $runPath 'result-summary.txt') -Raw)))
Get-Content (Join-Path $runPath 'result-summary.txt')
