param(
  [Parameter(Mandatory = $true)][string]$MasterResults,
  [string]$PlayersDirectory = (Join-Path (Get-Location).Path 'players'),
  [string]$MatrixPath = '',
  [string]$VersionCutoffsFile = ''
)

$ErrorActionPreference = 'Stop'
if (-not $MatrixPath) { $MatrixPath = Join-Path $PSScriptRoot 'bot-matrix.html' }
if (-not $PSBoundParameters.ContainsKey('VersionCutoffsFile')) {
  $VersionCutoffsFile = Join-Path $PSScriptRoot 'current-version-cutoffs.csv'
}
$versionCutoffs = @{}
if ($VersionCutoffsFile) {
  foreach ($entry in (Import-Csv -LiteralPath $VersionCutoffsFile)) {
    if (-not $entry.Bot -or $entry.Cutoff -notmatch '^\d{14}$') {
      throw 'Invalid current-version cutoff.'
    }
    $versionCutoffs[$entry.Bot] = $entry.Cutoff
  }
}
$bots = @(Get-ChildItem -LiteralPath $PlayersDirectory -Filter '*.trp' -File | ForEach-Object BaseName)
[Array]::Sort($bots, [StringComparer]::Ordinal)
if ($bots.Count -lt 2) { throw 'At least two player scripts are required.' }
$botSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($bot in $bots) { [void]$botSet.Add($bot) }
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$pairs = @{}
$players = @{}
foreach ($size in 2..10) {
  $pairs[$size] = @{}
  $players[$size] = @{}
  foreach ($bot in $bots) {
    $players[$size][$bot] = @{completed=0;timeouts=0;turnLimits=0;wins=0;losses=0;ties=0;limitedLosses=0}
  }
}

foreach ($line in [IO.File]::ReadAllLines((Resolve-Path $MasterResults).Path)) {
  if (-not $seen.Add($line)) { continue }
  $x = $line.Split(',')
  $size = 0
  if ($x.Count -lt 14 -or $x[2] -notin @('1','3','4') -or
      -not [int]::TryParse($x[5], [ref]$size) -or $size -lt 2 -or $size -gt 10 -or
      $x.Count -lt (6 + 4 * $size)) { continue }
  $names = New-Object 'string[]' $size
  $turns = New-Object 'int[]' $size
  $territories = New-Object 'int[]' $size
  $excluded = $false
  for ($i = 0; $i -lt $size; $i++) {
    $name = $x[6 + 4 * $i]
    if ($name -eq 'brainless_iv pre-occupation-fix') { $name = 'brainless_iv' }
    if ($name -eq 'brainless V legacy') { $name = 'brainless V' }
    $turns[$i] = [int]$x[7 + 4 * $i]
    $territories[$i] = [int]$x[9 + 4 * $i]
    if ($x[0] -lt '20261023') {
      if ($name -eq 'actuary') { $excluded = $true }
      if ($name -eq 'doomstack') { $name = 'challenger' }
    }
    if (($x[0] + $x[1]) -lt '20261027110000') {
      if ($name -eq 'brainless vi') { $name = 'brainless vi legacy' }
    }
    if ($versionCutoffs.ContainsKey($name) -and
        ($x[0] + $x[1]) -lt $versionCutoffs[$name]) {
      $name += ' pre-current-version'
    }
    $names[$i] = $name
  }
  if ($excluded) { continue }
  $timeout = $x[2] -eq '4'
  $turnLimit = $x[2] -eq '3'
  $limited = $timeout -or $turnLimit
  for ($i = 0; $i -lt $size; $i++) {
    $name = $names[$i]
    if (-not $botSet.Contains($name)) { continue }
    $stats = $players[$size][$name]
    if ($timeout) { $stats.timeouts++ }
    elseif ($turnLimit) { $stats.turnLimits++ }
    else { $stats.completed++ }
    if ($limited) {
      if ($territories[$i] -gt 0) { $stats.ties++ }
      else { $stats.losses++; $stats.limitedLosses++ }
    } elseif ($i -eq 0) { $stats.wins++ }
    else { $stats.losses++ }
  }
  for ($i = 0; $i -lt $size; $i++) {
    if (-not $botSet.Contains($names[$i])) { continue }
    for ($j = $i + 1; $j -lt $size; $j++) {
      if (-not $botSet.Contains($names[$j]) -or $names[$i] -eq $names[$j]) { continue }
      $forward = [string]::CompareOrdinal($names[$i], $names[$j]) -lt 0
      $key = if ($forward) { "$($names[$i])|$($names[$j])" } else { "$($names[$j])|$($names[$i])" }
      if (-not $pairs[$size].ContainsKey($key)) {
        $pairs[$size][$key] = @{
          N=0;Scores=@(0.0,0.0);Completed=0;Timeouts=0;TurnLimits=0
          Ties=@(0,0);CompletedTies=0;TimeoutTies=@(0,0);TurnLimitTies=@(0,0)
        }
      }
      $score = if ($limited) { if ($territories[$i] -gt 0) { 0.5 } else { 0.0 } }
        elseif ($i -eq 0) { 1.0 }
        elseif ($j -eq 0) { 0.0 } elseif ($turns[$i] -gt $turns[$j]) { 1.0 }
        elseif ($turns[$i] -lt $turns[$j]) { 0.0 } else { 0.5 }
      $otherScore = if ($limited) { if ($territories[$j] -gt 0) { 0.5 } else { 0.0 } }
        else { 1.0 - $score }
      $cell = $pairs[$size][$key]
      $cell.N++
      $direction = if ($forward) { 0 } else { 1 }
      $scores = @($score,$otherScore)
      for ($side = 0; $side -lt 2; $side++) {
        $d = if ($side -eq 0) { $direction } else { 1 - $direction }
        $cell.Scores[$d] += $scores[$side]
        if ($scores[$side] -eq 0.5) {
          $cell.Ties[$d]++
          if ($timeout) { $cell.TimeoutTies[$d]++ }
          elseif ($turnLimit) { $cell.TurnLimitTies[$d]++ }
        }
      }
      if ($timeout) { $cell.Timeouts++ }
      elseif ($turnLimit) { $cell.TurnLimits++ }
      else {
        $cell.Completed++
        if ($score -eq 0.5) { $cell.CompletedTies++ }
      }
    }
  }
}

$data = @{}
foreach ($size in 2..10) {
  $rows = New-Object 'System.Collections.Generic.List[object]'
  $averages = New-Object 'System.Collections.Generic.List[double]'
  foreach ($a in $bots) {
    $row = New-Object 'System.Collections.Generic.List[object]'
    $sum = 0.0
    $count = 0
    foreach ($b in $bots) {
      if ($a -eq $b) { $row.Add($null); continue }
      $forward = [string]::CompareOrdinal($a, $b) -lt 0
      $key = if ($forward) { "$a|$b" } else { "$b|$a" }
      $cell = $pairs[$size][$key]
      if (-not $cell) { $row.Add($null); continue }
      $direction = if ($forward) { 0 } else { 1 }
      $score = $cell.Scores[$direction]
      $alpha = 0.5 + $score
      $beta = 0.5 + $cell.N - $score
      $total = $alpha + $beta
      $mean = $alpha / $total
      $margin = 1.959963984540054 * [Math]::Sqrt(($alpha * $beta) / ($total * $total * ($total + 1)))
      $rate = $score / $cell.N
      $displayRate = if ($size -eq 2) { $rate } else { $mean }
      $row.Add(@([Math]::Round($displayRate,6),$cell.Completed,$cell.N,$cell.Timeouts,
        [Math]::Round([Math]::Max(0.0,$mean-$margin),6),
        [Math]::Round([Math]::Min(1.0,$mean+$margin),6),$cell.Ties[$direction],$score,
        $cell.TurnLimits,$cell.CompletedTies,$cell.TimeoutTies[$direction],$cell.TurnLimitTies[$direction]))
      if ($size -eq 2) {
        $sum += $rate
        $count++
      } else {
        $sum += $score
        $count += $cell.N
      }
    }
    $rows.Add($row.ToArray())
    $averages.Add($(if ($count) { [Math]::Round($sum/$count,6) } else { 0.5 }))
  }
  $data["$size"] = @{bots=$bots;cells=$rows.ToArray();avg=$averages.ToArray();playerStats=$players[$size]}
  Write-Output ("{0} players: {1}/{2} matchups with results." -f $size,$pairs[$size].Count,($bots.Count*($bots.Count-1)/2))
}
$html = [IO.File]::ReadAllText((Resolve-Path $MatrixPath).Path)
$match = [regex]::Match($html, 'const D=(\{.*?\});\s*const sizes=', [Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $match.Success) { throw "Could not locate matrix data in $MatrixPath." }
$payload = ConvertTo-Json -InputObject $data -Depth 100 -Compress
$updated = $html.Substring(0,$match.Index) + "const D=$payload;const sizes=" + $html.Substring($match.Index+$match.Length)
$policyNote = ' Valid pre-safety-fix games are pooled with the same strategy; legacy strategy versions remain separate.'
if (-not $updated.Contains($policyNote)) {
  $updated = $updated.Replace('pre-2026-10-23 Actuary games are excluded.',
    'pre-2026-10-23 Actuary games are excluded.' + $policyNote)
}
$vPoolingNote = ' Pre-restoration Brainless V results are pooled with V; the VI route-planner strategy boundary remains separate.'
if (-not $updated.Contains($vPoolingNote)) {
  $updated = $updated.Replace($policyNote, $policyNote + $vPoolingNote)
}
[IO.File]::WriteAllText((Resolve-Path $MatrixPath).Path,$updated,(New-Object System.Text.UTF8Encoding($false)))
