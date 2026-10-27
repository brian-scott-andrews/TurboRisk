# Brainless V and VI versions

The archived source files preserve the player scripts before and after the
October 2026 work:

| File | Version | Description |
|---|---|---|
| `brainless-V-pre-restoration.trp` | V baseline | Committed pre-restoration V, with the elimination caller removed during the 8 October hardening change. |
| `brainless-V-iv-elimination.trp` | V IV-derived experiment | Temporary version that used an IV-style immediate elimination-target helper. It was superseded when V was restored close to its original design. |
| `brainless-V-restored.trp` | V restored | Near-original elimination planner restored with bounds guards; its incomplete result is diagnostic and does not choose an attack target. This is the current `players\brainless V.trp`. |
| `brainless-vi-pre-route.trp` | VI baseline | Committed pre-route-planner VI. It does not use a functional elimination route planner. |
| `brainless-vi-iv-elimination.trp` | VI IV-derived experiment | Temporary version with the IV-style immediate elimination-target helper, before VI's route planner was implemented. |
| `brainless-vi-route-planner.trp` | VI route planner | Bounded weighted route search that selects the first step toward a reachable weak opponent and replans after each attack. This is the current `players\brainless vi.trp`. |
| `brainless-vi-route-rerun-2026-10-27.sgl` | VI benchmark | Raw valid result rows from the isolated route-planner rerun. |

Historical results through 27 October 2026 10:59 are identified as
`brainless V legacy` and `brainless vi legacy`; these are also available as
playable benchmark aliases in `players\`. The IV-derived experiments were
preserved from checkpoint `dba587b`; they were exploratory and not tournament
benchmarked. The current versions keep the names
`brainless V` and `brainless vi`. The original master-results file was not
rewritten; the tournament scripts apply the same cutoff when building
statistics. The intermediate IV-derived helper snapshots were preserved for
historical comparison and were not used in the route-planner rerun.

## VI route-planner rerun (2026-10-27)

The adaptive 2–10-player rerun used the route-planner version against the
current opponent roster. It produced 3,333 valid game results, including 109
time-limit ties; one scheduled game failed after retries. All 495
opponent/size matchups met the 20-sample minimum and approximate 95% Wilson
half-width goal of 20 percentage points.

Scores below count time-limit ties as half a point. Historical and rerun
rosters differ, so this is descriptive context rather than a controlled
before/after comparison. The restored V version was not independently
rerun; its 20 two-player games in this run were incidental matchups against
route-planner VI and do not estimate V's overall performance.

| Players | Pre-route VI score | Route-planner score | Valid rerun games |
|---:|---:|---:|---:|
| 2 | 75.4% | 73.9% | 1,102 |
| 3 | 15.1% | 21.9% | 569 |
| 4 | 25.1% | 23.2% | 399 |
| 5 | 38.1% | 25.3% | 308 |
| 6 | 40.0% | 23.8% | 250 |
| 7 | 40.4% | 25.9% | 212 |
| 8 | 38.2% | 22.3% | 184 |
| 9 | 41.1% | 25.2% | 163 |
| 10 | 38.0% | 22.6% | 146 |
