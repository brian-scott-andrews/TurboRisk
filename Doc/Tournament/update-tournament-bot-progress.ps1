param(
  [Parameter(Mandatory=$true)][string]$RunDirectory,
  [Parameter(Mandatory=$true)][string[]]$FocusBot,
  [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot 'run-multiplayer-confidence-tournament.ps1'),
  [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Update-TournamentBotProgress'
}, $false)
if (-not $function) { throw 'Tournament dashboard function is missing.' }
. ([scriptblock]::Create($function.Extent.Text))
Update-TournamentBotProgress -RunDirectory $RunDirectory -FocusBot $FocusBot -OutputPath $OutputPath
