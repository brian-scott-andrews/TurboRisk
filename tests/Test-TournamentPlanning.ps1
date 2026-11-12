$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot '..\Doc\Tournament\run-multiplayer-confidence-tournament.ps1'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$names=@('Test-FocusPair','Get-PairKey','Get-WilsonHalfWidth','Get-RequiredGames',
  'Get-RosterHalfWidth','Add-ResultLine','Test-EligibleHistoricalLine','New-Batch')
foreach($function in $ast.FindAll({
  param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]
},$false)){
  if($function.Name -in $names){. ([scriptblock]::Create($function.Extent.Text))}
}
$bots=@('a','b','c','d','e','f','g','h','i','j')
$focus=@('a','b'); $sizes=2..10; $SeedBase=12345
$MinimumGamesPerPair=20; $RepresentativeGamesPerBotSize=2; $BatchGamesPerSize=100
$goal=0.2; $z95=1.959963984540054; $brainlessVersionCutoff='20261027110000'
$pairStats=@{}; $pairFailures=@{}; $seatCounts=@{}
$representative=@{}; $representativeAttempts=@{}
$versionCutoffs=@{a='20261106000000'}
$botSet=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach($bot in $bots){[void]$botSet.Add($bot)}
foreach($size in $sizes){
  $seatCounts[$size]=@{}
  foreach($bot in $bots){$seatCounts[$size][$bot]=New-Object 'int[]' $size}
  foreach($bot in $focus){$representative["$size|$bot"]=0;$representativeAttempts["$size|$bot"]=0}
}
if(-not(Test-FocusPair a c) -or (Test-FocusPair c d)){throw 'Multiple-focus filtering failed'}
$old='20261105,120000,1,1,40,3,a,40,0,42,b,39,0,0,c,38,0,0'
if(-not(Test-EligibleHistoricalLine $old)){throw 'Old version discarded unchanged opponent evidence'}
Add-ResultLine $old
if($pairStats.ContainsKey('3|a|b') -or -not $pairStats.ContainsKey('3|b|c')){
  throw 'Version cutoff contaminated current-bot pairs or discarded unchanged pairs'
}
$current=$old.Replace('20261105','20261106')
Add-ResultLine $current
if($pairStats['3|a|b'].N -ne 1 -or $pairStats['3|b|c'].N -ne 2){
  throw 'Current-version evidence not counted correctly'
}
$batch=New-Batch 1
$ids=New-Object 'System.Collections.Generic.HashSet[int]'
foreach($game in $batch){
  $roster=@($game.Roster.Split(','))
  if($roster.Count -ne $game.N -or @($roster|Select-Object -Unique).Count -ne $game.N){
    throw 'Wrong roster size or duplicate bot'
  }
  if(-not $ids.Add([int]$game.Id)){throw 'Duplicate scheduled id'}
  if($game.Purpose -eq 'representative' -and $game.AnchorBot -notin $roster){
    throw 'Representative anchor missing'
  }
}
foreach($size in $sizes){foreach($bot in $focus){
  $games=@($batch|Where-Object {$_.N -eq $size -and $_.Purpose -eq 'representative' -and $_.AnchorBot -eq $bot})
  if($games.Count -ne 2){throw 'Representative quota not scheduled for every size/focus'}
}}
# Completed pair evidence must not suppress the independent representative quota.
foreach($size in $sizes){
  for($i=0;$i -lt $bots.Count;$i++){for($j=$i+1;$j -lt $bots.Count;$j++){
    $pairStats[(Get-PairKey $size $bots[$i] $bots[$j])]=[pscustomobject]@{N=100;Score=50.0}
  }}
}
$batch=New-Batch 10000
if($batch.Count -ne 36 -or @($batch|Where-Object Purpose -ne 'representative').Count){
  throw 'Representative quota depends on adaptive coverage'
}
foreach($size in $sizes){foreach($bot in $focus){$representative["$size|$bot"]=2}}
if((New-Batch 20000).Count -ne 0){throw 'Met quotas/coverage did not terminate'}
$sizes=@(4)
$RepresentativeGamesPerBotSize=0
$BatchGamesPerSize=1000
foreach($a in @('a','b','c','d')){foreach($b in @('a','b','c','d')){
  if($a -ne $b -and (Test-FocusPair $a $b)){
    $pairStats.Remove((Get-PairKey 4 $a $b))
  }
}}
$packed=New-Batch 30000
$required=Get-RequiredGames 0 0
if($packed.Count -ne $required){
  throw "Sparse coverage gaps should fit in $required games, not $($packed.Count)"
}
foreach($game in $packed){
  if($game.N -ne 4){throw 'Planner ignored selected player count'}
  if(@($game.Roster.Split(',')|Where-Object {$_ -notin @('a','b','c','d')}).Count){
    throw 'Coverage packing selected a filler instead of a useful missing matchup'
  }
}
$sizes=@(2)
$pairStats.Remove((Get-PairKey 2 'a' 'b'))
$duels=New-Batch 40000
if($duels.Count -ne $required -or @($duels|Where-Object N -ne 2).Count){
  throw 'Duel-only planning did not fill exactly the selected-size gap'
}
$sizes=2..10
$loadStart=($ast.EndBlock.Statements|Where-Object {
  $_.Extent.Text.StartsWith('foreach ($line in [IO.File]::ReadLines($masterPath))')
}).Extent.StartOffset
$loadEnd=($ast.EndBlock.Statements|Where-Object {
  $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Get-RequiredGames'
}).Extent.StartOffset
$loadEvidence=[scriptblock]::Create((($ast.EndBlock.Statements|Where-Object {
  $_.Extent.StartOffset -ge $loadStart -and $_.Extent.StartOffset -lt $loadEnd
}|ForEach-Object {$_.Extent.Text})-join [Environment]::NewLine))
$runPath=Join-Path ([IO.Path]::GetTempPath()) ('tournament-planning-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runPath|Out-Null
try {
  $masterPath=Join-Path $runPath 'master.sgl'
  $resultPath=Join-Path $runPath 'results.sgl'
  $attemptPath=Join-Path $runPath 'attempts.csv'
  $HistoricalResults=Join-Path $runPath 'reused.sgl'
  $own=$current.Replace(',120000,',',120001,')
  [IO.File]::WriteAllText($masterPath,'')
  [IO.File]::WriteAllLines($HistoricalResults,[string[]]@($current,$current))
  foreach($scenario in @('fresh','resume','already-staged')){
    $StageResults=$true
    $masterLines=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $pairStats=@{}; $newMasterLines=New-Object 'System.Collections.Generic.List[string]'
    $representative=@{}; $representativeWins=@{}; $representativeAttempts=@{}
    if($scenario -ne 'fresh'){
      [IO.File]::WriteAllLines($resultPath,[string[]]@($own,$own))
      @(
        [pscustomobject]@{N=3;Purpose='representative';AnchorBot='a';Status='1';Line=$own}
        [pscustomobject]@{N=3;Purpose='representative';AnchorBot='a';Status='setup-error';Line=''}
      )|Export-Csv $attemptPath -NoTypeInformation
    }
    if($scenario -eq 'already-staged'){
      [IO.File]::WriteAllLines((Join-Path $runPath 'master-import-pending.sgl'),[string[]]@($own))
    }
    . $loadEvidence
    $expected=if($scenario -eq 'fresh'){1}else{2}
    if($pairStats['3|a|b'].N -ne $expected){
      throw "Historical loading or deduplication failed in $scenario"
    }
    $pending=if($scenario -eq 'resume'){1}else{0}
    if($newMasterLines.Count -ne $pending){
      throw "Lost resumed results, duplicated staging, or staged reused coverage in $scenario"
    }
    if($scenario -ne 'fresh' -and (
      $representative['3|a'] -ne 1 -or $representativeAttempts['3|a'] -ne 2 -or
      $representativeWins['3|a'] -ne 1)){
      throw 'Resume replayed representative attempts once per result instead of once per attempt'
    }
  }
} finally {
  Remove-Item -LiteralPath $runPath -Recurse -Force
}
Write-Output "PASS: multiple focus bots, version-aware reuse, unique rosters, all sizes, independent quotas, termination, coverage packing ($required games), fresh historical loading and deduplicated resume/staging."
