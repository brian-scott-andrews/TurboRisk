# TRSim CLI help

`TRSimCLI` runs scheduled TRP games without showing the simulator GUI. Each game uses the exact roster on its schedule line.

Build the console executable with:

```powershell
C:\lazarus\lazbuild.exe .\TRSimCLI.lpi
```

Keep `TRSimCLI.exe` beside the `players` and `maps` directories. The schedule file contains one comma-separated roster per game. Player names may include or omit the `.trp` extension. Blank lines and lines beginning with `#` are ignored. Every roster must contain 2–10 distinct player files.

```text
alexander.trp,australian.trp,balancer.trp,frank.trp
Khorne,pitbull14,simple,wyrm
```

## Usage

```powershell
.\TRSimCLI.exe --schedule .\pairings-4.csv --map std_map_small.trm `
  --turn-limit 20 --game-log .\pairings-4.sgl --cpu-log .\pairings-4.scl
```

`--map` names a `.trm` file in `maps`, beside the executable. Schedule and log paths are resolved from the current working directory. The game log records the actual rosters and game status; turn- and time-limited games are distinct from TRP errors.

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
| `--seed <number>` | Seed for the game random-number generator. |
| `--error-dump` | Write a game dump when a TRP errors. |
| `--help`, `-h` | Show command-line help. |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Run completed without TRP errors. |
| `1` | One or more games encountered a TRP error. |
| `2` | Invalid command-line input or simulator setup failure. |

Games stopped by their turn or time limit are logged as limited games; they do not count as TRP errors.
