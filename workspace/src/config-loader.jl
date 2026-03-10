# Set FIDELITY below, then include this file at the top of each step script:
#   include(joinpath(@__DIR__, "config-loader.jl"))
#
# Valid values: "lowest", "low", "mid", "high"

const FIDELITY = get(ENV, "FIDELITY", "lowest")

# Load fidelity based settings
if FIDELITY == "lowest"
    include(joinpath(@__DIR__, "fidelity-lowest.jl"))
elseif FIDELITY == "low"
    include(joinpath(@__DIR__, "fidelity-low.jl"))
elseif FIDELITY == "mid"
    include(joinpath(@__DIR__, "fidelity-mid.jl"))
elseif FIDELITY == "high"
    include(joinpath(@__DIR__, "fidelity-high.jl"))
elseif FIDELITY == "almost-high"
    include(joinpath(@__DIR__, "fidelity-almost-high.jl"))
else
    error("Unknown FIDELITY value: \"$(FIDELITY)\". Expected \"lowest\", \"low\", \"mid\", or \"high\".")
end

println("################################################################")
println("Fidelity: $(FIDELITY)")
println("################################################################")

const run_name = "rotorhover"
const nrevs    = 10                         # Number of revolutions in simulation

# Paths
const sims_path   = joinpath("/output", "fidelity-$(FIDELITY)")

# Rotor geometry
const rotor_file  = "DJI9443.csv"
const CW          = false
const pitch       = 0.0

# Operating conditions
const RPM         = 5400
const J           = 0.0001
const AOA         = 0.0
const rho         = 1.071778
const mu          = 1.85508e-5
const speedofsound = 342.35

# Acoustic observer: circular microphone array
const sph_R        = 1.905
const sph_nR       = 0
const sph_nphi     = 0
const sph_ntht     = 72
const sph_thtmin   = 0
const sph_thtmax   = 360
const sph_phimax   = 180
const sph_rotation = [90, 0, 0]

