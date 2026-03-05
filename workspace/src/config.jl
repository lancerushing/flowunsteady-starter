# Shared configuration for all simulation steps.
# Include this file at the top of each step script after imports:
#   include(joinpath(@__DIR__, "config.jl"))

const PROJECT_DIR    = dirname(Base.active_project())
const sims_path      = joinpath(PROJECT_DIR, "output")

# Simulation identity
const run_name       = "step1-rotorhover"

# Rotor geometry
const rotor_file     = "DJI9443.csv"
const CW             = false
const pitch          = 0.0

# Operating conditions
const RPM            = 5400
const J              = 0.0001
const AOA            = 0.0
const rho            = 1.071778
const mu             = 1.85508e-5
const speedofsound   = 342.35

# Aero discretization - steps 2-4 must match step 1
const nsteps_per_rev = 36

# Acoustic observer: circular microphone array
const sph_R          = 1.905
const sph_nR         = 0
const sph_nphi       = 0
const sph_ntht       = 72
const sph_thtmin     = 0
const sph_thtmax     = 360
const sph_phimax     = 180
const sph_rotation   = [90, 0, 0]
