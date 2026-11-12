$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('matrix-versions-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
  foreach($bot in @('a','b','c')){
    [IO.File]::WriteAllText((Join-Path $root "$bot.trp"),'')
  }
  $matrix=Join-Path $root 'matrix.html'
  [IO.File]::WriteAllText($matrix,'const D={};const sizes=[];')
  $master=Join-Path $root 'master.sgl'
  [IO.File]::WriteAllLines($master,[string[]]@(
    '20261105,120000,1,1,40,3,a,40,0,42,b,39,0,0,c,38,0,0',
    '20261106,120000,1,1,40,3,a,40,0,42,b,39,0,0,c,38,0,0'
  ))
  $cutoffs=Join-Path $root 'cutoffs.csv'
  [IO.File]::WriteAllLines($cutoffs,[string[]]@('Bot,Cutoff','a,20261106000000'))
  & (Join-Path $PSScriptRoot '..\Doc\Tournament\update-bot-matrix.ps1') `
    -MasterResults $master -PlayersDirectory $root -MatrixPath $matrix -VersionCutoffsFile $cutoffs
  $html=[IO.File]::ReadAllText($matrix)
  $json=[regex]::Match($html,'const D=(\{.*?\});const sizes=',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
  $data=$json|ConvertFrom-Json
  if($data.'3'.cells[0][1][2] -ne 1 -or $data.'3'.cells[1][2][2] -ne 2){
    throw 'Version cutoffs contaminated current cells or discarded unchanged opponents.'
  }
  if($data.'3'.playerStats.a.completed -ne 1 -or $data.'3'.playerStats.b.completed -ne 2){
    throw 'Version cutoffs did not apply to player counts.'
  }
  $policyBots=@('brainless V','brainless vi','brainless_iv','raptorbot','zotob')
  foreach($bot in $policyBots){[IO.File]::WriteAllText((Join-Path $root "$bot.trp"),'')}
  $rows=New-Object 'System.Collections.Generic.List[string]'
  foreach($date in @('20261026','20261028','20261109')){
    foreach($bot in $policyBots|Where-Object {$_ -ne 'zotob'}){
      $rows.Add("$date,120000,1,1,40,2,$bot,40,0,42,zotob,39,0,0")
    }
  }
  $rows.Add('20261101,120000,1,1,40,2,brainless_iv pre-occupation-fix,40,0,42,zotob,39,0,0')
  $rows.Add('20261101,120001,4,1,40,2,raptorbot,40,0,10,zotob,40,0,10')
  foreach($status in @('2','3')){
    $rows.Add("20261101,120002,$status,1,40,2,raptorbot,40,0,10,zotob,40,0,10")
  }
  [IO.File]::WriteAllLines($master,$rows)
  & (Join-Path $PSScriptRoot '..\Doc\Tournament\update-bot-matrix.ps1') `
    -MasterResults $master -PlayersDirectory $root -MatrixPath $matrix
  $html=[IO.File]::ReadAllText($matrix)
  $data=([regex]::Match($html,'const D=(\{.*?\});const sizes=',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value)|ConvertFrom-Json
  $z=[array]::IndexOf($data.'2'.bots,'zotob')
  foreach($bot in @('brainless V','brainless vi','brainless_iv','raptorbot')){
    $i=[array]::IndexOf($data.'2'.bots,$bot)
    $expected=if($bot -in @('brainless V','brainless vi')){2}else{4}
    if($data.'2'.cells[$i][$z][2] -ne $expected){
      throw "Bug-fix pooling or strategy boundary failed for $bot"
    }
  }
  [IO.File]::WriteAllLines($master,[string[]]@(
    '20261109,120000,1,1,40,3,a,40,0,42,b,39,0,0,c,39,0,0',
    '20261109,120001,4,1,40,3,a,40,0,10,b,40,0,10,c,40,0,10'
  ))
  & (Join-Path $PSScriptRoot '..\Doc\Tournament\update-bot-matrix.ps1') `
    -MasterResults $master -PlayersDirectory $root -MatrixPath $matrix -VersionCutoffsFile ''
  $html=[IO.File]::ReadAllText($matrix)
  $data=([regex]::Match($html,'const D=(\{.*?\});const sizes=',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value)|ConvertFrom-Json
  $a=[array]::IndexOf($data.'3'.bots,'a')
  $b=[array]::IndexOf($data.'3'.bots,'b')
  $c=[array]::IndexOf($data.'3'.bots,'c')
  if($data.'3'.cells[$b][$c][6] -ne 2 -or $data.'3'.cells[$a][$b][6] -ne 1 -or
      $data.'3'.cells[$a][$b][7] -ne 1.5 -or $data.'3'.cells[$b][$a][7] -ne 0.5){
    throw 'Tie counts or exact directional scores lost timeout/equal-finish evidence.'
  }
  Write-Output 'PASS: version filtering, safety-fix pooling, strategy boundaries, exact scores and all pair ties.'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force
}
