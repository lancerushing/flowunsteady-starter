
import FLOWUnsteady as uns
import FLOWVLM as vlm

include(joinpath(@__DIR__, "config-loader.jl"))

save_path = joinpath(sims_path, run_name)

# Read number of blades from rotor file
data_path = uns.def_data_path
_, B = uns.read_rotor(rotor_file; data_path=data_path)[[1,3]]

println("Calling Paraview...")

# Files to open in Paraview
files = joinpath(save_path, run_name*"_pfield...xmf;")
for bi in 1:B
    global files
    files *= run_name*"_Rotor_Blade$(bi)_loft...vtk;"
    files *= run_name*"_Rotor_Blade$(bi)_vlm...vtk;"
end

# Call Paraview
run(`paraview --data=$(files)`)
