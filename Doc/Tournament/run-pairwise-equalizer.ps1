param(
  [Parameter(Mandatory=$true)][string]$Run,
  [Parameter(Mandatory=$true)][string]$MasterResults,
  [int]$Workers = 24,
  [int]$TimeLimit = 180,
  [int]$Target = 200,
  [int]$Seed = 20261023,
  [int]$MaxRetryPasses = 6,
  [switch]$ResumeExistingPass
)

$ErrorActionPreference = 'Stop'
$runPath = (Resolve-Path $Run).Path
$masterPath = (Resolve-Path $MasterResults).Path
$plan = @(Import-Csv (Join-Path $runPath 'pair-plan.csv'))
$initialJobs = @(Import-Csv (Join-Path $runPath 'schedule-index.csv'))
$info = Get-Content (Join-Path $runPath 'tournament-info.txt')
$expectedHash = (($info | Where-Object { $_ -like 'MasterSha256AtStart=*' }) -replace '^MasterSha256AtStart=', '')
$mapSequence = @('std_map_small.trm', 'diagram_small.trm', 'Satellite_Map_Small.trm', 'std_map_medium.trm')
$started = Get-Date
$passNumbers = New-Object 'System.Collections.Generic.List[int]'

function Get-PairKey([string]$a, [string]$b) {
  if ([string]::CompareOrdinal($a, $b) -lt 0) { return "$a|$b" }
  return "$b|$a"
}

function Get-ResultState {
  $pairValid = @{}
  $valid = 0
  $errors = 0
  $timeouts = 0
  $logged = 0
  foreach ($pass in $passNumbers) {
    foreach ($worker in 0..($Workers - 1)) {
      $log = Join-Path $runPath "w$worker\games-pass$pass.sgl"
      if (-not (Test-Path $log)) { continue }
      try {
        foreach ($line in [IO.File]::ReadLines($log)) {
          $x = $line.Split(',')
          if ($x.Count -lt 14 -or $x[5] -ne '2') { continue }
          $logged++
          if ($x[2] -eq '2') { $errors++; continue }
          if ($x[2] -notin @('1','4')) { continue }
          if ($x[2] -eq '4') { $timeouts++ }
          $valid++
          $key = Get-PairKey $x[6] $x[10]
          $pairValid[$key] = [int]$pairValid[$key] + 1
        }
      } catch {}
    }
  }
  return [pscustomobject]@{PairValid=$pairValid; Valid=$valid; Errors=$errors; Timeouts=$timeouts; Logged=$logged}
}

function Write-ProgressFile([string]$path, [string]$content) {
  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    try {
      [IO.File]::WriteAllText($path, $content)
      return
    } catch [System.IO.IOException] {
      Start-Sleep -Milliseconds 250
    }
  }
  throw "Could not update progress file because another process holds it: $path"
}

function Write-ProgressSnapshot([int]$pass, [int]$scheduled, [int]$running) {
  $state = Get-ResultState
  $remaining = 0
  $donePairs = 0
  $pairRows = foreach ($p in $plan) {
    $count = [int]$p.Existing + [int]$state.PairValid[$p.Pair]
    $left = [math]::Max(0, $Target - $count)
    $remaining += $left
    if ($left -eq 0) { $donePairs++ }
    [pscustomobject]@{Pair=$p.Pair; Existing=[int]$p.Existing; New=[int]$state.PairValid[$p.Pair]; Total=$count; Target=$Target; Remaining=$left}
  }
  $elapsed = [math]::Max(1, ((Get-Date) - $started).TotalMinutes)
  $rate = $state.Valid / $elapsed
  $eta = if ($rate -gt 0) { [math]::Ceiling($remaining / $rate) } else { 0 }
  $progress = [pscustomobject]@{
    Pass=$pass; GamesLogged=$state.Logged; ValidGames=$state.Valid
    Errors=$state.Errors; Timeouts=$state.Timeouts; PairsComplete=$donePairs
    TotalPairs=$plan.Count; GamesRemaining=$remaining; CurrentPassScheduled=$scheduled
    WorkersRunning=$running; RatePerMinute=[math]::Round($rate,1); EtaMinutes=$eta
    Updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }
  Write-ProgressFile (Join-Path $runPath 'progress.json') ($progress | ConvertTo-Json)
  $pairRows | Export-Csv (Join-Path $runPath 'pair-progress.csv') -NoTypeInformation
  $text = @(
    'BALANCED 2-PLAYER ROUND ROBIN'
    ('Updated: {0}   Pass: {1}   Workers running: {2}' -f $progress.Updated, $pass, $running)
    ('Valid games: {0:N0}   Logged: {1:N0}   Errors: {2:N0}   Time limits: {3:N0}' -f $state.Valid, $state.Logged, $state.Errors, $state.Timeouts)
    ('Matchups at {0}: {1:N0}/{2:N0}   Remaining valid pair-games: {3:N0}' -f $Target, $donePairs, $plan.Count, $remaining)
    ('This pass scheduled: {0:N0}   Rate: {1:N1} valid games/min   ETA: {2:N0} min' -f $scheduled, $rate, $eta)
    ''
    'Least-complete matchups (current valid games / target):'
  )
  $text += @($pairRows | Sort-Object Total, Pair | Select-Object -First 12 | ForEach-Object { '  {0,-32} {1,3}/{2}   remaining {3,3}' -f $_.Pair, $_.Total, $_.Target, $_.Remaining })
  Write-ProgressFile (Join-Path $runPath 'progress.txt') ($text -join [Environment]::NewLine)
}

function Invoke-Pass([int]$pass, [object[]]$jobs, [string]$map) {
  $passNumbers.Add($pass)
  $active = New-Object System.Collections.Generic.List[object]
  for ($worker = 0; $worker -lt $Workers; $worker++) {
    $wd = Join-Path $runPath "w$worker"
    $mine = @($jobs | Where-Object { [int]$_.Id % $Workers -eq $worker })
    if (-not $mine.Count) { continue }
    $mine | ForEach-Object Roster | Set-Content (Join-Path $wd 'schedule.csv') -Encoding ASCII
    $stdout = Join-Path $wd "out-pass$pass.txt"
    $stderr = Join-Path $wd "err-pass$pass.txt"
    $args = "--schedule schedule.csv --map $map --turn-limit 0 --time-limit $TimeLimit --seed $($Seed + $pass * 1000 + $worker) --game-log games-pass$pass.sgl --cpu-log cpu-pass$pass.scl"
    $proc = Start-Process -FilePath (Join-Path $wd 'TRSimCLI.exe') -ArgumentList $args -WorkingDirectory $wd -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $active.Add([pscustomobject]@{Worker=$worker;Process=$proc})
  }
  do {
    Start-Sleep -Seconds 15
    $stillRunning = @($active | Where-Object { -not $_.Process.HasExited }).Count
    Write-ProgressSnapshot $pass $jobs.Count $stillRunning
  } while ($stillRunning -gt 0)
  foreach ($item in $active) { $item.Process.WaitForExit() }
}

if ($plan.Count -ne 1431 -or $Target -ne 200) {
  throw "Unexpected tournament plan: $($plan.Count) matchups, target $Target."
}
if ((Get-FileHash $masterPath -Algorithm SHA256).Hash -ne $expectedHash) {
  throw 'Master results changed after the tournament schedule was created; refusing to run a stale plan.'
}

$nextPass = 1
if ($ResumeExistingPass) {
  $passNumbers.Add(1)
  $nextPass = 2
  while ($true) {
    $activeTournamentWorkers = @(Get-CimInstance Win32_Process -Filter "Name='TRSimCLI.exe'" | Where-Object {
      $_.ExecutablePath -and $_.ExecutablePath.StartsWith((Join-Path $runPath 'w'), [StringComparison]::OrdinalIgnoreCase)
    })
    Write-ProgressSnapshot 1 $initialJobs.Count $activeTournamentWorkers.Count
    if ($activeTournamentWorkers.Count -eq 0) { break }
    Start-Sleep -Seconds 15
  }
} else {
  Invoke-Pass 1 $initialJobs $mapSequence[0]
  $nextPass = 2
}
for ($retry = 1; $retry -le $MaxRetryPasses; $retry++) {
  $state = Get-ResultState
  $retryJobs = New-Object 'System.Collections.Generic.List[object]'
  $id = 1
  foreach ($p in $plan) {
    $left = [math]::Max(0, $Target - [int]$p.Existing - [int]$state.PairValid[$p.Pair])
    $names = $p.Pair.Split('|')
    $flip = (Get-Random -Minimum 0 -Maximum 2)
    for ($n = 0; $n -lt $left; $n++) {
      $roster = if (($n + $flip + $retry) % 2 -eq 0) { "$($names[0]),$($names[1])" } else { "$($names[1]),$($names[0])" }
      $retryJobs.Add([pscustomobject]@{Id=$id;Pair=$p.Pair;Roster=$roster})
      $id++
    }
  }
  if ($retryJobs.Count -eq 0) { break }
  Invoke-Pass $nextPass @($retryJobs) $mapSequence[($retry % $mapSequence.Count)]
  $nextPass++
}

$finalState = Get-ResultState
$toAppend = New-Object 'System.Collections.Generic.List[string]'
foreach ($pass in $passNumbers) {
  foreach ($worker in 0..($Workers - 1)) {
    $log = Join-Path $runPath "w$worker\games-pass$pass.sgl"
    if (-not (Test-Path $log)) { continue }
    foreach ($line in [IO.File]::ReadLines($log)) {
      $x = $line.Split(',')
      if ($x.Count -ge 14 -and $x[5] -eq '2' -and $x[2] -in @('1','4')) { $toAppend.Add($line) }
    }
  }
}

if ((Get-FileHash $masterPath -Algorithm SHA256).Hash -ne $expectedHash) {
  throw "Master results changed during the run. Results are retained in $runPath and were not appended."
}
$backupDir = Join-Path (Split-Path $masterPath) 'raw_backup'
New-Item -ItemType Directory -Force $backupDir | Out-Null
$backup = Join-Path $backupDir ("master_results-before-pairwise-{0}.sgl" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Copy-Item $masterPath $backup
[IO.File]::AppendAllLines($masterPath, [string[]]$toAppend)

$summary = @(
  ('Target games per pair: {0}' -f $Target)
  ('Games scheduled initially: {0}' -f $initialJobs.Count)
  ('Valid result lines appended: {0}' -f $toAppend.Count)
  ('Errored attempts remaining: {0}' -f $finalState.Errors)
  ('Time-limit results counted: {0}' -f $finalState.Timeouts)
  ('Before-run master backup: {0}' -f $backup)
)
foreach ($p in $plan) {
  $count = [int]$p.Existing + [int]$finalState.PairValid[$p.Pair]
  if ($count -ne $Target) { $summary += ('INCOMPLETE {0}: {1}/{2}' -f $p.Pair, $count, $Target) }
}
$summary | Set-Content (Join-Path $runPath 'result-summary.txt')
Write-ProgressSnapshot $passNumbers[$passNumbers.Count-1] $initialJobs.Count 0
$summary
