# History

FLOWUnsteady is a [Julia](https://julialang.org/) package with complex dependencies, including unregistered packages and external C++ libraries.

**For detailed installation instructions**, please see the [official documentation](https://flow.byu.edu/FLOWUnsteady/installation/). The installation process includes:

1. Installing Julia 1.6 or later
2. Installing external tools (CMake, GCC, OpenMP)
3. Compiling the ExaFMM C++ library for fast multipole acceleration
4. Installing unregistered FLOW Lab packages
5. Setting up Python dependencies (for airfoil tools)

## Reasons for the Docker-based runner

Getting all of FLOWUnsteady's dependencies working on a fresh machine is time-consuming
and fragile. Two issues in particular motivated wrapping the simulation in Docker:

**ExaFMM compilation.** The core VPM solver accelerates N-body calculations using
[ExaFMM](https://github.com/exafmm/exafmm-t), a C++ fast multipole library that must
be compiled from source during Julia package installation. This requires CMake, GCC,
and OpenMPI to be present at the right versions - something that varies across Linux
distributions and is completely absent on Windows and macOS without extra setup.

**Python 3.12+ incompatibility.** The `AirfoilPrep` dependency uses Python's `imp`
module, which was removed in Python 3.12. Any system with a modern Python (Arch, Ubuntu
24.04+, Fedora 40+) will fail to install the package without first pinning to Python 3.11
and rebuilding PyCall. This is not obvious from the error messages and has caused
repeated confusion.

### The Docker solution

A Docker image pins all system-level dependencies - Julia 1.12, Python 3.11, CMake,
GCC, OpenMPI - to known-good versions. Julia packages are installed once into a
`.julia/` directory on the host and re-used across runs. The simulation scripts are
mounted from the host so they can be edited without rebuilding the image.

The simulation itself is split into four sequential steps so that the expensive
aerodynamic solve (step 1, ~2 hours) does not have to be re-run every time
post-processing or acoustic parameters are adjusted.
