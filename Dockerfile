FROM julia:1.12.2-bookworm

# Install system dependencies required for FLOWUnsteady
# - CMake, GCC: For compiling ExaFMM and other native dependencies
# - OpenMPI, MPICH: For parallel computing support
# - Python 3.11: Compatible with AirfoilPrep (avoids Python 3.12+ imp module deprecation)
# - Python packages: matplotlib, scipy, mpmath for visualization and scientific computing

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.11 \
        python3-pip \
        cmake g++ libopenmpi-dev mpich \
        git \
        python3-matplotlib python3-mpmath python3-scipy \
        paraview

# if you want to publish this docker image,
# add `rm -rf /var/lib/apt/lists/*` to the
# previous command

## Optional - Install apps to help debug x11 sharing (like xeyes)
RUN apt-get install -y x11-apps

## To share gui applications (like paraview)
## the group and user ids NEED to match your local group and user
## run the `id` command locally to verify
## Change the 1000 to match your linux user ID
RUN groupadd -g 1000 runner
RUN useradd -m -u 1000 -g runner runner

USER runner
# Set working directory to match project structure
WORKDIR /workspace
VOLUME ["/workspace"]


# Default command: interactive bash shell for development
CMD ["/bin/bash"]
