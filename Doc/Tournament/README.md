# Tournament reference material

This folder holds results from simulated tournaments between the computer
players, run with `TRSimCLI` (see `TRSimCLI.md`). The material is for
reference only and is not used by the game.

## bot-matrix.html

A self-contained page (open it in any browser) with head-to-head results for
every pair of computer players, for games of 2 to 10 players. Each cell shows
the row bot's average score against the column bot by finish order, and its
tooltip gives an approximate 95% Jeffreys-prior credible interval. Games that
hit the time limit count as a tie (0.5 each); turn-limit and error results are
excluded.

The matrix is built from 66,480 simulated games played from 8 to 23 October
2026. These include:

- round-robin and adaptive confidence-interval runs between the original bots;
- Actuary (released version) gauntlets: 1,958 games, including 1,060 two-player
  games against every other bot and 318 games with 4, 6 and 8 players;
- Doomstack benchmarks: 1,168 games comparing the version from PR #41 with the
  stalemate-breaker version now in `players\doomstack.trp`. Both versions are
  recorded under the name `doomstack`; the 8-player games are where they differ.

Results have sampling noise: check the credible intervals and game counts
before drawing conclusions from small differences.

## bot-archive

Development versions of Actuary and Doomstack, with their benchmark results.
See `bot-archive\README.md`.
