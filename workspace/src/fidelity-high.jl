# HIGH fidelity profile — loaded by config-loader.jl

const run_name = "fidelity-high"

# ---- HIGH FIDELITY -----------------------------------------------------------
# Blade discretization
const n                         = 50    # Number of blade elements per blade
const r_expansion               = 1/10  # Geometric expansion (tip/hub spacing ratio)

# Time discretization - steps 2-4 must match step 1
const nsteps_per_rev            = 360   # Time steps per revolution

# VPM particle shedding
const p_per_step                = 2     # Particle sheds per time step
const shed_starting             = true  # Whether to shed starting vortex

# Regularization
# sigma_rotor_surf = R / sigma_rotor_surf_divisor  (computed in step1 after reading R)
const sigma_rotor_surf_divisor  = 80
const sigmafactor_vpmonvlm      = 5.5   # Shrink particles for VPM-on-VLM/Rotor velocity

# Wake treatment
const suppress_fountain         = false # Suppress hub fountain effect for first 3 revs

# VPM solver (step1 only — requires: import FLOWVPM as vpm)
if @isdefined(vpm)
    vpm_integration = vpm.rungekutta3
    vpm_SFS         = vpm.DynamicSFS(vpm.Estr_fmm, vpm.pseudo3level_positive;
                                     alpha=0.999, maxC=1.0,
                                     clippings=[vpm.clipping_backscatter])
end
