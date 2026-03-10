# FLOWUnsteady Runner - DJI 9443 Rotor Hover

Self-contained Docker runner for a DJI 9443 rotor-in-hover simulation using [FLOWUnsteady](https://flow.byu.edu/FLOWUnsteady/).

Requires Linux with Docker installed. May work on Docker Desktop's WSL2 backend on Windows, but this is untested.

To use visualization tools (ParaView, live plots), use `docker-ce` rather than Docker Desktop. X11 forwarding relies on Unix sockets, which Docker Desktop does not support. Tested on Debian 12.5 (GNOME) and Arch Linux (Wayland).

For background on why this Docker runner exists, see [docs/HISTORY.md](docs/HISTORY.md).

## Setup

```bash
# Build the Docker image (run once, takes 5 min)
make docker-build

# Install Julia packages (run once - saves to .julia/, takes ~10-30 min)
make prepare-julia
```

## Run

Steps must be run in order. Each step reads output from the previous one.

```bash
make run-step-1    # Aerodynamic simulation (rVPM + VLM)
make run-step-2    # Fluid domain visualization grid
make run-step-3    # Aero-acoustic noise prediction
make run-step-4    # Post-processing and comparison plots
```

> **Step 3 requires** `workspace/bin/wopwop3` (PSU-WOPWOP binary, not included).

Outputs are written to `workspace/output/fidelity-<level>/`.

### Fidelity levels

Pass `FIDELITY=<level>` to any step target. Valid levels:

| Level    | `n` | Steps/rev | Use              | Step 1 RunTime | Step 2     | Step 3     |
| -------- | --- | --------- | ---------------- | -------------- | ---------- | ---------- |
| `lowest` |  20 |         6 | Quick smoke test | 2 minutes      | 10 minutes | ?? minutes |
| `low`    |  20 |        36 | Development      | 24 minutes     | 10 minutes | ?? minutes |
| `mid`    |  50 |        72 | Production       | 6 hours        |  6 minutes | ?? minutes |
| `high`   |  50 |       360 | High-accuracy    | ?? days        | ??         | ??         |

* Run times measured on AMD Ryzen 5 5600X (only 12 cores)

#### Performance recommendations

Unless you have a 64+ core machine available, consider running on AWS or GCP. With spot pricing, a full simulation costs roughly $10 — see [docs/HOWTO_AWS.md](docs/HOWTO_AWS.md) or [docs/HOWTO_GCLOUD.md](docs/HOWTO_GCLOUD.md).

```bash
make run-step-1 FIDELITY=lowest   # default
make run-step-1 FIDELITY=low
make run-step-1 FIDELITY=mid
make run-step-1 FIDELITY=high
```

Each fidelity level writes to its own output directory, so runs do not overwrite each other. Step 4 reads all four directories and plots them together.

## Configuration

Edit [`workspace/src/config-loader.jl`](workspace/src/config-loader.jl) to change simulation parameters shared across all steps (RPM, rotor geometry, operating conditions, acoustic observer geometry). Fidelity-specific discretization parameters live in the corresponding `workspace/src/fidelity-<level>.jl` file.

## Debugging

```bash
make run-bash      # Interactive shell in the container
make test-xeyes    # Verify X11 display forwarding
```
