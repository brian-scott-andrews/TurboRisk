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

The test script uses an isolated temporary copy of the executable, map, and player files; it checks headless `UMessage`, repeatability with the same seed, default log locations, and each available TRP against `simple`.

## Bot strategy descriptions

The following TRPs, including Grudge, are authored by Brian S. Andrews and
created with AI assistance. Their strategies are heuristics, not guarantees;
actual behavior may differ from the descriptions. Each script repeats its
author credit, AI disclaimer, and strategy description in its header. The
source code is the definitive reference for behavior.

| TRP | Strategy |
| --- | --- |
| `grudge.trp` | Tracks which opponents capture territories it previously owned and targets the opponent responsible for the most losses, favoring a human player on a tie. If that target is unavailable, attacks others only at a force ratio of at least 1.5. Failed attacks are not observable to TRPs, so captures serve as its measure of hostile actions. |
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
| `--turn-limit <number>` | Maximum turns per game; `0` disables the limit. |
| `--time-limit <seconds>` | Maximum seconds per game; `0` disables the limit. |
| `--seed <number>` | Seed for the game random-number generator, including calls made by TRPs through `URandom`. Identical seeds, schedules, and game inputs produce repeatable random sequences. |
| `--statistically-significant-sample` | Repeat the schedule cyclically, using its length as the minimum and at most 10 times that many games. Stop early when every scheduled TRP's win rate has a 95% Wilson confidence interval within +/- 5 percentage points. Only completed games contribute; the log reports if the target is not reached. |
| `--verbose` | Log TRP decisions and action outcomes. |
| `--error-dump` | Write a game dump when a TRP errors. |
| `--help`, `-h` | Show command-line help. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Run completed without TRP errors. |
| `1` | One or more games encountered a TRP error. |
| `2` | Invalid command-line input or simulator setup failure. |

Games stopped by their turn or time limit are logged as limited games; they do not count as TRP errors.
