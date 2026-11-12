$ErrorActionPreference = 'Stop'
$directory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
[void][IO.Directory]::CreateDirectory($directory)
try {
  $heading = '<h2>Representative outright wins (new uniformly sampled rosters only)</h2>'
  [IO.File]::WriteAllText((Join-Path $directory 'index.html'), "<html><body>$heading<table>unused</table></body></html>")
  @(
    [pscustomobject]@{Size=2;Bot='a';Target=0}
    [pscustomobject]@{Size=2;Bot='b';Target=0}
  ) | Export-Csv (Join-Path $directory 'representative-win-rates.csv') -NoTypeInformation
  @(
    [pscustomobject]@{N=2;Roster='a,b';Status='1';Line='20261109,120000,1,0,10,2,a,10,0,42,b,9,0,0'}
    [pscustomobject]@{N=2;Roster='a,b';Status='4';Line=''}
    [pscustomobject]@{N=2;Roster='a,b';Status='setup-error';Line=''}
  ) | Export-Csv (Join-Path $directory 'attempts.csv') -NoTypeInformation
  $script = Join-Path $PSScriptRoot '..\Doc\Tournament\update-tournament-bot-progress.ps1'
  & $script -RunDirectory $directory -FocusBot a,b
  & $script -RunDirectory $directory -FocusBot a,b
  $rows = @(Import-Csv (Join-Path $directory 'bot-game-progress.csv'))
  if ($rows.Count -ne 2) { throw 'Missing bot rows' }
  foreach ($row in $rows) {
    if ($row.Completed -ne 1 -or $row.Timeouts -ne 1 -or
        $row.OtherIncompleteAttempts -ne 1 -or $row.FinishedAttempts -ne 3) { throw 'Incorrect attempt totals' }
  }
  if ($rows[0].Wins -ne 1 -or $rows[1].Losses -ne 1) { throw 'Incorrect winner attribution' }
  $html = [IO.File]::ReadAllText((Join-Path $directory 'index.html'))
  if ($html.Contains($heading) -or ([regex]::Matches($html,'bot-progress-start')).Count -ne 1) {
    throw 'Zero-target table visible or duplicate progress table'
  }
  [pscustomobject]@{Size=2;Bot='a';Target=20} |
    Export-Csv (Join-Path $directory 'representative-win-rates.csv') -NoTypeInformation
  [IO.File]::WriteAllText((Join-Path $directory 'index.html'), "<html><body>$heading<table>retained</table></body></html>")
  & $script -RunDirectory $directory -FocusBot a
  if (-not ([IO.File]::ReadAllText((Join-Path $directory 'index.html'))).Contains('<table>retained</table>')) {
    throw 'Active representative table removed'
  }
  Write-Output 'Tournament bot progress tests passed.'
} finally {
  Remove-Item -LiteralPath $directory -Recurse -Force
}
