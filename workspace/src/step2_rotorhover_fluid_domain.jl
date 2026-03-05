#=##############################################################################
    Computes the fluid domain of DJI 9443 simulation using a volumetric domain.
    This is done probing the velocity and vorticity that the particle field
    induces at each node of a Cartesian grids.

    NOTE: The fluid domain generated here does not include the freestream
            velocity, which needs to be added manually inside ParaView (if any).
=###############################################################################

import FLOWUnsteady as uns
import FLOWUnsteady: vpm, gt, dot, norm

include(joinpath(@__DIR__, "config-loader.jl"))

# --------------- INPUTS AND OUTPUTS -------------------------------------------
read_path       = joinpath(sims_path, run_name)           # Where to read simulation from

pfield_prefix   = run_name*"_pfield"        # Prefix of particle field files to read
staticpfield_prefix = run_name*"_staticpfield"  # Prefix of static particle field files to read

number_of_time_steps            = [nrevs * nsteps_per_rev - 1]  # Time steps to process
# staticpfield lags one step behind pfield (static particles written at step start,
# pfield written at step end), so the last valid combined step is nsteps-1.
# @show number_of_time_steps; exit()

# OUTPUT OPTIONS
save_path       = joinpath(sims_path, run_name*"-fdom")   # Where to save fluid domain
output_prefix   = "singlerotor"             # Prefix of output files
prompt          = false                     # Whether to prompt the user
verbose         = true                      # Enable verbose
v_lvl           = 0                         # Verbose indentation level


# -------------- PARAMETERS ----------------------------------------------------
# Simulation information
data_path       = uns.def_data_path                           # Path to rotor database
R, B            = uns.read_rotor(rotor_file; data_path=data_path)[[1,3]]  # Rotor radius

# Grid
L               = R                         # (m) reference length
dx, dy, dz      = L/50, L/50, L/50          # (m) cell size in each direction
Pmin            = L*[-0.50, -1.25, -1.25]   # (m) minimum bounds
Pmax            = L*[ 2.00,  1.25,  1.25]   # (m) maximum bounds
NDIVS           = ceil.(Int, (Pmax .- Pmin)./[dx, dy, dz])  # Number of cells in each direction
nnodes          = prod(NDIVS .+ 1)          # Total number of nodes

Oaxis           = gt.rotation_matrix2(0, 0, AOA)    # Orientation of grid

# VPM settings
maxparticles    = Int(1.0e6 + nnodes)         # Maximum number of particles
fmm             = vpm.FMM(; p=4, ncrit=50, theta=0.4, shrink_recenter=false) # FMM parameters
scale_sigma     = 1.00                      # Shrink smoothing radii by this factor
f_sigma         = 0.5                       # Smoothing of node particles as sigma = f_sigma*meansigma

maxsigma        = L/10                      # Particles larger than this get shrunk to this size (this helps speed up computation)
maxmagGamma     = Inf                       # Any vortex strengths larger than this get clipped to this value

include_staticparticles = true              # Whether to include the static particles embedded in the solid surfaces

other_file_prefs = include_staticparticles ? [staticpfield_prefix] : []
other_read_paths = [read_path for i in 1:length(other_file_prefs)]

if verbose
    println("\t"^(v_lvl)*"Fluid domain grid")
    println("\t"^(v_lvl)*"NDIVS =\t$(NDIVS)")
    println("\t"^(v_lvl)*"Number of nodes =\t$(nnodes)")
end

# --------------- PROCESSING SETUP ---------------------------------------------
if verbose
    println("\t"^(v_lvl)*"Getting ready to process $(read_path)")
    println("\t"^(v_lvl)*"Results will be saved under $(save_path)")
end

# Create save path
if save_path != read_path
    gt.create_path(save_path, prompt)
end

# Copy this driver file so the results are self-documenting.
# If you come back to the output folder later, you can see exactly
# what parameters were used to generate it.
cp(@__FILE__, joinpath(save_path, splitdir(@__FILE__)[2]); force=true)
cp(joinpath(@__DIR__, "config-loader.jl"), joinpath(save_path, "config-loader.jl"); force=true)

# Generate function to process the field clipping particle sizes
preprocessing_pfield = uns.generate_preprocessing_fluiddomain_pfield(maxsigma, maxmagGamma;
                                                                        verbose=verbose, v_lvl=v_lvl+1)

# --------------- PROCESS SIMULATION -------------------------------------------

nthreads        = 1                         # Total number of threads
nthread         = 1                         # Number of this thread
dnum = floor(Int, length(number_of_time_steps)/nthreads)    # Number of time steps per thread
threaded_number_of_time_steps = [view(number_of_time_steps, dnum*i+1:(i<nthreads-1 ? dnum*(i+1) : length(number_of_time_steps))) for i in 0:nthreads-1]

for these_number_of_time_steps in threaded_number_of_time_steps[nthread:nthread]

     uns.computefluiddomain(    Pmin, Pmax, NDIVS,
                                maxparticles,
                                these_number_of_time_steps, read_path, pfield_prefix;
                                Oaxis=Oaxis,
                                fmm=fmm,
                                f_sigma=f_sigma,
                                save_path=save_path,
                                file_pref=output_prefix, grid_names=["_fdom"],
                                other_file_prefs=other_file_prefs,
                                other_read_paths=other_read_paths,
                                userfunction_pfield=preprocessing_pfield,
                                verbose=verbose, v_lvl=v_lvl)

end
