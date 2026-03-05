# Docker Desktop Notes

> **Note:** The main project is designed for **docker-ce** (Community Edition) on Linux.
> The `Makefile` targets (`run-step-1`, `test-xeyes`, etc.) assume docker-ce, where
> containers share the host network namespace and can access Unix sockets directly.
> The scripts in this directory are **unsupported workarounds** for Docker Desktop users
> and are provided here for reference only.

## Why docker-ce is preferred

The `Makefile` mounts the X11 Unix socket directly into containers:

```makefile
DOCKER_RUN = docker run --rm \
    --volume /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$(DISPLAY) \
    ...
```

This works on **docker-ce** because containers run natively on the host Linux kernel
and can connect to host Unix sockets.

**Docker Desktop** runs containers inside a lightweight Linux VM. Even with `--net=host`
or a socket bind-mount, the container cannot reach the host's X11 Unix socket - the
VM's network namespace is isolated from the host.

## X11 forwarding workaround for Docker Desktop

These scripts bridge the host X11 Unix socket to a TCP port that the Docker VM can reach
via `host.docker.internal`.

| File | Purpose |
| --- | --- |
| [x11bridge.py](x11bridge.py) | Python TCP-to-Unix bridge; binds a random port and forwards to `/tmp/.X11-unix/X1` |
| [test-xeyes.sh](test-xeyes.sh) | Full test script: starts the bridge, generates xauth credentials, runs `xeyes` |

### How it works

1. `x11bridge.py` listens on a random TCP port (`0.0.0.0:0`) and signals readiness
   by writing the display number (`port - 6000`) to `/tmp/.x11bridge_port`
2. `test-xeyes.sh` reads the display number and generates a wildcard xauth cookie
   so the container can authenticate with the X server
3. The container connects via `DISPLAY=host.docker.internal:<display_num>` (TCP)
   instead of the Unix socket

### Usage

```bash
bash docs/DockerDesktopNotes/test-xeyes.sh
```

### Verifying your Docker context

```bash
docker context ls
```

If the active context is `desktop-linux`, you are running Docker Desktop and the
standard `make test-xeyes` target will not work. Use the script above instead.
