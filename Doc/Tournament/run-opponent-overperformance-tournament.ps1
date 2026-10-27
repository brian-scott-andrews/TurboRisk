param(
  [Parameter(Mandatory=$true)][string]$MasterResults,
  [string]$PlayersDirectory = (Join-Path (Get-Location).Path 'players'),
  [string]$SimulatorSnapshot = (Join-Path $env:TEMP 'trtourney\doomstack_all_sizes_20261014_121421\snapshot'),
  [string]$RunDirectory = '',
  [int]$SeedBase = (Get-Date -Format 'yyyyMMdd'),
  [string[]]$BaselineBots = @(),
  [int]$MinimumBaselineGames = 25,
  [int]$TimeLimitSeconds = 180,
  [int]$GamesPerCheckpoint = 25,
  [int]$MaximumNewGamesPerPair = 500,
  [int]$MaximumAttempts = 3,
  [string]$ReportDirectory = $PSScriptRoot,
  [switch]$FinalizeOnly,
  [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
$familyConfidence = 0.95
$powerTarget = 0.90
$minimumLift = 0.15
$masterPath = (Resolve-Path $MasterResults).Path
$playersPath = (Resolve-Path $PlayersDirectory).Path
$snapshotPath = (Resolve-Path $SimulatorSnapshot).Path
if ($GamesPerCheckpoint -lt 1) { throw 'GamesPerCheckpoint must be positive.' }
if ($MaximumNewGamesPerPair -lt $GamesPerCheckpoint) { throw 'MaximumNewGamesPerPair must be at least one checkpoint.' }
if (($MaximumNewGamesPerPair % $GamesPerCheckpoint) -ne 0) { throw 'MaximumNewGamesPerPair must be divisible by GamesPerCheckpoint.' }
if ($MaximumAttempts -lt 1) { throw 'MaximumAttempts must be positive.' }
if ($MinimumBaselineGames -lt $GamesPerCheckpoint -or ($MinimumBaselineGames % $GamesPerCheckpoint) -ne 0) {
  throw 'MinimumBaselineGames must be a positive multiple of GamesPerCheckpoint.'
}

function Append-MasterLine([string]$path, [string]$line) {
  for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
      [IO.File]::AppendAllText($path, ($line + [Environment]::NewLine), [Text.Encoding]::ASCII)
      return
    } catch [IO.IOException] {
      if ($attempt -eq 40) { throw }
      Start-Sleep -Milliseconds 250
    }
  }
}

function Copy-MasterSnapshot([string]$source, [string]$destination) {
  for ($attempt = 1; $attempt -le 40; $attempt++) {
    try {
      Copy-Item -LiteralPath $source -Destination $destination -Force
      return
    } catch [IO.IOException] {
      if ($attempt -eq 40) { throw }
      Start-Sleep -Milliseconds 250
    }
  }
}

function Read-SharedLines([string]$path) {
  $stream = New-Object System.IO.FileStream(
    $path,
    [IO.FileMode]::Open,
    [IO.FileAccess]::Read,
    [IO.FileShare]::ReadWrite
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

$bots = @(Get-ChildItem $playersPath -Filter '*.trp' | ForEach-Object BaseName)
[Array]::Sort($bots, [StringComparer]::Ordinal)
if ($bots.Count -lt 2) { throw "Expected at least two player files in $playersPath." }
$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }

if (-not $RunDirectory) {
  $RunDirectory = Join-Path $env:TEMP ('trtourney\opponent_overperformance_2p_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null
$runPath = (Resolve-Path $RunDirectory).Path
$dataPath = Join-Path $runPath 'data'
$workerPath = Join-Path $runPath 'worker'
$mapsPath = Join-Path $workerPath 'maps'
$playerPath = Join-Path $workerPath 'players'
New-Item -ItemType Directory -Path $dataPath, $mapsPath, $playerPath -Force | Out-Null
$baselinePath = Join-Path $dataPath 'baseline-master.sgl'
$resultsPath = Join-Path $dataPath 'results.sgl'
$attemptsPath = Join-Path $dataPath 'attempts.csv'
$progressPath = Join-Path $runPath 'progress.json'
$schedulePath = Join-Path $runPath 'schedule.csv'
Copy-MasterSnapshot $masterPath $baselinePath
if (-not $PlanOnly -and -not $FinalizeOnly) {
  Copy-Item (Join-Path $snapshotPath 'TRSimCLI.exe') $workerPath -Force
  Copy-Item (Join-Path $snapshotPath 'maps\*.trm') $mapsPath -Force
  Copy-Item (Join-Path $snapshotPath 'maps\std_map_small.bmp') $mapsPath -Force
  Copy-Item (Join-Path $playersPath '*.trp') $playerPath -Force
}

$pairStats = @{}
$masterLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$completedGames = 0
$timeouts = 0
$failedGames = 0
$gameId = 0
$timeoutLimitMilliseconds = ($TimeLimitSeconds + 45) * 1000
$nextId = 1
$pairCount = $bots.Count * ($bots.Count - 1) / 2
$directionCount = $bots.Count * ($bots.Count - 1)
$checkpointCount = [int]($MaximumNewGamesPerPair / $GamesPerCheckpoint)
$testLooks = $checkpointCount + 1
$alphaPerLook = (1.0 - $familyConfidence) / ($directionCount * $testLooks)

function Get-PairKey([string]$a, [string]$b) {
  if ([string]::CompareOrdinal($a, $b) -lt 0) { return "$a|$b" }
  return "$b|$a"
}

function Get-NormalQuantile([double]$p) {
  $a = @(-39.6968302866538,220.946098424521,-275.928510446969,138.357751867269,-30.6647980661472,2.50662827745924)
  $b = @(-54.4760987982241,161.585836858041,-155.698979859887,66.8013118877197,-13.2806815528857)
  $c = @(-0.00778489400243029,-0.322396458041136,-2.40075827716184,-2.54973253934373,4.37466414146497,2.93816398269878)
  $d = @(0.00778469570904146,0.32246712907004,2.445134137143,3.75440866190742)
  $low = 0.02425
  $high = 1.0 - $low
  if ($p -le 0 -or $p -ge 1) { throw 'Normal quantile probability must be between zero and one.' }
  if ($p -lt $low) {
    $q = [Math]::Sqrt(-2.0 * [Math]::Log($p))
    return (((((($c[0]*$q+$c[1])*$q+$c[2])*$q+$c[3])*$q+$c[4])*$q+$c[5]) /
      (((($d[0]*$q+$d[1])*$q+$d[2])*$q+$d[3])*$q+1.0))
  }
  if ($p -gt $high) {
    $q = [Math]::Sqrt(-2.0 * [Math]::Log(1.0-$p))
    return -(((((($c[0]*$q+$c[1])*$q+$c[2])*$q+$c[3])*$q+$c[4])*$q+$c[5]) /
      (((($d[0]*$q+$d[1])*$q+$d[2])*$q+$d[3])*$q+1.0))
  }
  $q = $p - 0.5
  $r = $q * $q
  return (((((($a[0]*$r+$a[1])*$r+$a[2])*$r+$a[3])*$r+$a[4])*$r+$a[5])*$q) /
    (((((($b[0]*$r+$b[1])*$r+$b[2])*$r+$b[3])*$r+$b[4])*$r)+1.0)
}

$zCritical = Get-NormalQuantile (1.0 - $alphaPerLook)

function Add-ResultLine([string]$line, [bool]$isHistorical) {
  $x = $line.Split(',')
  if ($x.Count -lt 14 -or $x[5] -ne '2' -or $x[2] -notin @('1','4')) { return }
  $a = $x[6]; $b = $x[10]
  if ($x[0] -lt '20261023') {
    if ($a -eq 'actuary' -or $b -eq 'actuary') { return }
    if ($a -eq 'doomstack') { $a = 'challenger' }
    if ($b -eq 'doomstack') { $b = 'challenger' }
  }
  if (-not $botSet.Contains($a) -or -not $botSet.Contains($b) -or $a -eq $b) { return }
  $key = Get-PairKey $a $b
  if (-not $pairStats.ContainsKey($key)) {
    $names = $key.Split('|')
    $pairStats[$key] = [pscustomobject]@{
      A=$names[0]; B=$names[1]; N=0; ScoreA=0.0; ScoreSquaresA=0.0
      FirstA=0; SecondA=0; NewGames=0; SignificantA=$false; SignificantB=$false
      TestedA=$false; TestedB=$false; SignalA=$null; SignalB=$null
    }
  }
  $p = $pairStats[$key]
  $score = if ($x[2] -eq '4') { 0.5 } elseif ($a -eq $p.A) { 1.0 } else { 0.0 }
  $p.N++
  $p.ScoreA += $score
  $p.ScoreSquaresA += $score * $score
  if ($a -eq $p.A) { $p.FirstA++ } else { $p.SecondA++ }
  if (-not $isHistorical) { $p.NewGames++ }
}

foreach ($line in [IO.File]::ReadLines($baselinePath)) {
  if (-not $masterLines.Add($line)) { continue }
  Add-ResultLine $line $true
}
foreach ($a in $bots) {
  foreach ($b in $bots) {
    if ([string]::CompareOrdinal($a, $b) -lt 0) {
      $key = Get-PairKey $a $b
      if (-not $pairStats.ContainsKey($key)) {
        $pairStats[$key] = [pscustomobject]@{
          A=$a; B=$b; N=0; ScoreA=0.0; ScoreSquaresA=0.0
          FirstA=0; SecondA=0; NewGames=0; SignificantA=$false; SignificantB=$false
          TestedA=$false; TestedB=$false; SignalA=$null; SignalB=$null
        }
      }
    }
  }
}

function Get-Rate([string]$bot, [string]$opponent, [ref]$variance) {
  $sum = 0.0
  $varianceSum = 0.0
  $count = 0
  foreach ($other in $bots) {
    if ($other -eq $bot -or $other -eq $opponent) { continue }
    $pair = $pairStats[(Get-PairKey $bot $other)]
    if (-not $pair -or $pair.N -eq 0) { continue }
    $score = if ($bot -eq $pair.A) { $pair.ScoreA } else { $pair.N - $pair.ScoreA }
    $squares = if ($bot -eq $pair.A) { $pair.ScoreSquaresA } else { $pair.N - 2.0*$pair.ScoreA + $pair.ScoreSquaresA }
    $rate = $score / $pair.N
    $sampleVariance = if ($pair.N -gt 1) {
      [Math]::Max(0.0, ($squares - $pair.N*$rate*$rate) / ($pair.N - 1))
    } else { 0.25 }
    $sum += $rate
    $varianceSum += $sampleVariance / $pair.N
    $count++
  }
  if ($count -eq 0) { throw "No baseline matchups are available for $bot." }
  $variance.Value = $varianceSum / ($count * $count)
  return $sum / $count
}

$zPower = -1.2815515655446004
function Get-RequiredGames([string]$bot, [string]$opponent, [int]$currentGames) {
  $baseVariance = 0.0
  $baseline = Get-Rate $bot $opponent ([ref]$baseVariance)
  $alternative = $baseline + $minimumLift
  if ($alternative -ge 1.0) { return [pscustomobject]@{Games=[int]::MaxValue;Baseline=$baseline} }
  $availableVariance = [Math]::Pow($minimumLift / ($zCritical + [Math]::Abs($zPower)), 2) - $baseVariance
  if ($availableVariance -le 0) { return [pscustomobject]@{Games=[int]::MaxValue;Baseline=$baseline} }
  $required = [int][Math]::Ceiling(($alternative * (1.0 - $alternative)) / $availableVariance)
  return [pscustomobject]@{Games=[Math]::Max($currentGames, $required);Baseline=$baseline}
}

function Get-Signal([string]$bot, [string]$opponent) {
  $pair = $pairStats[(Get-PairKey $bot $opponent)]
  if (-not $pair -or $pair.N -lt 2) { return [pscustomobject]@{Significant=$false;Z=0.0;Rate=0.0;Baseline=0.0;Lift=0.0} }
  $score = if ($bot -eq $pair.A) { $pair.ScoreA } else { $pair.N - $pair.ScoreA }
  $squares = if ($bot -eq $pair.A) { $pair.ScoreSquaresA } else { $pair.N - 2.0*$pair.ScoreA + $pair.ScoreSquaresA }
  $rate = $score / $pair.N
  $sampleVariance = if ($pair.N -gt 1) {
    [Math]::Max(0.0, ($squares - $pair.N*$rate*$rate) / ($pair.N - 1))
  } else { 0.25 }
  $baseVariance = 0.0
  $baseline = Get-Rate $bot $opponent ([ref]$baseVariance)
  $standardError = [Math]::Sqrt(($sampleVariance / $pair.N) + $baseVariance)
  $z = if ($standardError -gt 0) { ($rate - $baseline) / $standardError } elseif ($rate -gt $baseline) { [double]::PositiveInfinity } else { 0.0 }
  return [pscustomobject]@{
    Significant=($rate - $baseline -gt ($zCritical * $standardError))
    Z=$z; Rate=$rate; Baseline=$baseline; Lift=($rate-$baseline)
  }
}

function Test-Pair([object]$pair, [switch]$Initial) {
  if ($Initial) {
    if ($pair.N -lt 2) { return }
  } elseif ($pair.NewGames -lt $GamesPerCheckpoint -or ($pair.NewGames % $GamesPerCheckpoint) -ne 0) {
    return
  }
  $aSignal = Get-Signal $pair.A $pair.B
  $bSignal = Get-Signal $pair.B $pair.A
  $pair.TestedA = $true
  $pair.TestedB = $true
  $pair.SignalA = $aSignal
  $pair.SignalB = $bSignal
  $pair.SignificantA = $aSignal.Significant
  $pair.SignificantB = $bSignal.Significant
}

function Write-Progress {
  $testedDirections = 0
  $significantDirections = 0
  $activePairs = 0
  foreach ($pair in $pairStats.Values) {
    if ($pair.TestedA) { $testedDirections++; if ($pair.SignificantA) { $significantDirections++ } }
    if ($pair.TestedB) { $testedDirections++; if ($pair.SignificantB) { $significantDirections++ } }
    if (-not ($pair.SignificantA -or $pair.SignificantB) -and $pair.NewGames -lt $MaximumNewGamesPerPair) { $activePairs++ }
  }
  $state = [pscustomobject]@{
    CompletedGames=$completedGames; Timeouts=$timeouts; FailedGames=$failedGames
    Pairings=$pairCount; SignificantPairings=(@($pairStats.Values | Where-Object { $_.SignificantA -or $_.SignificantB }).Count)
    SignificantDirections=$significantDirections; TestedDirections=$testedDirections
    ActivePairings=$activePairs; MaxNewGamesPerPair=$MaximumNewGamesPerPair
    MinLiftPercentagePoints=($minimumLift*100); PowerTargetPercentage=($powerTarget*100)
    FamilyConfidencePercentage=($familyConfidence*100); Workers=1
    Updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }
  $state | ConvertTo-Json | Set-Content $progressPath -Encoding UTF8
  Write-Output ("Games {0:N0} | significant pairings {1:N0}/{2:N0} | active pairings {3:N0} | failed {4:N0}" -f
    $completedGames, $state.SignificantPairings, $pairCount, $activePairs, $failedGames)
}

function Invoke-ScheduledGame([int]$id, [string]$initialRoster) {
  $rosterNames = [string[]]($initialRoster -split ',')
  $schedule = Join-Path $workerPath 'schedule.csv'
  [IO.File]::WriteAllText($schedule, ($initialRoster + [Environment]::NewLine), [Text.Encoding]::ASCII)
  $attempt = 1
  $line = ''
  $seed = 0
  $gameLog = ''
  while ($attempt -le $MaximumAttempts -and -not $line) {
    $seed = $SeedBase + ($id * 101) + ($attempt * 7)
    $logName = "game-$id-attempt-$attempt.sgl"
    $cpuName = "game-$id-attempt-$attempt.scl"
    $stdout = Join-Path $runPath "stdout-$id-$attempt.txt"
    $stderr = Join-Path $runPath "stderr-$id-$attempt.txt"
    $cpuLog = Join-Path $workerPath $cpuName
    $arguments = "--schedule schedule.csv --map std_map_small.trm --turn-limit 0 --time-limit $TimeLimitSeconds --seed $seed --game-log $logName --cpu-log $cpuName"
    $proc = Start-Process -FilePath (Join-Path $workerPath 'TRSimCLI.exe') -ArgumentList $arguments `
      -WorkingDirectory $workerPath -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $proc.WaitForExit($timeoutLimitMilliseconds)) {
      Stop-Process -Id $proc.Id -Force
      $proc.WaitForExit()
    }
    $gameLog = Join-Path $workerPath $logName
    if (Test-Path $gameLog) {
      foreach ($candidate in [IO.File]::ReadAllLines($gameLog)) {
        if ($candidate -match '^\d{8},' -and ($candidate.Split(',')[2] -in @('1','4'))) {
          $line = $candidate
          break
        }
      }
      if ($line) {
        foreach ($temporaryFile in @($gameLog, $cpuLog, $stdout, $stderr)) {
          if (Test-Path $temporaryFile) { Remove-Item -LiteralPath $temporaryFile -Force }
        }
      }
    }
    [pscustomobject]@{
      Id=$id; Pair=(Get-PairKey $rosterNames[0] $rosterNames[1]); Attempt=$attempt
      Seed=$seed; Status=if($line){($line.Split(',')[2])}else{'failed'}
      Line=$line; Log=$gameLog
    } | Export-Csv $attemptsPath -NoTypeInformation -Append
    if (-not $line) {
      $attempt++
      [array]::Reverse($rosterNames)
      [IO.File]::WriteAllText($schedule, (($rosterNames -join ',') + [Environment]::NewLine), [Text.Encoding]::ASCII)
    }
  }
  if (-not $line) {
    $script:failedGames++
    Write-Progress
    throw "Game $id failed after $MaximumAttempts attempts; stopping to avoid undercounting the planned sample."
  }
  return [pscustomobject]@{Line=$line;Seed=$seed;Attempt=$attempt;Log=$gameLog}
}

$allPairs = @($pairStats.Values | Sort-Object A,B)
if ($BaselineBots.Count -gt 0 -and -not $FinalizeOnly -and -not $PlanOnly) {
  foreach ($baselineBot in $BaselineBots) {
    if (-not $botSet.Contains($baselineBot)) { throw "Baseline bot '$baselineBot' is not in $playersPath." }
    Write-Output "Calibrating baseline coverage for $baselineBot against its opponents."
    foreach ($opponent in $bots) {
      if ($opponent -eq $baselineBot) { continue }
      $pair = $pairStats[(Get-PairKey $baselineBot $opponent)]
      while ($pair.N -lt $MinimumBaselineGames) {
        $gameId++
        $aFirst = $pair.FirstA -le $pair.SecondA
        $roster = if ($aFirst) { "$($pair.A),$($pair.B)" } else { "$($pair.B),$($pair.A)" }
        $result = Invoke-ScheduledGame $gameId $roster
        if ($masterLines.Add($result.Line)) { Append-MasterLine $masterPath $result.Line }
        [IO.File]::AppendAllText($resultsPath, ($result.Line + [Environment]::NewLine), [Text.Encoding]::ASCII)
        Add-ResultLine $result.Line $false
        $completedGames++
        if (($result.Line.Split(',')[2]) -eq '4') { $timeouts++ }
        if (($completedGames % 25) -eq 0) { Write-Progress }
      }
      Write-Output ("Baseline {0} vs {1}: {2}/{3} games." -f $baselineBot,$opponent,$pair.N,$MinimumBaselineGames)
    }
  }
}
if (-not $FinalizeOnly) {
  foreach ($pair in $allPairs) { Test-Pair $pair -Initial }
}
$maxGames = 0
$powerGames = 0
$powerNotAchievable = 0
$initialSignificantPairings = 0
foreach ($pair in $allPairs) {
  if ($pair.SignificantA -or $pair.SignificantB) {
    $initialSignificantPairings++
    continue
  }
  $aPower = Get-RequiredGames $pair.A $pair.B $pair.N
  $bPower = Get-RequiredGames $pair.B $pair.A $pair.N
  $pairPowerGames = 0
  foreach ($estimate in @($aPower, $bPower)) {
    if ($estimate.Games -eq [int]::MaxValue) { $powerNotAchievable++ }
    else {
      $needed = [Math]::Max(0, $estimate.Games - $pair.N)
      $pairPowerGames = [Math]::Max($pairPowerGames, [int]([Math]::Ceiling($needed / $GamesPerCheckpoint) * $GamesPerCheckpoint))
    }
  }
  $powerGames += $pairPowerGames
  $maxGames += $MaximumNewGamesPerPair
}
$historicalMeanSeconds = 28.44
$maxEtaDays = [Math]::Ceiling(($maxGames * $historicalMeanSeconds) / 86400)
@(
  "MasterResults=$masterPath"
  "PlayersDirectory=$playersPath"
  "Workers=1"
  "FamilyConfidencePercent=$($familyConfidence*100)"
  "MinimumLiftPercentagePoints=$($minimumLift*100)"
  "PowerTargetPercent=$($powerTarget*100)"
  "MaximumNewGamesPerPair=$MaximumNewGamesPerPair"
  "EstimatedGamesFor90PercentPower=$powerGames"
  "DirectionsWithoutAttainable15PointPower=$powerNotAchievable"
  "InitiallySignificantPairings=$initialSignificantPairings"
  "GamesPerCheckpoint=$GamesPerCheckpoint"
  "DirectionalHypotheses=$directionCount"
  "SequentialLooks=$testLooks"
  "AlphaPerLook=$alphaPerLook"
  "ZCritical=$zCritical"
  "EstimatedMaximumGames=$maxGames"
  "EstimatedMaximumDaysAtHistoricalMean=$maxEtaDays"
) | Set-Content (Join-Path $runPath 'settings.txt')
$allPairs | Select-Object A,B,N,NewGames,SignificantA,SignificantB |
  Export-Csv $schedulePath -NoTypeInformation

if ($PlanOnly) {
  Write-Output ("Plan only: {0} bot pairings, {1} directional tests, {2} historically significant pairings skipped; up to {3} new games per remaining pairing." -f
    $pairCount, $directionCount, $initialSignificantPairings, $MaximumNewGamesPerPair)
  Write-Output ("Worst-case additional games: {0:N0}; one-worker ETA at historical mean: about {1} days." -f $maxGames, $maxEtaDays)
  Write-Output ("Normal-approximation planning estimate for 90% power at a 15 pp lift: {0:N0} additional games across both directions; {1} directions have no feasible 15 pp alternative." -f $powerGames, $powerNotAchievable)
  Write-Output ("Family-wise confidence: {0}% across all directional tests and {1} prespecified looks; target lift {2} pp at {3}% power." -f
    ($familyConfidence*100), $testLooks, ($minimumLift*100), ($powerTarget*100))
  if ($powerGames -gt ($pairCount * $MaximumNewGamesPerPair) -or $powerNotAchievable -gt 0) {
    Write-Warning 'The configured per-pair ceiling may not provide the stated 90% power for every direction.'
  }
  return
}

if (-not $FinalizeOnly) {
  $mapFile = Join-Path $mapsPath 'std_map_small.trm'
  if (-not (Test-Path $mapFile)) { throw "Simulator map is missing: $mapFile" }
  Write-Progress
  foreach ($pair in $allPairs) {
  if ($pair.SignificantA -or $pair.SignificantB) { continue }
  while ($pair.NewGames -lt $MaximumNewGamesPerPair -and -not ($pair.SignificantA -or $pair.SignificantB)) {
    $count = [Math]::Min($GamesPerCheckpoint, $MaximumNewGamesPerPair - $pair.NewGames)
    for ($batchGame = 0; $batchGame -lt $count; $batchGame++) {
      $gameId++
      $aFirst = $pair.FirstA -le $pair.SecondA
      $roster = if ($aFirst) { "$($pair.A),$($pair.B)" } else { "$($pair.B),$($pair.A)" }
      $result = Invoke-ScheduledGame $gameId $roster
      if ($masterLines.Add($result.Line)) {
        Append-MasterLine $masterPath $result.Line
      }
      [IO.File]::AppendAllText($resultsPath, ($result.Line + [Environment]::NewLine), [Text.Encoding]::ASCII)
      Add-ResultLine $result.Line $false
      $completedGames++
      if (($result.Line.Split(',')[2]) -eq '4') { $timeouts++ }
      if (($pair.NewGames % $GamesPerCheckpoint) -eq 0) { Test-Pair $pair }
      if (($completedGames % 25) -eq 0) { Write-Progress }
    }
  }
  Write-Progress
  Write-Output ("Pair {0} vs {1}: {2} new games; A significant={3}; B significant={4}" -f
    $pair.A, $pair.B, $pair.NewGames, $pair.SignificantA, $pair.SignificantB)
  }

  $masterCurrentLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  foreach ($line in (Read-SharedLines $masterPath)) { [void]$masterCurrentLines.Add($line) }
  $appendLines = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in (Read-SharedLines $resultsPath)) {
    if ($masterCurrentLines.Add($line)) { $appendLines.Add($line) }
  }
  if ($appendLines.Count -gt 0) {
    for ($attempt = 1; $attempt -le 40; $attempt++) {
      try {
        [IO.File]::AppendAllLines($masterPath, [string[]]$appendLines, [Text.Encoding]::ASCII)
        break
      } catch [IO.IOException] {
        if ($attempt -eq 40) { throw }
        Start-Sleep -Milliseconds 250
      }
    }
  }

  Write-Output 'Tournament complete. New results were deduplicated and appended to master.'
  Write-Output ("Run directory: {0}" -f $runPath)
}

$htmlPath = Join-Path $ReportDirectory 'bot-matrix.html'
$reportPath = Join-Path $ReportDirectory 'opponent-overperformance-2p.txt'
$html = [IO.File]::ReadAllText($htmlPath)
$matrixMatch = [regex]::Match($html, 'const D=(\{.*?\});\s*const sizes=', [Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $matrixMatch.Success) { throw "Could not locate matrix data in $htmlPath." }
$matrixData = $matrixMatch.Groups[1].Value | ConvertFrom-Json
$matrixBotList = New-Object 'System.Collections.Generic.List[string]'
foreach ($bot in @($matrixData.'2'.bots) + $bots) {
  if (-not $matrixBotList.Contains([string]$bot)) { $matrixBotList.Add([string]$bot) }
}
$matrixBots = $matrixBotList.ToArray()
$matrixBotSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $matrixBots) { [void]$matrixBotSet.Add($bot) }

$finalPairs = @{}
$finalPlayerStats = @{}
$finalLines = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $matrixBots) { $finalPlayerStats[$bot] = [pscustomobject]@{completed=0;timeouts=0} }
foreach ($line in (Read-SharedLines $masterPath)) {
  if (-not $finalLines.Add($line)) { continue }
  $x = $line.Split(',')
  if ($x.Count -lt 14 -or $x[5] -ne '2' -or $x[2] -notin @('1','4')) { continue }
  $a = $x[6]; $b = $x[10]
  if ($x[0] -lt '20261023') {
    if ($a -eq 'actuary' -or $b -eq 'actuary') { continue }
    if ($a -eq 'doomstack') { $a = 'challenger' }
    if ($b -eq 'doomstack') { $b = 'challenger' }
  }
  if (-not $matrixBotSet.Contains($a) -or -not $matrixBotSet.Contains($b) -or $a -eq $b) { continue }
  $key = Get-PairKey $a $b
  if (-not $finalPairs.ContainsKey($key)) {
    $names = $key.Split('|')
    $finalPairs[$key] = [pscustomobject]@{A=$names[0];B=$names[1];N=0;ScoreA=0.0;Completed=0;Timeouts=0}
  }
  $cell = $finalPairs[$key]
  $score = if ($x[2] -eq '4') { 0.5 } elseif ($a -eq $cell.A) { 1.0 } else { 0.0 }
  $cell.N++
  $cell.ScoreA += $score
  if ($x[2] -eq '4') { $cell.Timeouts++ } else { $cell.Completed++ }
  foreach ($participant in @($a,$b)) {
    if ($x[2] -eq '4') { $finalPlayerStats[$participant].timeouts++ }
    else { $finalPlayerStats[$participant].completed++ }
  }
}

$cellRows = New-Object 'System.Collections.Generic.List[object]'
$averageScores = New-Object 'System.Collections.Generic.List[double]'
$averageByBot = @{}
$overperformanceCounts = @{}
foreach ($rowBot in $matrixBots) {
  $row = New-Object 'System.Collections.Generic.List[object]'
  $rowTotal = 0.0
  $rowCount = 0
  $overperformanceCounts[$rowBot] = 0
  foreach ($columnBot in $matrixBots) {
    if ($rowBot -eq $columnBot) { $row.Add($null); continue }
    $cell = $finalPairs[(Get-PairKey $rowBot $columnBot)]
    if (-not $cell -or $cell.N -eq 0) { $row.Add($null); continue }
    $score = if ($rowBot -eq $cell.A) { $cell.ScoreA } else { $cell.N - $cell.ScoreA }
    $rate = $score / $cell.N
    $standardError = [Math]::Sqrt($rate * (1.0 - $rate) / $cell.N)
    $low = [Math]::Max(0.0, $rate - 1.959963984540054 * $standardError)
    $high = [Math]::Min(1.0, $rate + 1.959963984540054 * $standardError)
    $row.Add(@([Math]::Round($rate,6),$cell.Completed,$cell.N,$cell.Timeouts,[Math]::Round($low,6),[Math]::Round($high,6)))
    $rowTotal += $rate
    $rowCount++
  }
  $rowAverage = if ($rowCount) { $rowTotal / $rowCount } else { 0.5 }
  $averageByBot[$rowBot] = $rowAverage
  $averageScores.Add([Math]::Round($rowAverage,6))
  $cellRows.Add($row.ToArray())
}
foreach ($rowBot in $matrixBots) {
  foreach ($columnBot in $matrixBots) {
    if ($rowBot -eq $columnBot) { continue }
    $cell = $finalPairs[(Get-PairKey $rowBot $columnBot)]
    if (-not $cell -or $cell.N -eq 0) { continue }
    $opponentScore = if ($columnBot -eq $cell.A) { $cell.ScoreA } else { $cell.N - $cell.ScoreA }
    if (($opponentScore / $cell.N) -gt $averageByBot[$columnBot]) { $overperformanceCounts[$rowBot]++ }
  }
}

$matrixData.'2' = [pscustomobject]@{
  bots=$matrixBots; cells=$cellRows.ToArray(); avg=$averageScores.ToArray(); playerStats=$finalPlayerStats
}
$serializedMatrix = ConvertTo-Json -InputObject $matrixData -Depth 100 -Compress
$prefixLength = $matrixMatch.Index
$suffixStart = $matrixMatch.Index + $matrixMatch.Length
$updatedHtml = $html.Substring(0,$prefixLength) + "const D=$serializedMatrix;const sizes=" + $html.Substring($suffixStart)
[IO.File]::WriteAllText($htmlPath, $updatedHtml, (New-Object System.Text.UTF8Encoding($false)))

$reportLines = New-Object 'System.Collections.Generic.List[string]'
$reportLines.Add('Opponent overperformance frequency in 2-player matchups')
$reportLines.Add(('Generated from the current-version bot matrix on {0}.' -f (Get-Date -Format 'yyyy-MM-dd')))
$reportLines.Add('')
$reportLines.Add('For each bot, this is the percentage of its opponents whose win rate against')
$reportLines.Add('that bot is higher than the opponent''s overall win rate in the 2-player matrix.')
$reportLines.Add('Every opponent with at least one recorded game is included, regardless of')
$reportLines.Add('matchup sample size. The count is divided by all other matrix bots. This is a')
$reportLines.Add('descriptive frequency, not a calibrated probability for')
$reportLines.Add('an arbitrary future opponent; small-sample matchups can make it noisy.')
$reportLines.Add('')
$reportLines.Add('The source matrix is deduplicated and excludes pre-2026-10-23 Actuary results.')
$reportLines.Add('Pre-stalemate Doomstack results are labeled challenger. Matchup win rates')
$reportLines.Add('include time-limit results as ties.')
$reportLines.Add('')
$reportLines.Add('Bot                  Opponents overperforming')
$reportLines.Add('-------------------  ------------------------')
foreach ($bot in ($matrixBots | Sort-Object)) {
  $count = $overperformanceCounts[$bot]
  $percent = if ($matrixBots.Count -gt 1) { 100.0 * $count / ($matrixBots.Count - 1) } else { 0.0 }
  $reportLines.Add(('{0,-18} {1,6:N1}%  ({2,2}/{3})' -f $bot,$percent,$count,($matrixBots.Count-1)))
}
$reportLines.Add('')
if ($FinalizeOnly) {
  $reportLines.Add('This is a descriptive post-run summary of the shared confidence-width tournament.')
  $reportLines.Add('No inferential significance tests are applied to these adaptively sampled results.')
} else {
  $reportLines.Add(('Adaptive tests: nominal 95% family-wise confidence across {0:N0} directional hypotheses and {1} prespecified looks, using a one-sided normal-approximation z test.' -f $directionCount,$testLooks))
  $reportLines.Add(('Designed power target: {0}% for a true lift of {1} percentage points; this is a planning approximation, not a guarantee.' -f ($powerTarget*100),($minimumLift*100)))
  $reportLines.Add('A direction is marked significant only if it crossed its adjusted threshold at a prespecified checkpoint; non-significance is not evidence of equal performance.')
}
[IO.File]::WriteAllLines($reportPath, [string[]]$reportLines, (New-Object System.Text.UTF8Encoding($false)))

$signalRows = New-Object 'System.Collections.Generic.List[object]'
foreach ($pair in $allPairs) {
  foreach ($entry in @(
    [pscustomobject]@{Bot=$pair.A;Opponent=$pair.B;Signal=$pair.SignalA;Significant=$pair.SignificantA;Tested=$pair.TestedA},
    [pscustomobject]@{Bot=$pair.B;Opponent=$pair.A;Signal=$pair.SignalB;Significant=$pair.SignificantB;Tested=$pair.TestedB}
  )) {
    $signalRows.Add([pscustomobject]@{
      Bot=$entry.Bot; Opponent=$entry.Opponent; Tested=$entry.Tested
      Significant=$entry.Significant; Games=$pair.N
      Rate=if($entry.Signal){$entry.Signal.Rate}else{$null}
      Baseline=if($entry.Signal){$entry.Signal.Baseline}else{$null}
      Lift=if($entry.Signal){$entry.Signal.Lift}else{$null}
      Z=if($entry.Signal){$entry.Signal.Z}else{$null}
    })
  }
}
$signalRows | Export-Csv (Join-Path $dataPath 'directional-results.csv') -NoTypeInformation
Write-Output ("Updated 2-player matrix and overperformance report: {0}" -f $reportPath)
