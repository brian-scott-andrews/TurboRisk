param(
  [Parameter(Mandatory=$true)][string]$Snapshot,
  [Parameter(Mandatory=$true)][string]$RunDirectory,
  [int]$Workers=24,
  [int]$Seed=20261109,
  [switch]$PlanOnly,
  [switch]$Resume
)
$ErrorActionPreference='Stop'
$bots=@(Get-ChildItem "$Snapshot\players" -File -Filter '*.trp' | ForEach-Object BaseName | Sort-Object)
if ($bots.Count -ne 63) { throw 'This fixed design requires the approved 63-bot roster.' }
if ($Workers -lt 1 -or $Workers -gt 24) { throw 'Workers must be between 1 and 24.' }
if ($Resume -and $PlanOnly) { throw 'Resume and PlanOnly cannot be combined.' }
if ($Resume) {
  $Snapshot=Join-Path $RunDirectory 'snapshot'
  if (@(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith("$RunDirectory\workers\")
  }).Count) { throw 'Tournament workers are already running.' }
} elseif (Test-Path $RunDirectory) { throw 'Run directory already exists; preserve and inspect it rather than overwrite.' }
if (-not $Resume) {
[void][IO.Directory]::CreateDirectory($RunDirectory)
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
public static class RepresentativePlan {
  class Edge { public int To,Rev,Cap; public Edge(int t,int r,int c){To=t;Rev=r;Cap=c;} }
  class Flow {
    public List<Edge>[] G; int[] level,it;
    public Flow(int n){G=new List<Edge>[n];for(int i=0;i<n;i++)G[i]=new List<Edge>();level=new int[n];it=new int[n];}
    public void Add(int a,int b,int c){G[a].Add(new Edge(b,G[b].Count,c));G[b].Add(new Edge(a,G[a].Count-1,0));}
    int Push(int v,int t,int f){
      if(v==t)return f;
      for(;it[v]<G[v].Count;it[v]++){
        Edge e=G[v][it[v]];
        if(e.Cap<=0||level[e.To]!=level[v]+1)continue;
        int d=Push(e.To,t,Math.Min(f,e.Cap));
        if(d>0){e.Cap-=d;G[e.To][e.Rev].Cap+=d;return d;}
      }return 0;
    }
    public int Run(int s,int t){
      int total=0;
      while(true){
        for(int i=0;i<level.Length;i++)level[i]=-1;
        var q=new Queue<int>();q.Enqueue(s);level[s]=0;
        while(q.Count>0){int v=q.Dequeue();foreach(Edge e in G[v])if(e.Cap>0&&level[e.To]<0){level[e.To]=level[v]+1;q.Enqueue(e.To);}}
        if(level[t]<0)return total;
        Array.Clear(it,0,it.Length);int d;
        while((d=Push(s,t,int.MaxValue))>0)total+=d;
      }
    }
  }
  public static int[,] Make(int size,int seed){
    var rng=new Random(seed);var seq=new List<int>();
    for(int round=0;round<200;round++){
      int[] a=new int[63];bool valid;
      do{
        for(int i=0;i<63;i++)a[i]=i;
        for(int i=62;i>0;i--){int j=rng.Next(i+1),t=a[i];a[i]=a[j];a[j]=t;}
        valid=true;int rem=seq.Count%size;
        for(int i=0;i<size-rem&&rem>0;i++)
          for(int j=seq.Count-rem;j<seq.Count;j++)if(a[i]==seq[j])valid=false;
      }while(!valid);
      seq.AddRange(a);
    }
    int count=12600/size;
    int[,] result=new int[count,size];bool[,] used=new bool[count,size];
    int extra=count-(200/size)*63;
    for(int seat=0;seat<size-1;seat++){
      int source=count+63,sink=source+1;var flow=new Flow(sink+1);
      for(int g=0;g<count;g++){
        flow.Add(source,g,1);
        for(int p=0;p<size;p++)if(!used[g,p])flow.Add(g,count+seq[g*size+p],1);
      }
      for(int b=0;b<63;b++)flow.Add(count+b,sink,200/size+(((b+seat*extra)%63)<extra?1:0));
      if(flow.Run(source,sink)!=count)throw new Exception("Seat matching infeasible");
      for(int g=0;g<count;g++)foreach(Edge e in flow.G[g])
        if(e.To>=count&&e.To<count+63&&e.Cap==0){
          int b=e.To-count;result[g,seat]=b;
          for(int p=0;p<size;p++)if(seq[g*size+p]==b)used[g,p]=true;
        }
    }
    for(int g=0;g<count;g++)for(int p=0;p<size;p++)if(!used[g,p])result[g,size-1]=seq[g*size+p];
    return result;
  }
}
'@
$schedule=New-Object 'System.Collections.Generic.List[object]'
$bySize=@{}
foreach($size in 2..10){
  $plan=[RepresentativePlan]::Make($size,($Seed+$size))
  $counts=@{};$seats=@{}
  foreach($bot in $bots){$counts[$bot]=0;$seats[$bot]=New-Object 'int[]' $size}
  $games=New-Object 'System.Collections.Generic.List[object]'
  for($g=0;$g -lt $plan.GetLength(0);$g++){
    $names=@(for($p=0;$p -lt $size;$p++){$bots[$plan[$g,$p]]})
    if(@($names|Select-Object -Unique).Count -ne $size){throw 'Duplicate roster player'}
    for($p=0;$p -lt $size;$p++){$counts[$names[$p]]++;$seats[$names[$p]][$p]++}
    $games.Add([pscustomobject]@{Id=0;N=$size;Roster=$names -join ',';Seed=0})
  }
  foreach($bot in $bots){
    if($counts[$bot] -ne 200 -or @($seats[$bot]|Where-Object {
      $_ -lt [math]::Floor(200/$size) -or $_ -gt [math]::Ceiling(200/$size)
    }).Count){throw "Unbalanced schedule for $bot at $size"}
  }
  $bySize[$size]=$games
}
for($i=0;$i -lt 6300;$i++){
  foreach($size in 2..10){
    if($i -lt $bySize[$size].Count){
      $game=$bySize[$size][$i];$game.Id=$schedule.Count+1;$game.Seed=$Seed+$game.Id*101
      $schedule.Add($game)
    }
  }
}
if($schedule.Count -ne 24305){throw 'Unexpected game budget'}
$schedule|Export-Csv "$RunDirectory\schedule.csv" -NoTypeInformation
@{
  Created=(Get-Date).ToString('o');Bots=$bots;AppearancesPerBotPerSize=200
  PlayerCounts=@(2..10);Games=24305;Workers=$Workers;Seed=$Seed
  Selection='Random partition sequences conditioned on no duplicate player; capacity-matched seats, floor/ceiling balance.'
  Rules='std_map_small; random assignment; progressive/immediate cards; 180 seconds; no turn cap; 270-second watchdog.'
  Interpretation='Fixed scheduled-appearance denominator; no outcome-based stopping or completion replacement. Correlated balanced schedule; no simultaneous rank guarantees.'
  HistoricalReuse=$false;MasterImport=$false
}|ConvertTo-Json -Depth 5|Set-Content "$RunDirectory\method.json" -Encoding ASCII
Write-Output 'Validated 24305 games; each bot has 200 appearances per size and floor/ceiling-balanced seats.'
if($PlanOnly){return}
Copy-Item $Snapshot "$RunDirectory\snapshot" -Recurse
}
$frozen=Join-Path $RunDirectory 'snapshot'
if ($Resume) {
  $hashes=@(Import-Csv "$RunDirectory\input-hashes.csv")
  foreach($h in $hashes){
    if((Get-FileHash -LiteralPath $h.Path).Hash -ne $h.Hash){throw "Frozen input changed: $($h.Path)"}
  }
  $bots=@(Get-ChildItem "$frozen\players" -File -Filter '*.trp'|ForEach-Object BaseName|Sort-Object)
  $schedule=@(Import-Csv "$RunDirectory\schedule.csv"|ForEach-Object {
    [pscustomobject]@{Id=[int]$_.Id;N=[int]$_.N;Roster=$_.Roster;Seed=[int]$_.Seed}
  })
  if($schedule.Count -ne 24305 -or @($schedule.Id|Select-Object -Unique).Count -ne 24305){throw 'Invalid saved schedule'}
  $backup=Join-Path $RunDirectory ('resume-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
  [void][IO.Directory]::CreateDirectory($backup)
  foreach($name in @('attempts.csv','results.sgl','progress.json','paused.json','schedule.csv')){
    if(Test-Path "$RunDirectory\$name"){Copy-Item "$RunDirectory\$name" $backup}
  }
  $recorded=@{}
  foreach($a in (Import-Csv "$RunDirectory\attempts.csv")){
    if($recorded.ContainsKey($a.Id)){throw 'Duplicate recorded game ID'}
    $game=$schedule[[int]$a.Id-1]
    if($game.Id -ne [int]$a.Id -or $game.Roster -ne $a.Roster -or $game.Seed -ne [int]$a.Seed){throw 'Attempt differs from fixed schedule'}
    $recorded[$a.Id]=$true
  }
  foreach($file in (Get-ChildItem "$RunDirectory\workers\w*\game-*.sgl" -File)){
    if($file.BaseName -notmatch '^game-(\d+)$'){continue}
    $id=$matches[1]
    if($recorded.ContainsKey($id)){continue}
    $lines=@([IO.File]::ReadLines($file.FullName)|Where-Object {$_ -match '^\d{8},'})
    if(-not $lines.Count){continue}
    if($lines.Count -ne 1){throw 'Ambiguous recovered result'}
    $game=$schedule[[int]$id-1];$x=$lines[0].Split(',')
    $meta=(Get-Content ($file.FullName -replace '\.sgl$','.jsonl') -TotalCount 1|ConvertFrom-Json).metadata
    $names=@(for($p=0;$p -lt $game.N;$p++){$x[6+4*$p]})
    if($x.Count -ne 6+4*$game.N -or $x[5] -ne "$($game.N)" -or
      (($names|Sort-Object)-join ',') -ne (($game.Roster.Split(',')|Sort-Object)-join ',') -or
      (@($meta.players|Sort-Object id|ForEach-Object name)-join ',') -ne $game.Roster -or
      $meta.map -ne 'std_map_small.trm' -or $meta.assignment -ne 0 -or
      $meta.card_values -ne 1 -or -not $meta.immediate_trade){throw "Invalid recovered game $id"}
    [pscustomobject]@{Id=$game.Id;N=$game.N;Roster=$game.Roster;Seed=$game.Seed;
      Status=$x[2];Line=$lines[0];Log=$file.FullName}|
      Export-Csv "$RunDirectory\attempts.csv" -NoTypeInformation -Append
    $recorded[$id]=$true
  }
  # Preserve partial histories before replaying the same scheduled games.
  foreach($worker in (Get-ChildItem "$RunDirectory\workers" -Directory)){
    foreach($file in (Get-ChildItem $worker.FullName -File)){
      if($file.Name -notmatch '^(game-(\d+)\.(sgl|jsonl)|std(out|err)-(\d+)\.txt)$'){continue}
      $id=if($matches[2]){$matches[2]}else{$matches[5]}
      if(-not $recorded.ContainsKey($id)){
        $dest=Join-Path $backup $worker.Name
        [void][IO.Directory]::CreateDirectory($dest)
        Move-Item -LiteralPath $file.FullName -Destination $dest
      }
    }
  }
  $saved=@(Import-Csv "$RunDirectory\attempts.csv")
  $valid=@($saved|Where-Object {$_.Status -in @('1','4')}|ForEach-Object Line)
  [IO.File]::WriteAllLines("$RunDirectory\results.sgl",[string[]]$valid,[Text.Encoding]::ASCII)
  Write-Output "Resume: preserved $($saved.Count) recorded/recovered outcomes; pending games retain original seeds and seats."
} else {
  $hashes=@(Get-ChildItem $frozen -File -Recurse|Get-FileHash)
  $hashes|Export-Csv "$RunDirectory\input-hashes.csv" -NoTypeInformation
}
[void][IO.Directory]::CreateDirectory((Join-Path $RunDirectory 'workers'))
$totals=@{}
foreach($size in 2..10){foreach($bot in $bots){
  $totals["$size|$bot"]=[pscustomobject]@{Size=$size;Bot=$bot;Scheduled=200;Finished=0;Wins=0;Completed=0;Timeouts=0;Failures=0;WinRate=0.0;CompletedWinRate=$null}
}}
$slots=@(for($i=0;$i -lt $Workers;$i++){
  $dir=Join-Path $RunDirectory "workers\w$i"
  if(-not (Test-Path $dir)){Copy-Item $frozen $dir -Recurse}
  foreach($h in $hashes){
    $relative=$h.Path.Substring($frozen.Length+1)
    if((Get-FileHash -LiteralPath (Join-Path $dir $relative)).Hash -ne $h.Hash){throw 'Worker hash mismatch'}
  }
  [pscustomobject]@{Directory=$dir;Process=$null;Game=$null;Started=$null}
})
function Write-Dashboard {
  $rows=@($totals.Values|Sort-Object Size,@{Expression='WinRate';Descending=$true},Bot)
  $rows|Export-Csv "$RunDirectory\representative-rates.csv" -NoTypeInformation
  $running=@($slots|Where-Object Process).Count
  $summary=[pscustomobject]@{Updated=(Get-Date).ToString('o');Finished=$script:finished;Scheduled=24305;Running=$running}
  $summary|ConvertTo-Json|Set-Content "$RunDirectory\progress.json" -Encoding ASCII
  $html="<html><head><meta charset='utf-8'><meta http-equiv='refresh' content='30'><title>Representative win rates</title></head><body><h1>Representative win rates: fixed-budget study</h1><p>Updated $($summary.Updated). Finished $($summary.Finished) / 24305; running $running. Each bot: 200 scheduled appearances per size. WinRate = wins / 200 (provisional until finished); CompletedWinRate excludes timeouts and failures. No historical games; historical matchup matrix remains separate.</p>$(($rows|ConvertTo-Html -Fragment)-join '')</body></html>"
  [IO.File]::WriteAllText("$RunDirectory\index.html",$html)
}
$next=0;$script:finished=0;$last=[datetime]::MinValue
if($Resume){
  foreach($a in $saved){
    foreach($bot in $a.Roster.Split(',')){
      $row=$totals["$($a.N)|$bot"];$row.Finished++
      if($a.Status -eq '1'){$row.Completed++;if($a.Line.Split(',')[6] -eq $bot){$row.Wins++}}
      elseif($a.Status -eq '4'){$row.Timeouts++}else{$row.Failures++}
      $row.WinRate=$row.Wins/200.0
      $row.CompletedWinRate=if($row.Completed){$row.Wins/[double]$row.Completed}else{$null}
    }
    $script:finished++
  }
  $schedule=@($schedule|Where-Object {-not $recorded.ContainsKey("$($_.Id)")})
  if(Test-Path "$RunDirectory\paused.json"){Move-Item "$RunDirectory\paused.json" "$backup\paused-original.json"}
}
$pendingCount=$schedule.Count
try{
  do{
    foreach($slot in $slots){
      if($slot.Process){
        $slot.Process.Refresh()
        $watchdog=$false
        if(-not $slot.Process.HasExited -and ((Get-Date)-$slot.Started).TotalSeconds -gt 270){
          Stop-Process -Id $slot.Process.Id;$slot.Process.WaitForExit();$watchdog=$true
        }
        if(-not $slot.Process.HasExited){continue}
        $game=$slot.Game;$log=Join-Path $slot.Directory "game-$($game.Id).sgl"
        $lines=@()
        if(Test-Path $log){$lines=@([IO.File]::ReadLines($log)|Where-Object {$_ -match '^\d{8},'})}
        if($lines.Count -gt 1){throw 'Multiple results for scheduled game'}
        $line=if($lines.Count){$lines[0]}else{''}
        $status=if($line){$line.Split(',')[2]}elseif($watchdog){'watchdog'}else{'missing-result'}
        if($line){
          $x=$line.Split(',')
          $names=@(for($p=0;$p -lt $game.N;$p++){$x[6+4*$p]})
          if($x.Count -ne 6+4*$game.N -or (($names|Sort-Object)-join ',') -ne (($game.Roster.Split(',')|Sort-Object)-join ',')){throw 'Result roster mismatch'}
        }
        $action=Join-Path $slot.Directory "game-$($game.Id).jsonl"
        if(Test-Path $action){
          $meta=(Get-Content $action -TotalCount 1|ConvertFrom-Json).metadata
          if($meta.map -ne 'std_map_small.trm' -or $meta.assignment -ne 0 -or $meta.card_values -ne 1 -or -not $meta.immediate_trade -or
            (@($meta.players|Sort-Object id|ForEach-Object name)-join ',') -ne $game.Roster){throw 'Rules or seat mismatch'}
        }elseif($status -in @('1','4')){throw 'Missing action metadata for eligible result'}
        [pscustomobject]@{Id=$game.Id;N=$game.N;Roster=$game.Roster;Seed=$game.Seed;Status=$status;Line=$line;Log=$log}|
          Export-Csv "$RunDirectory\attempts.csv" -NoTypeInformation -Append
        if($status -in @('1','4')){[IO.File]::AppendAllLines("$RunDirectory\results.sgl",[string[]]@($line),[Text.Encoding]::ASCII)}
        foreach($bot in $game.Roster.Split(',')){
          $row=$totals["$($game.N)|$bot"];$row.Finished++
          if($status -eq '1'){$row.Completed++;if($x[6] -eq $bot){$row.Wins++}}
          elseif($status -eq '4'){$row.Timeouts++}
          else{$row.Failures++;Write-Warning "Game $($game.Id), $bot : $status; preserved $log"}
          $row.WinRate=$row.Wins/200.0
          $row.CompletedWinRate=if($row.Completed){$row.Wins/[double]$row.Completed}else{$null}
        }
        $script:finished++;$slot.Process=$null
      }
      if($next -lt $schedule.Count){
        $game=$schedule[$next];$next++
        [IO.File]::WriteAllText("$($slot.Directory)\schedule.csv",$game.Roster+[Environment]::NewLine,[Text.Encoding]::ASCII)
        $args="--schedule schedule.csv --map std_map_small.trm --turn-limit 0 --time-limit 180 --seed $($game.Seed) --error-dump --game-log game-$($game.Id).sgl --action-log game-$($game.Id).jsonl"
        $slot.Game=$game;$slot.Started=Get-Date
        $slot.Process=Start-Process "$($slot.Directory)\TRSimCLI.exe" -WorkingDirectory $slot.Directory -ArgumentList $args -WindowStyle Hidden `
          -RedirectStandardOutput "$($slot.Directory)\stdout-$($game.Id).txt" -RedirectStandardError "$($slot.Directory)\stderr-$($game.Id).txt" -PassThru
      }
    }
    if(((Get-Date)-$last).TotalSeconds -ge 30){Write-Dashboard;$last=Get-Date;Write-Output "Finished $script:finished / 24305; dispatched $next."}
    if($next -lt $pendingCount -or @($slots|Where-Object Process).Count){Start-Sleep -Seconds 1}
  }while($next -lt $pendingCount -or @($slots|Where-Object Process).Count)
  Write-Dashboard
  Write-Output 'Fixed-budget representative study complete. Results are not appended to master automatically.'
}finally{
  foreach($slot in $slots){if($slot.Process -and -not $slot.Process.HasExited){Stop-Process -Id $slot.Process.Id -ErrorAction SilentlyContinue}}
}
