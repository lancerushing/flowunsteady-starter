import Pkg

# Explicitly build PyCall so it links against the Python interpreter specified
# by the PYTHON env var (set in Dockerfile to /usr/local/python3.9/bin/python3.9).
# Pkg.instantiate() may skip the build step if PyCall was previously installed.
println("Instantiating packages from Project.toml...")
Pkg.instantiate()

println("Building PyCall against Python 3.9...")
Pkg.build("PyCall")

println("\n✓ Package installation complete!")
