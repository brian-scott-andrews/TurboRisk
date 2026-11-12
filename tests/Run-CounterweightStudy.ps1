param(
  [Parameter(Mandatory=$true)][string]$SnapshotRoot,
  [Parameter(Mandatory=$true)][ValidateSet(20,50,100,200,400)][int]$TargetGames,
  [Parameter(Mandatory=$true)][string]$Rationale,
  [int]$Candidate=1,
  [int]$SeedBase=202611070,
  [int]$TimeLimit=30,
  [int]$TurnLimit=400,
  [switch]$Holdout
)
$ErrorActionPreference='Stop'

if($Candidate -lt 1 -or $Candidate -gt 10){throw 'Candidate must be 1 through 10.'}
if($TimeLimit -lt 1 -or $TurnLimit -lt 1){throw 'Time and turn limits must be positive.'}
$SnapshotRoot=(Resolve-Path $SnapshotRoot).Path
$studyRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Doc\Tournament\counterweight-study'))
$candidateDir=Join-Path $studyRoot ("candidate-{0:D2}" -f $Candidate)
$stageDir=Join-Path $candidateDir ("checkpoint-{0:D3}" -f $TargetGames)
if($Holdout){
  if($TargetGames -ne 400){throw 'Holdout requires exactly 400 games.'}
  $stageDir=Join-Path $candidateDir 'holdout-400'
}elseif($TargetGames -eq 400){throw '400 games are reserved for holdout.'}
$source=Join-Path (Split-Path $PSScriptRoot -Parent) 'players\counterweight.trp'
$vexer=Join-Path $SnapshotRoot 'players\vexer.trp'
$exe=Join-Path $SnapshotRoot 'TRSimCLI.exe'
$ini=Join-Path $SnapshotRoot 'TurboRisk.INI'
$mapTrm=Join-Path $SnapshotRoot 'maps\std_map_small.trm'
$mapBmp=Join-Path $SnapshotRoot 'maps\std_map_small.bmp'
foreach($required in @($source,$vexer,$exe,$ini,$mapTrm,$mapBmp)){
  if(-not (Test-Path $required -PathType Leaf)){throw "Required frozen input missing: $required"}
}
if(-not (Test-Path $candidateDir)){
  New-Item $candidateDir -ItemType Directory -Force|Out-Null
  Copy-Item $source (Join-Path $candidateDir 'source.trp')
  $hash=(Get-FileHash $source -Algorithm SHA256).Hash
  [IO.File]::WriteAllText((Join-Path $candidateDir 'source.sha256'),$hash+[Environment]::NewLine,[Text.Encoding]::ASCII)
  $meta=[ordered]@{
    candidate=$Candidate; source_sha256=$hash; rationale=$Rationale
    snapshot_root=$SnapshotRoot; vexer_sha256=(Get-FileHash $vexer -Algorithm SHA256).Hash
    simulator_sha256=(Get-FileHash $exe -Algorithm SHA256).Hash
    ini_sha256=(Get-FileHash $ini -Algorithm SHA256).Hash
    map_trm_sha256=(Get-FileHash $mapTrm -Algorithm SHA256).Hash
    map_bmp_sha256=(Get-FileHash $mapBmp -Algorithm SHA256).Hash
    rules='[Rules] CardUsage=1 (progressive); TradeCapturedCards=1 (trade captured cards immediately)'
    map='std_map_small.trm; random territory assignment; seed controls RNG'
    roster='counterweight,vexer and vexer,counterweight for every seed'
    seed_base=$SeedBase; seed_formula='SeedBase + pair_index * 101'; time_limit_seconds=$TimeLimit
    turn_limit=$TurnLimit; external_watchdog_seconds=90; created_utc=[DateTime]::UtcNow.ToString('o')
  }
  $meta|ConvertTo-Json -Depth 4|Set-Content (Join-Path $candidateDir 'metadata.json') -Encoding UTF8
  [IO.File]::WriteAllText((Join-Path $candidateDir 'rationale.txt'),$Rationale+[Environment]::NewLine,[Text.Encoding]::UTF8)
}else{
  $saved=(Get-Content (Join-Path $candidateDir 'source.sha256') -Raw).Trim()
  $actual=(Get-FileHash $source -Algorithm SHA256).Hash
  if($saved -ne $actual){throw "Live source hash $actual differs from archived candidate $Candidate hash $saved. Archive before any edit."}
  $savedMeta=Get-Content (Join-Path $candidateDir 'metadata.json') -Raw|ConvertFrom-Json
  foreach($entry in @(
    @{Path=$vexer;Hash=$savedMeta.vexer_sha256},
    @{Path=$exe;Hash=$savedMeta.simulator_sha256},
    @{Path=$ini;Hash=$savedMeta.ini_sha256}
  )){
    if((Get-FileHash $entry.Path -Algorithm SHA256).Hash -ne $entry.Hash){
      throw "Frozen input changed: $($entry.Path)"
    }
  }
  if(((-not $Holdout) -and $savedMeta.seed_base -ne $SeedBase) -or $savedMeta.time_limit_seconds -ne $TimeLimit -or $savedMeta.turn_limit -ne $TurnLimit){
    throw 'Seeds or simulator limits differ from the frozen candidate method.'
  }
}

$prior=@()
$resultsPath=Join-Path $candidateDir 'results.csv'
if(Test-Path $resultsPath){$prior=@(Import-Csv $resultsPath)}
if($Holdout){
  if($prior.Count -ne 200 -or @($prior|Where-Object {$_.Status -eq '1' -and $_.Winner -eq 'counterweight'}).Count -le 100){
    throw 'Holdout requires passing 200-game development screen.'
  }
  $holdoutSeeds=@(0..199|ForEach-Object {$SeedBase+$_*101})
  if(@($prior|Where-Object {[int]$_.Seed -in $holdoutSeeds}).Count){throw 'Holdout seeds overlap development.'}
  $prior=@()
  $resultsPath=Join-Path $stageDir 'results-all.csv'
}
if($prior.Count -ge $TargetGames){throw "Already have $($prior.Count) results; target was $TargetGames"}
if(($prior.Count % 2) -ne 0){throw 'Prior results do not contain complete two-seat seed pairs.'}
if($prior.Count -gt 0 -and $prior.Count -notin @(20,50,100)){throw 'Only planned sequential checkpoints are allowed.'}
if(-not $Holdout -and $prior.Count -eq 0 -and $TargetGames -ne 20){throw 'Begin screening at the 20-game checkpoint.'}
if($prior.Count -gt 0 -and $TargetGames -le $prior.Count){throw 'Checkpoint must advance monotonically.'}
foreach($threshold in @(20,50,100)){
  if($prior.Count -ge $threshold){
    $wins=@($prior|Where-Object {$_.Status -eq '1' -and $_.Winner -match '^counterweight(?:\.trp)?$'}).Count
    $minimum=@{20=0.30;50=0.40;100=0.45}[$threshold]
    if(($wins/$prior.Count) -lt $minimum){throw "Candidate already failed its $threshold-game gate; no further games allowed."}
  }
}
if(Test-Path $stageDir){throw "Checkpoint already exists; refusing to overwrite evidence: $stageDir"}
New-Item $stageDir -ItemType Directory -Force|Out-Null
if($Holdout){
  [ordered]@{
    source_sha256=(Get-FileHash $source).Hash;games=400;seed_base=$SeedBase
    alpha=0.05;familywise_alpha=0.05;maximum_holdouts=10
    adjusted_z=2.807033768343804;ordinary_z=1.959963984540054
    success_rule='Both ordinary and Bonferroni-adjusted Wilson lower bounds must exceed 0.5 on wins/all attempts.'
    frozen_utc=[DateTime]::UtcNow.ToString('o')
  }|ConvertTo-Json|Set-Content (Join-Path $stageDir 'predeclared-method.json') -Encoding UTF8
}
$workerRoot=Join-Path $stageDir 'workers'
$rawRoot=Join-Path $stageDir 'raw'
New-Item $workerRoot,$rawRoot -ItemType Directory -Force|Out-Null
$workerCount=4
for($w=0;$w -lt $workerCount;$w++){
  $dir=Join-Path $workerRoot "w$w"
  New-Item (Join-Path $dir 'players'),(Join-Path $dir 'maps') -ItemType Directory -Force|Out-Null
  Copy-Item $exe,$ini $dir
  Copy-Item $mapTrm,$mapBmp (Join-Path $dir 'maps')
  Copy-Item $source (Join-Path $dir 'players\counterweight.trp')
  Copy-Item $vexer (Join-Path $dir 'players\vexer.trp')
}

$newGames=$TargetGames-$prior.Count
$pairStart=[int]($prior.Count/2)
$newPairs=[int]($newGames/2)
$pending=New-Object System.Collections.Queue
for($offset=0;$offset -lt $newPairs;$offset++){
  $pair=$pairStart+$offset
  $seed=$SeedBase+$pair*101
  foreach($seat in 0,1){
    $game=2*$pair+$seat
    $roster=if($seat -eq 0){'counterweight,vexer'}else{'vexer,counterweight'}
    $pending.Enqueue([pscustomobject]@{Game=$game;Pair=$pair;Seat=$seat;Seed=$seed;Roster=$roster})
  }
}
$active=New-Object System.Collections.ArrayList
$newRows=New-Object System.Collections.ArrayList
try{
  while($pending.Count -gt 0 -or $active.Count -gt 0){
    while($pending.Count -gt 0 -and $active.Count -lt $workerCount){
      $job=$pending.Dequeue()
      $used=@($active|ForEach-Object Worker)
      $worker=0; while($worker -lt $workerCount -and $worker -in $used){$worker++}
      $dir=Join-Path $workerRoot "w$worker"
      $gameDir=Join-Path $rawRoot ("game-{0:D4}" -f $job.Game)
      New-Item $gameDir -ItemType Directory -Force|Out-Null
      [IO.File]::WriteAllText((Join-Path $dir 'schedule.csv'),($job.Roster+[Environment]::NewLine),[Text.Encoding]::ASCII)
      $logName="game-$($job.Game).sgl"
      $arguments="--schedule schedule.csv --map std_map_small.trm --turn-limit $TurnLimit --time-limit $TimeLimit --seed $($job.Seed) --error-dump --game-log $logName --cpu-log game-$($job.Game).scl --action-log game-$($job.Game).jsonl"
      $startInfo=New-Object System.Diagnostics.ProcessStartInfo
      $startInfo.FileName=Join-Path $dir 'TRSimCLI.exe'
      $startInfo.WorkingDirectory=$dir
      $startInfo.Arguments=$arguments
      $startInfo.UseShellExecute=$false
      $startInfo.CreateNoWindow=$true
      $startInfo.RedirectStandardOutput=$true
      $startInfo.RedirectStandardError=$true
      $process=New-Object System.Diagnostics.Process
      $process.StartInfo=$startInfo
      if(-not $process.Start()){throw 'Could not start simulator'}
      $stdout=$process.StandardOutput.ReadToEndAsync()
      $stderr=$process.StandardError.ReadToEndAsync()
      [void]$active.Add([pscustomobject]@{Worker=$worker;Game=$job;Process=$process;Stdout=$stdout;Stderr=$stderr;Directory=$dir;GameDirectory=$gameDir;LogName=$logName;Started=(Get-Date)})
    }

    Start-Sleep -Milliseconds 250
    $stillRunning=New-Object System.Collections.ArrayList
    foreach($job in $active){
      $job.Process.Refresh()
      if(-not $job.Process.HasExited -and ((Get-Date)-$job.Started).TotalSeconds -le 90){
        [void]$stillRunning.Add($job); continue
      }
      $watchdog=$false
      if(-not $job.Process.HasExited){
        $watchdog=$true
        Stop-Process -Id $job.Process.Id -Force
        $job.Process.WaitForExit()
      }
      $job.Process.WaitForExit()
      [IO.File]::WriteAllText((Join-Path $job.GameDirectory 'stdout.txt'),$job.Stdout.Result)
      [IO.File]::WriteAllText((Join-Path $job.GameDirectory 'stderr.txt'),$job.Stderr.Result)
      if(-not $watchdog -and $job.Process.ExitCode -ne 0){
        throw "Simulator failed with exit $($job.Process.ExitCode); inspect $($job.GameDirectory)"
      }
      $logPath=Join-Path $job.Directory $job.LogName
      $line=''
      if(Test-Path $logPath){
        foreach($candidateLine in [IO.File]::ReadLines($logPath)){
          if($candidateLine -match '^\d{8},'){$line=$candidateLine;break}
        }
      }
      if($watchdog){
        $status='4'; $winner=''; $line='external watchdog timeout'
      }else{
        if(-not $line){throw "Simulator/setup failure: missing result record for game $($job.Game.Game); inspect $job.GameDirectory"}
        $fields=$line.Split(',')
        if($fields.Count -lt 7){throw "Malformed result record for game $($job.Game.Game): $line"}
        $status=$fields[2]; $winner=$fields[6]
        if($status -notin @('1','3','4')){throw "TRP or simulator error in game $($job.Game.Game) (status $status); inspect $job.GameDirectory"}
      }
      foreach($name in @($job.LogName,"game-$($job.Game.Game).scl","game-$($job.Game.Game).jsonl")){
        $path=Join-Path $job.Directory $name
        if(Test-Path $path){Copy-Item $path (Join-Path $job.GameDirectory $name)}
      }
      $row=[pscustomobject]@{
        Game=$job.Game.Game;Pair=$job.Game.Pair;Seat=$job.Game.Seat;Seed=$job.Game.Seed
        Status=$status;Winner=$winner;Watchdog=$watchdog;RawLine=$line
      }
      [void]$newRows.Add($row)
      $row|Export-Csv (Join-Path $stageDir 'results.csv') -NoTypeInformation -Append
    }
    $active=$stillRunning
  }

  if($newRows.Count -ne $newGames){throw "Expected $newGames new games; got $($newRows.Count)."}
  $all=@($prior)+@($newRows|Sort-Object {[int]$_.Game})
  $all|Export-Csv $resultsPath -NoTypeInformation
  $games=$all.Count
  $wins=@($all|Where-Object {$_.Status -eq '1' -and $_.Winner -match '^counterweight(?:\.trp)?$'}).Count
  $timeouts=@($all|Where-Object {$_.Status -eq '4'}).Count
  $turnLimits=@($all|Where-Object {$_.Status -eq '3'}).Count
  $gate=@{20=0.30;50=0.40;100=0.45;200=0.50}[$TargetGames]
  $passed=if($TargetGames -eq 200){$wins/$games -gt $gate}else{$wins/$games -ge $gate}
  $lower95=$null; $lowerAdjusted=$null
  if($Holdout){
    $rate=$wins/$games
    foreach($z in @(1.959963984540054,2.807033768343804)){
      $lower=($rate+$z*$z/(2*$games)-$z*[Math]::Sqrt($rate*(1-$rate)/$games+$z*$z/(4*$games*$games)))/(1+$z*$z/$games)
      if($z -lt 2){$lower95=$lower}else{$lowerAdjusted=$lower}
    }
    $gate=0.5; $passed=$lowerAdjusted -gt 0.5
  }
  $summary=[ordered]@{
    candidate=$Candidate;checkpoint_games=$TargetGames;cumulative_games=$games;wins=$wins
    all_attempt_win_rate=[Math]::Round($wins/$games,6);timeouts=$timeouts;turn_limits=$turnLimits
    completed=($games-$timeouts-$turnLimits);threshold=$gate;gate_passed=$passed
    source_sha256=(Get-FileHash $source -Algorithm SHA256).Hash
    seed_base=$SeedBase;seat0_games=@($all|Where-Object {[int]$_.Seat -eq 0}).Count
    seat1_games=@($all|Where-Object {[int]$_.Seat -eq 1}).Count
    generated_utc=[DateTime]::UtcNow.ToString('o')
    holdout=[bool]$Holdout;wilson_lower95=$lower95;wilson_lower_adjusted=$lowerAdjusted
  }
  $summary|ConvertTo-Json|Set-Content (Join-Path $stageDir 'summary.json') -Encoding UTF8
  $summary|ConvertTo-Json
  if(-not $passed -and -not $Holdout){[IO.File]::WriteAllText((Join-Path $candidateDir 'STOPPED.txt'),"Failed $TargetGames-game cumulative gate: $wins/$games wins; threshold $gate.`r`n",[Text.Encoding]::UTF8)}
}finally{
  foreach($job in $active){
    if(-not $job.Process.HasExited){Stop-Process -Id $job.Process.Id -Force}
  }
  foreach($p in @(Get-CimInstance Win32_Process|Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($stageDir,[StringComparison]::OrdinalIgnoreCase)
  })){Stop-Process -Id $p.ProcessId -Force}
}
