# TRSim CLI help

`TRSimCLI` runs scheduled TRP games without showing the simulator GUI. Each game uses the exact roster on its schedule line.

Build the console executable with:

```powershell
C:\lazarus\lazbuild.exe .\TRSimCLI.lpi
```

Keep `TRSimCLI.exe` beside the `players` and `maps` directories. The schedule file contains one comma-separated roster per game. Player names may include or omit the `.trp` extension. Blank lines and lines beginning with `#` are ignored. Every roster must contain 2–10 distinct player files.

Run the CLI regression checks and one-game-per-player smoke sweep after building:

```powershell
.\tests\Run-TRSimCLITests.ps1
```

The test script uses an isolated temporary copy of the executable, map, and player files; it checks headless `UMessage`, repeatability with the same seed, default log locations, and each available TRP against `simple`. It also reruns the three reported Placement-crash rosters with action logging, both with and without an INI file beside the executable.

The standalone script-reload regression checks that unloading a script clears
its execution cursor before the next bot's routines run. This guards against
the stale procedure pointer behind the intermittent Placement access violation
in #28. Build and run it with FPC on the command path:

```powershell
New-Item -ItemType Directory -Force .\lib\reload-tests | Out-Null
fpc -B -Mdelphi -dBorland -dVer150 -dDelphi7 -dCompiler6_Up -dPUREPASCAL -Fu.\PascalScript\Source -FU.\lib\reload-tests -FE.\lib\reload-tests .\tests\PascalScriptReloadTests.lpr
.\lib\reload-tests\PascalScriptReloadTests.exe
```

## Bot strategy descriptions

Zotob retains its existing attack scoring and thresholds. If its Descartes
fallback selects a source but no destination, it now stops attacking instead
of submitting an invalid destination-zero request. The compiler workflow tests
compare guarded and unguarded attack decisions in both modes, before and after
a conquest, including zero/negative destination-score boundaries.

The current Brainless V and VI scripts include movement-safety corrections for
issue #48: fortification candidates must have an owned adjacent destination and
transferable armies, and additional occupation is capped to leave one source
army. Brainless V also avoids its zero-army fallback move. Legacy aliases and
archived tournament snapshots retain their historical behavior; games using
the corrected scripts must not be presented as unchanged historical reruns.
`tests\TRCompWorkflowTests.lpi` includes saved-state and synthetic movement
regressions for both current scripts, including both special occupation routes.
Current Brainless IV also caps additional occupation to leave one source army;
the same regressions cover its Australia and South America branches, including
the captured Siam-to-Indonesia overdraw from resumed tournament case 147.

Every playable script in `players` starts with **Program**, **Author** and
**Description**, in that order, with a value on each label's line.
Credits, AI disclaimers and version notes follow the description.
Historical source snapshots under `Doc\Tournament\bot-archive` retain their
original headers for provenance. Check playable headers with
`powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TRPHeaders.ps1`.

The following TRPs, including Grudge, are authored by Brian S. Andrews and
created with AI assistance. Their strategies are heuristics, not guarantees;
actual behavior may differ from the descriptions. Each script repeats its
author credit, AI disclaimer, and strategy description in its header. The
source code is the definitive reference for behavior.

| TRP | Strategy |
| --- | --- |
| `grudge.trp` | Tracks which opponents capture territories it previously owned and targets the opponent responsible for the most losses, favoring a human player on a tie. If that target is unavailable, attacks others only at a force ratio of at least 1.5. This bot uses board snapshots, not the action-history API, so captures serve as its measure of hostile actions. |
| `oddsmaker.trp` | Estimates attack quality from force ratios and expected exchanges; avoids low-odds attacks and concentrates armies at the best attack front. |
| `bonussaboteur.trp` | Seeks a cheap conquest that breaks an opponent's continent bonus; otherwise targets a weak border. |
| `cardcollector.trp` | Seeks one low-risk conquest per turn for a card, then stops attacking for that turn. |
| `chokepoint.trp` | Values connected territories and continent entry points, seeking control of routes between regions. |
| `quartermaster.trp` | Concentrates forces at a favorable front and moves the largest interior reserve toward the nearest front. |
| `turtle.trp` | Favors survival and a compact frontier, attacking only at a decisive advantage or for a low-risk card. |
| `kingmaker.trp` | Scores opponents by military and strategic strength, then directs attacks toward the leader to prevent a runaway. |
| `comeback.trp` | When behind in army strength, targets weak opponents and low-risk territories; when ahead, raises its attack threshold and invests in continent bonuses. |
| `opportunist.trp` | Re-evaluates attack opportunities using force ratio, eliminations, continent bonuses, and strategic access. |
| `washington.trp` | Uses a Fabian-inspired approach: preserves forces, avoids unnecessary battles, reinforces exposed fronts, and advances from favorable positions. |
| `doomstack.trp` | Concentrated-army strategy crediting Brainless IV (Mattias Beimers) and Vexer for ideas, not copied source code. Its greedy elimination-route search was independently implemented. Takes inexpensive conquests for cards, plans budgeted elimination routes against opponents with up to six territories, adjusts for progression or combination cards, and consolidates reserves through owned paths. In games of four or fewer players it also targets, breaks, and defends continents and keeps its stack rolling in duels. Also attacks giant stacks held on one or two territories to break stalemates. Evaluates opponents by position and cards, never by name. |
| `actuary.trp` | Evaluates attacks with exact dice odds: a Markov-chain table gives the probability that an attack succeeds under TurboRisk's maximum-dice rule, and each roll is re-evaluated as expected value (card, continent, elimination, border gains minus weighted army losses). Plans chained eliminations of weak card holders, reinforces continent entries whose odds of falling are too high, and builds one stack aimed at the most achievable continent. Draws on common Risk strategy-guide advice and Doomstack's stack ideas; those references credit strategy concepts, not a source-code origin. Evaluates opponents by position and cards, never by name. |

```text
alexander.trp,australian.trp,balancer.trp,frank.trp
Khorne,pitbull,simple,wyrm
```

## Usage

```powershell
.\TRSimCLI.exe --schedule .\pairings-4.csv --map std_map_small.trm `
  --turn-limit 20 --verbose --game-log .\pairings-4.sgl --cpu-log .\pairings-4.scl
```

`--map` names a `.trm` file in `maps`, beside the executable. Schedule and log paths are resolved from the current working directory; omitted log paths create `TRSimCLI.sgl` and `TRSimCLI.scl` there. The game log records the actual rosters and game status; turn- and time-limited games are distinct from TRP errors. TRP `UMessage` calls are printed to the console instead of opening a dialog.

`--verbose` adds decision entries to the console and simulator log window for territory
assignments, army placements, attack attempts and outcomes, occupation moves,
and fortifications. These show which actions a TRP selected, but not its
internal reasoning; use TRP `ULog` messages for bot-specific rationale.

Run multiple instances concurrently by assigning different `--game-log` and `--cpu-log` paths to each process.

## Options

| Option | Description |
| --- | --- |
| `--schedule <file>` | Required. One comma-separated roster per game. |
| `--map <file.trm>` | Map file under `maps`. Defaults to `std_map_small.trm`. |
| `--game-log <file>` | Game log path. Defaults to `TRSimCLI.sgl`. |
| `--cpu-log <file>` | CPU usage log path. Defaults to `TRSimCLI.scl`. |
| `--action-log <file>` | Optional public action history as UTF-8 JSONL. Appends game/roster headers and sequenced actions; disabled unless specified. Must be separate from other logs and the schedule. |
| `--turn-limit <number>` | Maximum turns per game; `0` disables the limit. |
| `--time-limit <seconds>` | Maximum seconds per game; `0` disables the limit. |
| `--seed <number>` | Seed for the game random-number generator, including calls made by TRPs through `URandom`. Identical seeds, schedules, and game inputs produce repeatable random sequences. |
| `--statistically-significant-sample` | Repeat the schedule cyclically, using its length as the minimum and at most 10 times that many games. Stop early when every scheduled TRP's win rate has a 95% Wilson confidence interval within +/- 5 percentage points. Only completed games contribute; the log reports if the target is not reached. |
| `--verbose` | Log TRP decisions and action outcomes. |
| `--error-dump` | Write a game dump when a TRP errors. |
| `--help`, `-h` | Show command-line help. |

## Sharing results with game history

### Public action history

TRPs can use `HCount` and `HGet(Index, Field)` to observe public actions by all
human and bot players, including failed attacks, casualties, captures,
placements, troop moves, income, trades, eliminations and turn boundaries.
Indices are 1-based; invalid indices/fields raise runtime errors. History resets
for a new game and is preserved in new saved games. It does not expose private
card identities or bot buffers, or store cross-game opponent models.

Use `--action-log .\actions.jsonl` for optional structured action logging:

```powershell
.\TRSimCLI.exe --schedule .\pairings-4.csv --seed 123 `
  --action-log .\actions.jsonl
```

The [action-history API and JSONL schema](Doc/HelpSource/api_history.htm)
document the `AK_*` action kinds and `AF_*` fields. Each game/segment header
identifies its roster; action rows contain game/segment IDs, sequence numbers,
actors, territories, army counts before/after, casualties and capture flags.
Each combat row represents one dice exchange. The existing `.sgl`, `.scl` and
`history.txt` formats are unchanged.

In the game, **Log actions...** in the Log window saves the available history
and streams future actions until **Stop action log** or application exit.
In TRSim's GUI, enter an optional **Action log** filename; blank disables it.
Use different action-log paths for concurrent processes. Existing compatible
files are appended; invalid files and write failures are reported.
Restarting logging can repeat game/sequence pairs in a new segment; consumers
should deduplicate those pairs. Restored saves get a new game ID with a
`parent_game` link; old saves have `history_from_start: false`.

The standalone storage/logging regression can be built with FPC using the
repository root as a unit search path, then run:

```powershell
C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe -Fu. .\tests\ActionHistoryTests.lpr
.\tests\ActionHistoryTests.exe
```

### Game results

The game's History window can open either `history.txt` or a TRSim/TRSimCLI
`.sgl` directly using **Open history / TRSim log...**. Only completed games
enter its rankings and comparisons; the window reports excluded unfinished
games. Opening a log does not append to or replace the game's saved history.

The TRSim game-log viewer also has **Export as game history...**, which writes
the legacy `date,player count,player names in finishing order` layout without
manual column editing. Only completed games are exported; timeout, error,
turn-limited and aborted results are excluded with a count. Existing writers
and their log formats are unchanged. Legacy history has no simulation timing
or army details and is viewed in History, not the detailed simulator viewer.

Build and run the import/export regression checks with:

```powershell
C:\lazarus\lazbuild.exe .\tests\HistoryWorkflowTests.lpi
.\tests\HistoryWorkflowTests.exe
```

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Run completed without TRP errors. |
| `1` | One or more games encountered a TRP error. |
| `2` | Invalid command-line input or simulator setup failure. |

Games stopped by their turn or time limit are logged as limited games; they do not count as TRP errors.
