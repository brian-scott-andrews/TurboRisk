# Tournament reference material

This folder holds results from simulated tournaments between the computer
players, run with `TRSimCLI` (see `TRSimCLI.md`). The material is for
reference only and is not used by the game.

## Matrix files

`bot-matrix.html` is the current-version reference matrix, built from
deduplicated `master_results.sgl` data. It uses
`current-version-cutoffs.csv` to exclude older source versions from
the affected bots' current cells while preserving unchanged opponents' evidence.
Raw historical master rows are retained. It also excludes games involving Actuary
dated before 23 October 2026. Doomstack results from before that date are
retained under the name `challenger` to distinguish the pre-stalemate version
from the current `doomstack`; results from 23 October onward retain the
`doomstack` name. Brainless V results before 27 October 2026 11:00 are labeled
`brainless V legacy`; the 2-player matrix similarly labels pre-route-planner
VI samples `brainless vi legacy`. Their benchmark aliases are preserved only in
`bot-archive\brainless\`, not in `players\`. The current VI route-planner results are included in the 2-player
matrix and summarized across 2–10 players in
`bot-archive\brainless\README.md`. Restored V has only incidental 2-player
games against the route-planner VI from that run, not a dedicated V rerun.

Safety-only fixes do not reset historical matrix coverage. Valid completed and
timed-out games before the Brainless IV/V/VI movement guards, Zotob invalid-target
guards, and Raptorbot placement-selection correction remain eligible. The
explicit `brainless_iv pre-occupation-fix` result alias is pooled with IV for
display only; raw master attribution is preserved. These are pooled strategy
results, not proof that fixes have no effect on outcomes. Error, turn-limit and
watchdog-without-result attempts remain excluded. Genuine strategy boundaries
(including restored V versus legacy V, route-planning VI versus legacy VI, and
Challenger versus Doomstack) remain separate. The optional cutoff CSV is empty
until another strategic version boundary requires an additional cutoff.

`bot-matrix-archive-2026-10-23.html` preserves the previous matrix as it was
generated on 23 October 2026. It combines historical samples, including
Actuary and Doomstack results from before their latest updates; unlike the
current matrix, pre-stalemate Doomstack results there are still labeled
`doomstack`. Those cells must not be interpreted as measurements of only the current
versions.

Both files are self-contained pages (open them in any browser). Each cell
shows the row bot's average score against the column bot by finish order, and
its tooltip gives an approximate 95% Jeffreys-prior credible interval. Games
that hit the time limit count as a tie (0.5 each); turn-limit and error
results are excluded.

The **Exclude ties** checkbox removes timeout ties and equal-elimination-turn
pair ties from displayed cells, sample sizes, intervals, row/column sorting
and averages. All-tie cells become empty. The default retains half-point ties.
Two-player averages retain equal weighting across opponents with eligible data;
multiplayer averages retain observation weighting. Player hover totals remain
all recorded games, explicitly labeled. Excluding ties gives performance
conditional on a decisive pair result, not a way to count timeouts as losses
or to infer outright multiplayer win rates.

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

### Staged current-version studies

The existing multiplayer confidence runner also accepts `-FocusBots` (an array
of current names), `-VersionCutoffsFile` (CSV columns `Bot,Cutoff`, with local
`yyyyMMddHHmmss` timestamps), and `-HistoricalResults` (separately audited SGL
coverage evidence). Before-cutoff bots do not contribute current-version pairs;
unchanged opponents can still contribute their own pairs. Date cutoffs are
conservative eligibility boundaries, not proof of source identity: verify
source hashes and provenance separately.

`-StageResults` requires an `input-hashes.csv` manifest with `Path,Hash` columns
inside the run directory and an explicit frozen `TurboRisk.INI`. It verifies
input/worker hashes and progressive/random-assignment/immediate-trade rules.
It writes new rows to `master-import-pending.sgl`, never appends to master or
regenerates the published matrix, and verifies that master remains unchanged.
Import and any historical version relabeling require separate review. Staging
is mandatory for experimental source versions.

`-RepresentativeGamesPerBotSize 200` independently targets 200 completed
games for each focus bot at each size, using uniformly sampled distinct
opponents and cycling that bot's seats. Only games anchored on that bot count
toward its quota and `representative-win-rates.csv`; adaptive coverage games,
incidental appearances, and reused Vexer-focused studies do not count.
Wins/completed and wins/all attempts are reported separately. Opponent and seat
dependence, optional quota completion, and time-limit exclusions limit inference.
The pairwise interval target remains approximate, not a simultaneous confidence
guarantee on outright wins.

`-PlayerCounts 2` restricts the study to duels; the default remains all sizes
2 through 10. Only selected sizes contribute scheduling and coverage targets.

`-TurnLimit` is explicit (zero means no turn cap); the external watchdog allows
90 seconds beyond the simulator time limit. Every new attempt records its
purpose, anchor, roster, seed and raw action/CPU/game logs. `progress.json` and
`index.html` show per-size coverage and representative quotas. Game sizes are
interleaved across the batch. `-PlanOnly` reads existing evidence and prints the
next batch/coverage summary without creating directories, backups or schedules.
Audited historical coverage is loaded on a fresh run as well as a resume.
Resuming counts saved representative attempts once, deduplicates saved results,
and recovers new run rows not yet flushed to staging without importing reused
coverage. Game IDs continue beyond the previous schedule; unfinished schedule
slots are replaced by newly scheduled quota/coverage work. Historical-throughput
ETAs are omitted for representative studies because their mixed-size workload
and failure replacements are not described by pair deficits alone.

Use actual published filenames: Shadow2 loads as `shadow2.trp`, not `shadow.trp`.
Earlier alias studies remain a separate cohort and must not be silently credited
to current-name coverage or pooled outright-win rates. With explicit maintainer
approval and verified identical source/opponents, alias games can supply pair
coverage using a ledger that preserves the actual external filename and raw log;
they still do not enter the representative win-rate sample. Do not copy the held
Era$or workspace candidate into a current-version study; freeze the approved
published source. Archived bots remain excluded unless explicitly requested.

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
Each coverage roster starts with an under-covered pair, then greedily adds
opponents covering the most still-needed pairs with its existing members.
Ties favor larger remaining deficits, then seeded random selection; seats are
balanced across the run. This reduces wasted coverage but does not guarantee
a globally minimal schedule. Representative rosters remain uniformly sampled
and independent of coverage packing. Historical Actuary and Doomstack results use the same
23 October cutoff as the current matrix; pre-stalemate Doomstack games are
attributed to `challenger` when that bot is in the roster. Brainless V/VI
history before 27 October 2026 11:00 is attributed to the corresponding
`legacy` player. The runner backs up
the master before appending results and writes live progress to its run
directory, including per-player-count matchup coverage in `progress.json` and
per-size batch counts and historical-throughput ETAs in both the progress file
and console output. The HTML dashboard also shows each focus bot's completed
games, wins, losses, timeouts, and other incomplete attempts from this run,
including coverage games. Retries count as separate attempts; historical games
are not included in these per-bot totals. The representative-only table is
hidden when its sampling target is zero. `update-tournament-bot-progress.ps1`
can refresh these totals for an existing dashboard without changing results.
The optional `-FocusBot <name>` parameter restricts
confidence sampling and progress coverage to that bot's matchups; other bots
remain available as multiplayer roster fillers. At completion it generates the descriptive 2-player
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
matrix data for all player counts in `bot-matrix.html` and refreshes
`opponent-overperformance-2p.txt`. The runner also writes per-direction test
results to its run directory. Confidence and power are approximations, not
formal guarantees, and a non-significant result does not establish equivalence.
Use its `-FinalizeOnly` mode to rebuild the descriptive matrix/report without
starting another simulation run.

`update-bot-matrix.ps1 -MasterResults <master_results.sgl>` rebuilds all
2–10-player tabs from the same deduplicated, version-attributed master.
It preserves the page controls and includes every current player script in
each tab. The tournament finalizer calls it automatically, including when
using `-FinalizeOnly`; previously only the 2-player tab was refreshed.

## Representative win-rate study

`run-representative-tournament.ps1 -Snapshot <frozen-input-directory>
-RunDirectory <new-directory>` schedules 24,305 games for a 63-bot roster.
Every bot gets exactly 200 appearances at each size from 2 through 10, with
floor/ceiling-balanced seats. Random partition sequences exclude duplicate
players; the complete schedule is fixed before gameplay and interleaves sizes.
Use `-PlanOnly` to validate and export the schedule without launching games.
The default maximum is 24 hidden workers.

The snapshot must contain `players`, standard-map files, `TRSimCLI.exe`, and an
explicit `TurboRisk.INI`. Inputs are copied and hashed. The study uses random
assignment, progressive cards, immediate captured-card trades, a 180-second
simulator limit, no turn cap, and a 270-second external watchdog. Action metadata
is checked against the declared rules and seats. Failures are retained and
reported rather than silently replaced. Use `-Resume` with the same run directory
and its frozen snapshot to continue after stopping all workers. Resume verifies
input hashes, recovers finished but unrecorded games, preserves partial logs in
a timestamped backup, and replays unfinished slots with original seeds and seats.
Recorded failures remain outcomes rather than being replaced.

`index.html` and `representative-rates.csv` show wins divided by the fixed 200
scheduled appearances, completed-game win rates, timeouts, failures, and progress.
Scheduled-denominator rates are provisional until that bot finishes its schedule.
The runner never appends results to master automatically. The completed
2026-11-09 study was separately validated and approved for import on 2026-11-12:
24,281 completed and timed-out result rows were added; 24 watchdog attempts
without valid results were excluded. The matrix now pools this cohort with
historical matchup evidence, so it is not the representative win-rate ranking;
use the study dashboard for fixed-budget win rates. Seat and roster balancing
introduces dependence; close rankings and simultaneous statistical guarantees
are not established by this budget.

## bot-archive

`players\` contains current playable bots only. Keep legacy and archived
versions here instead; do not include them in tournaments unless explicitly
requested. Historical result labels remain unchanged.

Development versions of Actuary and Doomstack, with their benchmark results.
See `bot-archive\README.md`.
