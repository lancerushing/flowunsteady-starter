FROM julia:1.12.2-bookworm

# Install system dependencies required for FLOWUnsteady
# - CMake, GCC: For compiling ExaFMM and other native dependencies
# - OpenMPI, MPICH: For parallel computing support
# - Python 3.9.12: PyCall.jl segfaults under multi-threaded Julia with Python 3.10+
#   See: https://github.com/byuflowlab/FastMultipole.jl/issues (author confirmed)
# - Python packages: matplotlib, scipy, mpmath for visualization and scientific computing

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake g++ libopenmpi-dev mpich \
        git \
        paraview \
        x11-apps \
        # Python 3.9.12 build dependencies
        build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev curl \
        libncursesw5-dev xz-utils tk-dev libxml2-dev \
        libxmlsec1-dev libffi-dev liblzma-dev

# Build Python 3.9.12 from source and install to /usr/local/python3.9
# PyCall.jl (used by FLOWUnsteady) segfaults with Python 3.10+ under multi-threaded Julia.
# Python 3.9.12 avoids this. The PYTHON env var tells PyCall which interpreter to
# use at Pkg.build time.
RUN curl -fsSL https://www.python.org/ftp/python/3.9.12/Python-3.9.12.tgz | tar -xz && \
    cd Python-3.9.12 && \
    ./configure --enable-shared --prefix=/usr/local/python3.9 && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf Python-3.9.12

# Tell PyCall which Python to use. Must be set before `Pkg.build("PyCall")`.
ENV PYTHON=/usr/local/python3.9/bin/python3.9
# Make libpython3.9.so findable at runtime (required by --enable-shared build)
ENV LD_LIBRARY_PATH=/usr/local/python3.9/lib:$LD_LIBRARY_PATH

RUN /usr/local/python3.9/bin/pip3 install matplotlib scipy mpmath

# if you want to publish this docker image,
# add `rm -rf /var/lib/apt/lists/*` to the
# apt-get command above

## To share gui applications (like paraview)
## the group and user ids NEED to match your local group and user
## run the `id` command locally to verify
## Change the 1000 to match your linux group an user ID
RUN groupadd -g 1000 runner
RUN useradd -m -u 1000 -g runner runner

USER runner
# Set working directory to match project structure
WORKDIR /workspace
VOLUME ["/workspace"]


# Default command: interactive bash shell for development
CMD ["/bin/bash"]
