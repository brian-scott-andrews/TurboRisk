# Tournament reference material

This folder holds results from simulated tournaments between the computer
players, run with `TRSimCLI` (see `TRSimCLI.md`). The material is for
reference only and is not used by the game.

## Matrix files

`bot-matrix.html` is the current-version reference matrix, built from
deduplicated `master_results.sgl` data. It excludes games involving Actuary
dated before 23 October 2026. Doomstack results from before that date are
retained under the name `challenger` to distinguish the pre-stalemate version
from the current `doomstack`; results from 23 October onward retain the
`doomstack` name. The matching pre-stalemate player is bundled as
`players\challenger.trp`. Historical results for other bots remain included.

`bot-matrix-archive-2026-10-23.html` preserves the previous matrix as it was
generated on 23 October 2026. It combines historical samples, including
Actuary and Doomstack results from before their latest updates; unlike the
current matrix, pre-stalemate Doomstack results there are still labeled
`doomstack`. Those cells must not be interpreted as measurements of only the
current versions.

Both files are self-contained pages (open them in any browser). Each cell
shows the row bot's average score against the column bot by finish order, and
its tooltip gives an approximate 95% Jeffreys-prior credible interval. Games
that hit the time limit count as a tie (0.5 each); turn-limit and error
results are excluded.

### Archived matrix coverage

The archived matrix covers every pair of computer players for games of 2 to
10 players and is built from 66,480 simulated games played from 8 to 23
October 2026. These include:

- round-robin and adaptive confidence-interval runs between the original bots;
- Actuary (released version) gauntlets: 1,958 games, including 1,060 two-player
  games against every other bot and 318 games with 4, 6 and 8 players;
- Doomstack benchmarks: 1,168 games comparing the version from PR #41 with the
  stalemate-breaker version now in `players\doomstack.trp`. Both versions are
  recorded under the name `doomstack`; the 8-player games are where they differ.

Results have sampling noise: check the credible intervals and game counts
before drawing conclusions from small differences.

## Statistical tournament scripts

`run-statistical-tournament.ps1` schedules additional two-player games until
each matchup meets its confidence-width target and each bot's equally weighted
average across opponents meets its overall target. While a run is active,
`watch-statistical-tournament.ps1 -Run <run-directory>` displays live counts,
valid-game rate, estimated batch time, and current confidence widths from the
worker logs. The monitor uses `+/-` for interval widths to avoid console
encoding issues.

`run-multiplayer-confidence-tournament.ps1` runs one adaptive confidence
tournament for 2–10-player games using every bot in the supplied players
directory.
It tops up each bot-pair/size until there are at least 20 valid results and an
approximate 95% Wilson half-width of at most 20 percentage points by default.
Each scheduled pair is joined by randomly selected opponents; seats are
balanced across the run. Historical Actuary and Doomstack results use the same
23 October cutoff as the current matrix; pre-stalemate Doomstack games are
attributed to `challenger` when that bot is in the roster. The runner backs up
the master before appending results and writes live progress to its run
directory, including per-player-count matchup coverage in `progress.json` and
per-size batch counts and historical-throughput ETAs in both the progress file
and console output. At completion it generates the descriptive 2-player
overperformance report from the same games; this final summary is not a second
adaptive test.

`run-opponent-overperformance-tournament.ps1` runs a one-worker, adaptive
two-player study for opponents whose win rate against a bot exceeds that bot's
equally weighted average against its other opponents. It tests both directions
of each matchup, checking historical results first and then every 25 new games.
The nominal family-wise 95% threshold uses Bonferroni correction across all
directional hypotheses and prespecified looks. The planned minimum detectable
lift is 15 percentage points at 90% power using a normal approximation; up to
500 new games are scheduled per unresolved pair, with either direction's
significance ending that pair's sampling. Results are appended to the master
as they are collected. On completion, the runner regenerates the two-player
matrix data in `bot-matrix.html` and refreshes
`opponent-overperformance-2p.txt`. The runner also writes per-direction test
results to its run directory. Confidence and power are approximations, not
formal guarantees, and a non-significant result does not establish equivalence.
Use its `-FinalizeOnly` mode to rebuild the descriptive matrix/report without
starting another simulation run.

## bot-archive

Development versions of Actuary and Doomstack, with their benchmark results.
See `bot-archive\README.md`.
