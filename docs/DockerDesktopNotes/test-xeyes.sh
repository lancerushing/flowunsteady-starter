#!/usr/bin/env bash
# Test X11 forwarding with Docker Desktop.
#
# Docker Desktop runs containers in a VM, so Unix sockets are not accessible
# from containers even with --net=host. This script bridges the X11 Unix socket
# to TCP via docs/x11bridge.py, then runs xeyes inside the container.
#
# Usage: bash docs/test-xeyes.sh
#
# Requirements:
#   - python3 (host)
#   - xauth (host)
#   - Docker Desktop with flowunsteady-runner:dev image built

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE=flowunsteady-runner:dev
XAUTH_FILE=$(xauth info 2>/dev/null | awk '/Authority file/{print $NF}')

# Start the TCP-to-Unix X11 bridge on a random port
python3 "$SCRIPT_DIR/x11bridge.py" &
BRIDGE_PID=$!

# Wait until the bridge signals it is ready
while [ ! -f /tmp/.x11bridge_ready ]; do sleep 0.1; done
rm -f /tmp/.x11bridge_ready

BRIDGE_DISP=$(cat /tmp/.x11bridge_port)
rm -f /tmp/.x11bridge_port

# Generate a wildcard-hostname xauth cookie the container can use
XAUTH_TMP=$(mktemp)
XAUTHORITY="$XAUTH_FILE" xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH_TMP" nmerge -
chmod 644 "$XAUTH_TMP"

# Run xeyes inside the container via the TCP bridge
docker run \
    --rm \
    --volume "$XAUTH_TMP":/tmp/.docker.xauth:ro \
    -e DISPLAY=host.docker.internal:"$BRIDGE_DISP" \
    -e XAUTHORITY=/tmp/.docker.xauth \
    "$IMAGE" xeyes

kill "$BRIDGE_PID" 2>/dev/null
rm -f "$XAUTH_TMP"
