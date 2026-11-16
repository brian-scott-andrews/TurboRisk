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
  $legacyV='20261025,120000,1,1,40,2,brainless V legacy,40,0,42,zotob,39,0,0'
  $rows.Add($legacyV)
  $rows.Add($legacyV)
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
    $expected=if($bot -eq 'brainless vi'){2}elseif($bot -eq 'raptorbot'){5}else{4}
    if($data.'2'.cells[$i][$z][2] -ne $expected){
      throw "Bug-fix pooling or strategy boundary failed for $bot"
    }
    if($data.'2'.playerStats.'brainless V'.wins -ne 4 -or
        $data.'2'.playerStats.'brainless V'.completed -ne 4 -or
        $data.'2'.playerStats.'brainless vi'.wins -ne 2){
      throw 'V pooling must include old wins and appearances once, without pooling legacy VI.'
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
  [IO.File]::WriteAllText((Join-Path $root 'd.trp'),'')
  $limited='20261109,120002,4,181,401,4,a,401,0,0,b,10,0,0,c,400,0,20,d,400,0,22'
  [IO.File]::WriteAllLines($master,[string[]]@($limited,$limited))
  & (Join-Path $PSScriptRoot '..\Doc\Tournament\update-bot-matrix.ps1') `
    -MasterResults $master -PlayersDirectory $root -MatrixPath $matrix -VersionCutoffsFile ''
  $html=[IO.File]::ReadAllText($matrix)
  $data=([regex]::Match($html,'const D=(\{.*?\});const sizes=',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value)|ConvertFrom-Json
  $a=[array]::IndexOf($data.'4'.bots,'a')
  $b=[array]::IndexOf($data.'4'.bots,'b')
  $c=[array]::IndexOf($data.'4'.bots,'c')
  if($data.'4'.cells[$a][$b][7] -ne 0 -or $data.'4'.cells[$b][$a][7] -ne 0 -or
      $data.'4'.cells[$a][$c][6] -ne 0 -or $data.'4'.cells[$c][$a][6] -ne 1 -or
      $data.'4'.cells[$c][$a][7] -ne 0.5 -or $data.'4'.cells[$c][$a][2] -ne 1){
    throw 'Limited-game elimination was counted as a tie, complemented into a win, or duplicated.'
  }
  if($data.'4'.playerStats.a.losses -ne 1 -or $data.'4'.playerStats.a.ties -ne 0){
    throw 'Final territories, not the last-turn counter, must determine limited-game survival.'
  }
  [IO.File]::WriteAllLines($master,[string[]]@(
    $limited,
    '20261109,120003,3,50,401,4,a,400,0,0,b,400,0,12,c,400,0,0,d,400,0,30',
    '20261109,120004,1,1,41,4,a,41,0,42,b,40,0,0,c,39,0,0,d,38,0,0'
  ))
  & (Join-Path $PSScriptRoot '..\Doc\Tournament\update-bot-matrix.ps1') `
    -MasterResults $master -PlayersDirectory $root -MatrixPath $matrix -VersionCutoffsFile ''
  $html=[IO.File]::ReadAllText($matrix)
  $data=([regex]::Match($html,'const D=(\{.*?\});const sizes=',[Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value)|ConvertFrom-Json
  if($data.'4'.playerStats.a.wins -ne 1 -or $data.'4'.playerStats.a.losses -ne 2 -or
      $data.'4'.playerStats.a.ties -ne 0 -or $data.'4'.playerStats.b.losses -ne 2 -or
      $data.'4'.playerStats.b.ties -ne 1 -or $data.'4'.playerStats.d.ties -ne 2){
    throw 'Time/turn-limited player outcomes or completed-game outcomes are incorrect.'
  }
  $forward=$data.'4'.cells[$a][$b]
  $reverse=$data.'4'.cells[$b][$a]
  if($forward[7] -ne 1 -or $forward[6] -ne 0 -or $reverse[7] -ne 0.5 -or $reverse[6] -ne 1 -or
      $reverse[1] -ne 1 -or $reverse[3] -ne 1 -or $reverse[8] -ne 1 -or
      $reverse[9] -ne 0 -or $reverse[10] -ne 0 -or $reverse[11] -ne 1){
    throw 'Directional scores or tie stopping reasons cannot support correct tie filtering.'
  }
  Write-Output 'PASS: version filtering, safety-fix pooling, completed-game scoring and directional survivor-only ties at time/turn limits.'
} finally {
  Remove-Item -LiteralPath $root -Recurse -Force
}
