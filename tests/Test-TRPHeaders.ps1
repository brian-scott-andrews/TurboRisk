param(
  [string]$PlayersDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'players')
)

$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem -LiteralPath $PlayersDirectory -Filter '*.trp' -File)
if ($files.Count -eq 0) { throw "No TRP files found in $PlayersDirectory." }
$invalid = @()
foreach ($file in $files) {
  $text = [IO.File]::ReadAllText($file.FullName)
  $header = [regex]::Match($text, '(?s)^\s*\{(.*?)\}')
  if (-not $header.Success -or $header.Groups[1].Value -notmatch
      '^\s*Program:[ \t]+\S[^\r\n]*\r?\n\s*Author:[ \t]+\S[^\r\n]*\r?\n\s*Description:[ \t]+\S') {
    $invalid += $file.Name
  }
}
if ($invalid.Count) {
  throw ('Expected opening Program, Author, Description fields with same-line values: ' +
    ($invalid -join ', '))
}
Write-Output "PASS: all $($files.Count) playable TRPs use Program, Author, Description in order."
