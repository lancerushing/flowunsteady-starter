# Performance Notes

## step2: Fluid Domain Computation (`computefluiddomain`)

### Problem size (default config)

| Parameter | Value |
|-----------|-------|
| Grid | 125 × 125 × 125 |
| Probe nodes | ~2,000,376 |
| Wake particles (from step 1) | ~118,000 (`(2*20+1)*2*360*4`) |
| Total FMM problem size | ~2.1M particles |
| Time steps processed | 1 (`nums = [359]`) |
| Threads | 1 |

### Estimated runtime

**15–60 minutes** on a typical workstation CPU (single core).

FMM scales as O(N log N). The dominant cost is the two FMM evaluations
(velocity U and vorticity W) over the 2M probe nodes.

FMM settings used: `p=4, ncrit=50, theta=0.4` - these are already on the
faster/coarser end of the accuracy/speed tradeoff.

### Speedup options

| Change | Approx speedup |
|--------|---------------|
| Coarser grid `L/25` (63³ ≈ 250K nodes) | ~8x |
| Coarser grid `L/10` (26³ ≈ 19K nodes) | ~100x |
| `include_staticparticles = false` | small (~5%) |
| Lower `p` (e.g. `p=2`) | ~2x (less accurate) |
| Higher `theta` (e.g. `0.6`) | ~2x (less accurate) |

The grid resolution (`dx, dy, dz`) is the single biggest lever - node count
grows as N³ so halving the cell size increases cost by ~8x.
