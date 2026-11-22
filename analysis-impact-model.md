# Impact → score model (fitted to your race summaries)

## Dataset (from your screenshots)

| Race | DR end / Δ | SR end / Δ | Notes |
| --- | --- | --- | --- |
| 15th / 24 (BMW) | Bronze3 **10% +15.8%** | Silver1 **10% +16.0%** | DR “gained”; SR clean High×2 + contacts Low×2 |
| 19th (yellow) | Bronze3 **10% +15.0%** | Silver1 **30% −8.0%** | DR gained; SR barriers High− |
| 5th / 8 | Bronze3 **20% −15.0%** | Silver1 **20% +16.0%** | DR “lost” Low; SR clean High×2 only |

## Fit result

### Safety Rank — confirmed

Silver uses **8% per net arrow**:

| Net adjustment | Expected Δ | Your races |
| ---: | ---: | --- |
| −1 (Low) | **−8%** | 19th: −8.0% |
| +2 (Mid) | **+16%** | 15th & 5th/8: +16.0% |
| +3 (High) | +24% | (not in this set) |

Matches the community table (Silver +3 = 24% ⇒ 8%/arrow).

Full SR table:

| Tier | /arrow | +3 max |
| --- | ---: | ---: |
| Bronze | 15% | 45% |
| Silver | 8% | 24% |
| Gold | ~4.7% | 14% |
| Platinum | ~2.3% | 7% |

### Driver Rank — Bronze fits same 15%/arrow

| Net | Expected | Your races |
| ---: | ---: | --- |
| −1 | **−15%** | 5th/8: −15.0% (“lost” Low) |
| +1 | **+15%** | 19th: +15.0%; 15th: +15.8% (API/noise) |

So for **Bronze DR**, net Low ≈ ±15% — same as Bronze SR.

## Critical: reason rows ≠ additive %

Example (5th/8 DR):

| Reason | Impact |
| --- | --- |
| You lost Driver Rank | Low (−) |
| Finished 5th of 8 | Low (−) |
| Beat 1 higher DR | Low (+) |
| Lost to 0 lower DR | High (+) |

Signed sum of row levels ≠ a meaningful %. Badge moved **−15%** = **one** Low net arrow.

Same for SR on the 15th race: two High clean rows **and** two Low contact rows → net was still **+16%** (two arrows), not +6−2 arrow-levels.

**Rule:** only `driverRankAdjustment` / `safetyRankAdjustment` (−3…+3) maps to bar %. Reason-row Low/Mid/High are qualitative explanations.

## What not to trust

Profile-style deltas like **SR +32.9%** are multi-race snapshot noise (or old bug), not one race. Plugin now only snapshot-diffs on post-race `RankCard`.

## Plugin formula (current)

```
if API drChange/srChange ≠ 0 → use it
else → netAdjustment × pctPerArrow(tier)
```

Reason rows: show numeric % only if RaceControl sends a real field (usually it doesn’t).
