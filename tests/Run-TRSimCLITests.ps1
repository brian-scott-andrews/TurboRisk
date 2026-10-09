param(
  [string] $ExecutablePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'TRSimCLI.exe')
)

$ErrorActionPreference = 'Stop'

function Quote-ProcessArgument([string] $Value) {
  return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-TRSimCLI(
  [string] $Executable,
  [string[]] $Arguments,
  [string] $WorkingDirectory,
  [int] $TimeoutMilliseconds = 300000
) {
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $Executable
  $startInfo.Arguments = (($Arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    throw "Failed to start TRSimCLI at $Executable"
  }

  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  if (-not $process.WaitForExit($TimeoutMilliseconds)) {
    $process.Kill()
    throw "TRSimCLI exceeded the $TimeoutMilliseconds ms timeout."
  }
  $process.WaitForExit()

  return [pscustomobject]@{
    ExitCode = $process.ExitCode
    StdOut = $stdoutTask.Result
    StdErr = $stderrTask.Result
  }
}

function Assert-ExitCode($Result, [int] $Expected, [string] $Scenario) {
  if ($Result.ExitCode -ne $Expected) {
    throw "$Scenario failed with exit code $($Result.ExitCode).`n$($Result.StdOut)`n$($Result.StdErr)"
  }
}

function Get-StableGameResult([string] $Path) {
  $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match '^\d{8},' } | Select-Object -Last 1
  if (-not $line) {
    throw "No game result row found in $Path"
  }
  $fields = $line -split ','
  if ($fields.Count -lt 5) {
    throw "Unexpected game result format in ${Path}: $line"
  }
  return ($fields[4..($fields.Count - 1)] -join ',')
}

if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
  throw "TRSimCLI executable not found: $ExecutablePath`nBuild it with C:\lazarus\lazbuild.exe .\TRSimCLI.lpi"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $env:TEMP ('TurboRisk-TRSimCLI-tests-' + [guid]::NewGuid().ToString('N'))
$runtimeRoot = Join-Path $testRoot 'runtime'
$playersPath = Join-Path $runtimeRoot 'players'
$mapsPath = Join-Path $runtimeRoot 'maps'
$runA = Join-Path $testRoot 'run-a'
$runB = Join-Path $testRoot 'run-b'
$runDefaults = Join-Path $testRoot 'run-defaults'

try {
  New-Item -ItemType Directory -Path $playersPath, $mapsPath, $runA, $runB, $runDefaults | Out-Null
  Copy-Item -LiteralPath $ExecutablePath -Destination (Join-Path $runtimeRoot 'TRSimCLI.exe')
  Copy-Item -Path (Join-Path $repoRoot 'players\*.trp') -Destination $playersPath
  Copy-Item -Path (Join-Path $repoRoot 'maps\*') -Destination $mapsPath -Recurse

  $cli = Join-Path $runtimeRoot 'TRSimCLI.exe'
  $messagePlayer = [System.IO.File]::ReadAllText((Join-Path $playersPath 'simple.trp'))
  $messagePlayer = [regex]::Replace(
    $messagePlayer,
    'begin\s*end\.\s*$',
    "begin`r`n  UMessageOn();`r`n  UMessage('TRSim CLI message regression');`r`nend.`r`n"
  )
  if ($messagePlayer -notmatch 'TRSim CLI message regression') {
    throw 'Could not create the UMessage regression player from simple.trp.'
  }
  Set-Content -LiteralPath (Join-Path $playersPath 'cli_message_test.trp') -Value $messagePlayer -Encoding ASCII
  $messageSchedule = Join-Path $testRoot 'message.csv'
  Set-Content -LiteralPath $messageSchedule -Value 'cli_message_test,simple' -Encoding ASCII
  $messageResult = Invoke-TRSimCLI $cli @(
    '--schedule', $messageSchedule,
    '--turn-limit', '100',
    '--seed', '123',
    '--game-log', (Join-Path $testRoot 'message.sgl'),
    '--cpu-log', (Join-Path $testRoot 'message.scl')
  ) $runA 30000
  Assert-ExitCode $messageResult 0 'Headless UMessage regression'
  if ($messageResult.StdOut -notmatch 'cli_message_test - TRSim CLI message regression') {
    throw "Headless UMessage output was not printed to stdout.`n$($messageResult.StdOut)"
  }
  Write-Output 'PASS: UMessage prints to stdout without blocking the headless simulation.'

  $seedSchedule = Join-Path $testRoot 'seed.csv'
  Set-Content -LiteralPath $seedSchedule -Value 'randy,pitbull,simple' -Encoding ASCII
  $seedA = Invoke-TRSimCLI $cli @(
    '--schedule', $seedSchedule, '--turn-limit', '100', '--seed', '123',
    '--game-log', (Join-Path $runA 'seed.sgl'), '--cpu-log', (Join-Path $runA 'seed.scl')
  ) $runA
  $seedB = Invoke-TRSimCLI $cli @(
    '--schedule', $seedSchedule, '--turn-limit', '100', '--seed', '123',
    '--game-log', (Join-Path $runB 'seed.sgl'), '--cpu-log', (Join-Path $runB 'seed.scl')
  ) $runB
  Assert-ExitCode $seedA 0 'First seeded simulation'
  Assert-ExitCode $seedB 0 'Repeated seeded simulation'
  $stableA = Get-StableGameResult (Join-Path $runA 'seed.sgl')
  $stableB = Get-StableGameResult (Join-Path $runB 'seed.sgl')
  if ($stableA -ne $stableB) {
    throw "Identical seeds and rosters produced different game results:`n$stableA`n$stableB"
  }
  if ($seedA.StdOut -match '\[verbose\]') {
    throw 'Verbose decision output was printed without the --verbose option.'
  }
  Write-Output 'PASS: identical seeds and rosters produce identical stable game results.'

  $verboseSchedule = Join-Path $testRoot 'verbose.csv'
  Set-Content -LiteralPath $verboseSchedule -Value 'digger,simple' -Encoding ASCII
  $verboseResult = Invoke-TRSimCLI $cli @(
    '--schedule', $verboseSchedule, '--turn-limit', '100', '--seed', '123', '--verbose',
    '--game-log', (Join-Path $runA 'verbose.sgl'), '--cpu-log', (Join-Path $runA 'verbose.scl')
  ) $runA
  Assert-ExitCode $verboseResult 0 'Verbose decision logging'
  foreach ($decision in @('Placement', 'Attack result', 'Fortification')) {
    if ($verboseResult.StdOut -notmatch "\[verbose\].*: $decision") {
      throw "Verbose output did not include $decision decisions.`n$($verboseResult.StdOut)"
    }
  }
  Write-Output 'PASS: --verbose reports placements, attack outcomes, and fortification decisions.'

  $defaultResult = Invoke-TRSimCLI $cli @(
    '--schedule', $seedSchedule, '--turn-limit', '100', '--seed', '123'
  ) $runDefaults
  Assert-ExitCode $defaultResult 0 'Default log location regression'
  foreach ($logName in @('TRSimCLI.sgl', 'TRSimCLI.scl')) {
    if (-not (Test-Path -LiteralPath (Join-Path $runDefaults $logName) -PathType Leaf)) {
      throw "Expected default log was not created in the working directory: $logName"
    }
  }
  Write-Output 'PASS: default game and CPU logs are created in the caller working directory.'

  $simpleName = 'simple.trp'
  $botFiles = Get-ChildItem -LiteralPath $playersPath -Filter '*.trp' -File |
    Where-Object { $_.Name -ne $simpleName -and $_.Name -ne 'cli_message_test.trp' } |
    Sort-Object Name
  $botSchedule = Join-Path $testRoot 'bot-smoke.csv'
  $botLines = foreach ($bot in $botFiles) {
    '{0},simple' -f [System.IO.Path]::GetFileNameWithoutExtension($bot.Name)
  }
  Set-Content -LiteralPath $botSchedule -Value $botLines -Encoding ASCII
  $botResult = Invoke-TRSimCLI $cli @(
    '--schedule', $botSchedule,
    '--turn-limit', '100',
    '--seed', '123',
    '--verbose',
    '--game-log', (Join-Path $testRoot 'bot-smoke.sgl'),
    '--cpu-log', (Join-Path $testRoot 'bot-smoke.scl')
  ) $testRoot
  Assert-ExitCode $botResult 0 'All-player bot smoke sweep'
  $expectedGames = @($botFiles).Count
  $completedGames = ([regex]::Matches($botResult.StdOut, 'Game #\d+ (?:completed|aborted, turn limit reached|aborted, time limit reached)')).Count
  if ($completedGames -ne $expectedGames) {
    throw "Bot smoke sweep reported $completedGames game outcomes; expected $expectedGames."
  }
  if ($botResult.StdOut -notmatch '\[verbose\].*: Placement:') {
    throw 'The verbose bot smoke sweep did not report TRP decisions.'
  }
  Write-Output "PASS: all $expectedGames TRP bots completed a verbose scheduled game against simple."
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
