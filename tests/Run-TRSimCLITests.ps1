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
  $helpResult = Invoke-TRSimCLI $cli @('--help') $runA
  Assert-ExitCode $helpResult 0 'Command-line help'
  if ($helpResult.StdOut -notmatch '--statistically-significant-sample') {
    throw "Command-line help omitted --statistically-significant-sample.`n$($helpResult.StdOut)"
  }
  Write-Output 'PASS: --help documents statistically significant sampling.'

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
    '--game-log', (Join-Path $runB 'seed.sgl'), '--cpu-log', (Join-Path $runB 'seed.scl'),
    '--action-log', 'actions.jsonl'
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

  $actionPath = Join-Path $runB 'actions.jsonl'
  if (-not (Test-Path -LiteralPath $actionPath)) {
    throw 'Relative action log was not created in the caller working directory.'
  }
  $records = @(Get-Content -LiteralPath $actionPath | ForEach-Object { $_ | ConvertFrom-Json })
  $header = $records[0]
  if ($header.type -ne 'game' -or $header.format -ne 'TurboRisk.actions' -or
      $header.version -ne 1 -or $header.metadata.players.Count -ne 3) {
    throw 'Action log omitted its versioned game header or roster.'
  }
  $owners = New-Object int[] 43
  $armies = New-Object int[] 43
  $sequence = 0
  $kinds = @{}
  foreach ($event in $records | Select-Object -Skip 1) {
    $sequence++
    if ($event.type -ne 'action' -or $event.game -ne $header.game -or
        $event.sequence -ne $sequence) {
      throw "Invalid action identity/sequence at event $sequence."
    }
    $kinds[[int]$event.kind] = $true
    $from = [int]$event.from
    $to = [int]$event.to
    if ($event.kind -in @(1, 2, 3, 4, 5)) {
      if ($from -gt 0 -and $armies[$from] -ne $event.from_before) {
        throw "Source snapshot mismatch at event $sequence."
      }
      if ($armies[$to] -ne $event.to_before) {
        throw "Destination snapshot mismatch at event $sequence."
      }
      if ($event.kind -eq 1) {
        if ($owners[$to] -ne 0 -or $event.to_after -ne 1) {
          throw "Invalid initial assignment at event $sequence."
        }
        $owners[$to] = $event.player
      } elseif ($event.kind -eq 2) {
        if ($owners[$to] -ne $event.player -or
            $event.to_after - $event.to_before -ne $event.armies) {
          throw "Invalid placement at event $sequence."
        }
      } elseif ($event.kind -eq 3) {
        if ($owners[$from] -ne $event.player -or $owners[$to] -ne $event.opponent -or
            $event.player -eq $event.opponent -or
            $event.from_after + $event.to_after -ne
              $event.from_before + $event.to_before - $event.attacker_loss - $event.defender_loss) {
          throw "Combat identity/casualty mismatch at event $sequence."
        }
        if ($event.captured -eq 1) { $owners[$to] = $event.player }
      } else {
        if ($owners[$from] -ne $event.player -or $owners[$to] -ne $event.player -or
            $event.from_before - $event.from_after -ne $event.armies -or
            $event.to_after - $event.to_before -ne $event.armies) {
          throw "Troop movement mismatch at event $sequence."
        }
      }
      if ($from -gt 0) { $armies[$from] = $event.from_after }
      $armies[$to] = $event.to_after
    }
  }
  foreach ($kind in @(1, 2, 3, 6, 7, 8, 11)) {
    if (-not $kinds.ContainsKey($kind)) { throw "Action kind $kind was not exercised." }
  }
  if ($records[-1].kind -ne 11) { throw 'Action log omitted the game-ending status.' }
  Write-Output 'PASS: JSONL actions reconstruct the board, preserve RNG results, and include combat outcomes.'

  $historyPlayer = @'
procedure CheckHistory;
var
  I: integer;
begin
  if UBufferGet(499) = 0 then begin
    if HCount < 1 then begin
      UMessageOn;
      UMessage('ACTION HISTORY API FAILED');
      UAbortGame;
    end;
    for I := 1 to HCount do begin
      if (HGet(I, AF_KIND) < AK_ASSIGNMENT) or
         (HGet(I, AF_KIND) > AK_GAME_END) then begin
        UMessageOn;
        UMessage('ACTION HISTORY API FAILED');
        UAbortGame;
      end;
    end;
    UBufferSet(499, HCount);
    UMessageOn;
    UMessage('ACTION HISTORY API OK');
  end;
end;

'@
  $simpleSource = [IO.File]::ReadAllText((Join-Path $playersPath 'simple.trp'))
  $simpleSource = $simpleSource.Replace(
    '// perform attack with best chances; stop after 1 conquest;',
    'CheckHistory; // exercise the registered action API')
  if ($simpleSource -notmatch 'CheckHistory; // exercise') {
    throw 'Could not instrument the history API regression bot.'
  }
  Set-Content -LiteralPath (Join-Path $playersPath 'cli_history_test.trp') `
    -Value ($historyPlayer + $simpleSource) -Encoding ASCII
  $historySchedule = Join-Path $testRoot 'action-history.csv'
  Set-Content -LiteralPath $historySchedule `
    -Value @('cli_history_test,simple', 'cli_history_test,digger') -Encoding ASCII
  $historyResult = Invoke-TRSimCLI $cli @(
    '--schedule', $historySchedule, '--turn-limit', '100', '--seed', '123',
    '--game-log', (Join-Path $runA 'history.sgl'), '--cpu-log', (Join-Path $runA 'history.scl'),
    '--action-log', $actionPath
  ) $runA
  Assert-ExitCode $historyResult 0 'TRP action history API'
  if ($historyResult.StdOut -match 'ACTION HISTORY API FAILED' -or
      [regex]::Matches($historyResult.StdOut, 'ACTION HISTORY API OK').Count -ne 2) {
    throw "History API was unavailable or did not reset per game.`n$($historyResult.StdOut)"
  }
  $headers = @(Get-Content -LiteralPath $actionPath |
    ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.type -eq 'game' })
  if ($headers.Count -ne 3 -or @($headers.game | Select-Object -Unique).Count -ne 3) {
    throw 'Multiple action-logged games did not append as distinct game segments.'
  }
  Write-Output 'PASS: TRPs can read action history; multiple games reset history and append separate segments.'

  $badHistory = $simpleSource.Replace(
    'CheckHistory; // exercise the registered action API', 'FromTerritory := HGet(0, AF_KIND);')
  Set-Content -LiteralPath (Join-Path $playersPath 'cli_bad_history_test.trp') `
    -Value $badHistory -Encoding ASCII
  $badSchedule = Join-Path $testRoot 'bad-history.csv'
  Set-Content -LiteralPath $badSchedule -Value 'cli_bad_history_test,simple' -Encoding ASCII
  $badResult = Invoke-TRSimCLI $cli @(
    '--schedule', $badSchedule, '--turn-limit', '100', '--seed', '123',
    '--game-log', (Join-Path $runA 'bad-history.sgl'), '--cpu-log', (Join-Path $runA 'bad-history.scl')
  ) $runA
  Assert-ExitCode $badResult 1 'Invalid action index runtime error'
  if ($badResult.StdOut -notmatch 'Action index 0 is outside') {
    throw "Invalid history access did not report an explicit script error.`n$($badResult.StdOut)"
  }
  $collisionResult = Invoke-TRSimCLI $cli @(
    '--schedule', $seedSchedule, '--action-log', $seedSchedule,
    '--game-log', (Join-Path $runA 'collision.sgl'), '--cpu-log', (Join-Path $runA 'collision.scl')
  ) $runA
  Assert-ExitCode $collisionResult 2 'Action log colliding with schedule'
  if ((Get-Content -LiteralPath $seedSchedule) -ne 'randy,pitbull,simple') {
    throw 'Action log overwrote the schedule.'
  }
  $invalidLog = Join-Path $runA 'invalid-action-log.txt'
  Set-Content -LiteralPath $invalidLog -Value 'Keep this file unchanged' -Encoding ASCII
  $invalidLogResult = Invoke-TRSimCLI $cli @(
    '--schedule', $seedSchedule, '--action-log', $invalidLog,
    '--game-log', (Join-Path $runA 'invalid.sgl'), '--cpu-log', (Join-Path $runA 'invalid.scl')
  ) $runA
  Assert-ExitCode $invalidLogResult 2 'Unrecognized existing action log'
  if ((Get-Content -LiteralPath $invalidLog) -ne 'Keep this file unchanged') {
    throw 'Unrecognized action log file was modified.'
  }
  Write-Output 'PASS: invalid TRP history access is explicit and logging protects unrelated files.'

  $sampleSchedule = Join-Path $testRoot 'sample.csv'
  Set-Content -LiteralPath $sampleSchedule -Value 'simple,randy' -Encoding ASCII
  $sampleResult = Invoke-TRSimCLI $cli @(
    '--schedule', $sampleSchedule, '--turn-limit', '1', '--seed', '123',
    '--statistically-significant-sample',
    '--game-log', (Join-Path $runA 'sample.sgl'), '--cpu-log', (Join-Path $runA 'sample.scl')
  ) $runA
  Assert-ExitCode $sampleResult 0 'Statistically significant sample cap'
  $sampleGamesStarted = [regex]::Matches($sampleResult.StdOut, 'Game #\d+ started').Count
  if ($sampleGamesStarted -ne 10) {
    throw "Statistical sample mode should repeat a one-game schedule to its 10-game cap; started $sampleGamesStarted games."
  }
  if ($sampleResult.StdOut -notmatch 'Statistically significant sample not reached within the 10-game limit') {
    throw "Statistical sample mode did not report reaching its cap.`n$($sampleResult.StdOut)"
  }
  Write-Output 'PASS: statistical sample mode repeats schedules and stops at the 10x cap.'

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

  $placementCases = @(
    @{ Seed = 95065; Roster = 'descartes,australian09,raptorbot,frank' },
    @{ Seed = 95005; Roster = 'frank+,kingmaker,Fluid,australian' },
    @{ Seed = 95012; Roster = 'hunter,descartes09,finisher,frank+' }
  )
  $placementBaselines = @{}
  $runtimeIni = Join-Path $runtimeRoot 'TurboRisk.INI'
  foreach ($configuration in @('no-ini', 'with-ini')) {
    if ($configuration -eq 'with-ini') {
      Set-Content -LiteralPath $runtimeIni -Encoding ASCII -Value @(
        '[Map]', 'File=std_map_small.trm', '[Rules]', 'Assignment=0'
      )
    }
    foreach ($case in $placementCases) {
      $prefix = Join-Path $runA ("placement-$configuration-$($case.Seed)")
      Set-Content -LiteralPath ($prefix + '.csv') -Value $case.Roster -Encoding ASCII
      $placementResult = Invoke-TRSimCLI $cli @(
        '--schedule', ($prefix + '.csv'), '--turn-limit', '100',
        '--seed', ([string]$case.Seed), '--error-dump',
        '--game-log', ($prefix + '.sgl'), '--cpu-log', ($prefix + '.scl'),
        '--action-log', ($prefix + '.jsonl')
      ) $runA
      Assert-ExitCode $placementResult 0 "Placement reload regression ($configuration, seed $($case.Seed))"
      if ($placementResult.StdOut -match 'TRP error:|Access violation') {
        throw "Placement reload regression reported a runtime error.`n$($placementResult.StdOut)"
      }
      $endEvent = Get-Content -LiteralPath ($prefix + '.jsonl') |
        Select-Object -Last 1 | ConvertFrom-Json
      if ($endEvent.kind -ne 11 -or $endEvent.armies -notin @(1, 3)) {
        throw "Placement regression did not end normally or at its turn limit: $prefix"
      }
      $stable = Get-StableGameResult ($prefix + '.sgl')
      if ($configuration -eq 'no-ini') {
        $placementBaselines[$case.Seed] = $stable
      } elseif ($stable -ne $placementBaselines[$case.Seed]) {
        throw "INI presence changed the seeded Placement regression result for $($case.Seed)."
      }
    }
  }
  Remove-Item -LiteralPath $runtimeIni
  Write-Output 'PASS: all three reported Placement-crash rosters run with action logs, with and without INI.'

  $simpleName = 'simple.trp'
  $botFiles = Get-ChildItem -LiteralPath $playersPath -Filter '*.trp' -File |
    Where-Object { $_.Name -ne $simpleName -and $_.Name -notlike 'cli_*_test.trp' } |
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
