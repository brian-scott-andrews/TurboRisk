# Bot archive

Development versions of the Actuary and Doomstack computer players, kept for
reference and benchmarking. These files are not loaded by the game; the
playable versions are `players\actuary.trp`, `players\doomstack.trp`, and
`players\challenger.trp`.
`challenger.trp` is the separately bundled pre-stalemate Doomstack baseline,
copied from `doomstack-before-opt.trp`. To test other old versions, copy them
into `players\` under a different file name.

## Actuary (exact dice-odds bot, 2026-10-23)

| File | Change from previous | 2p score vs top 6* | Notes |
|---|---|---|---|
| actuary-v0-smoke.trp | First version | - | Smoke test: 2/4 duels won |
| actuary-v1-base.trp | v0 with simplified staging placement | 42.3% (175 g) | Also 48.5% vs top 10 (198 g, run v1_2p) |
| actuary-v1-aggr.trp | Duel attrition weight 0.15 -> 0.05 | 49.4% (178 g) | |
| actuary-v1-cons.trp | Duel attrition weight 0.15 -> 0.30 | 44.3% (176 g) | |
| actuary-v1-cont.trp | Continent targeting in all <=4-player games | 51.7% (176 g) | |
| actuary-v1-p65.trp | Minimum win probability 0.50 -> 0.65 | 45.8% (177 g) | |
| actuary-v2-base2.trp | aggr + cont combined | 57.9% (235 g) | 45% vs Vexer (100 g, seed 5000) |
| actuary-v2-guard-noop.trp | Intended guard edit failed to apply; identical to base2 | 55.9% (236 g) | Shows run-to-run noise of ~2 points |
| actuary-v2-guard.trp | base2 + rear guard when occupying next to enemy stacks | - | 47% vs Vexer (100 g, seed 5000) |
| actuary-v2-stop.trp | base2 + duel stack bonus only when stack >= 6 | 56.4% (236 g) | |
| actuary-current.trp | = base2; released as `players\actuary.trp` | 83.1% vs all 53 bots (1056 g) | Run full2p_v2 |
| actuary-v3-giant.trp | base2 + normal approximation for battles over 20 defenders, enemy losses counted in expected value | 53.0% (236 g) | Fewer limited multiplayer games but fewer wins; not adopted |

\* Top 6 = vexer, finisher, doomstack, brainless V, frank+, brainless_iv;
alternating seats; TRSimCLI time limit 120 s.

## Doomstack (2026-10-14)

| File | Notes |
|---|---|
| doomstack-v0.trp .. doomstack-v3.trp | Iterations on the brainless_iv-style concentrated stack |
| doomstack-before-opt.trp | Version before the small-game optimisation pass |
| doomstack-current.trp | Version merged in PR #41; identical to before-opt. Baseline for v4 |
| doomstack-v4-stalemate.trp | Stalemate breaker test: Factor 1 vs players with 30+ armies on <=2 territories, allowed without cards. 8p (51 opps x2, seed 9008): 51 wins/16 limited vs baseline 43/37. 2p vs 8 strong bots x60: 227 vs 228 wins |
| doomstack-v4-release.trp | v4 with release header and description; released as `players\doomstack.trp` |

In `bot-matrix.html`, historical results from `doomstack-current.trp` before
the v4 stalemate breaker was introduced are attributed to `challenger`; the
name `doomstack` is reserved for the stalemate-breaker version. `challenger`
is the matching bundled TRP for that historical strategy.

Earlier `vexerchallenger.trp` drafts (the bot later renamed Doomstack) were
rewritten in place and no copies survive.

## Hashes (SHA-256, first 12 hex)

| File | Hash |
|---|---|
| actuary-v0-smoke.trp | AD7DA991D970 |
| actuary-v1-base.trp | C32E62D797C9 |
| actuary-v1-aggr.trp | DD3B9B859C66 |
| actuary-v1-cons.trp | 32C333B242E1 |
| actuary-v1-cont.trp | E6E657FFB029 |
| actuary-v1-p65.trp | C3B4475488E4 |
| actuary-v2-base2.trp / guard-noop / current | 5AC052144CD7 |
| actuary-v2-guard.trp | 4B6ADFA5A087 |
| actuary-v2-stop.trp | 4D244BD2BBD8 |
| actuary-v3-giant.trp | 7A2DDEBFF57E |
| doomstack-v0.trp | 0F7B4106EE11 |
| doomstack-v1.trp | 19728983C66B |
| doomstack-v2.trp | 5D68F23CD522 |
| doomstack-v3.trp | 64274685A0DA |
| doomstack-before-opt.trp / current | 4157F22B84CE |
| doomstack-v4-stalemate.trp | 88108C45F416 |
| doomstack-v4-release.trp | 95B6E912ADBC |

## Decisions (2026-10-23)

- actuary-v3-giant.trp: large-battle odds approximation + enemy-loss EV. Fewer limited games (6p 2, 8p 9) but fewer wins (6p 31/106, 8p 27/105, top-6 2p 53.0% vs v2 57.9%). Not adopted; `players\actuary.trp` restored to v2-base2.
- Doomstack v4 adopted (see above).
