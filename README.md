# FLOWUnsteady Runner - DJI 9443 Rotor Hover

Self-contained Docker runner for a DJI 9443 rotor-in-hover simulation using [FLOWUnsteady](https://flow.byu.edu/FLOWUnsteady/).

Requires Linux with `docker-ce` (not Docker Desktop). X11 forwarding relies on Unix sockets and does not work with Docker Desktop. Tested on Debian 12.5 (GNOME) and Arch (Wayland).

For background on why this Docker runner exists, see [docs/HISTORY.md](docs/HISTORY.md).

## Setup

```bash
# Build the Docker image
make docker-build

# Install Julia packages (run once - saves to .julia/, takes ~10-30 min)
make prepare-julia
```

## Run

Steps must be run in order. Each step reads output from the previous one.

```bash
make run-step-1    # Aerodynamic simulation (rVPM + VLM), takes 2 hours
make run-step-2    # Fluid domain visualization grid
make run-step-3    # Aero-acoustic noise prediction
make run-step-4    # Post-processing and plots
```

> **Step 3 requires** `workspace/bin/wopwop3` (PSU-WOPWOP binary, not included).

Outputs are written to `workspace/output/`.

## Configuration

Edit [`workspace/src/config.jl`](workspace/src/config.jl) to change simulation parameters (RPM, rotor geometry, fidelity settings, etc.). All step scripts share this file - do not duplicate values across steps.

## Debugging

```bash
make run-bash      # Interactive shell in the container
make test-xeyes    # Verify X11 display forwarding
```
