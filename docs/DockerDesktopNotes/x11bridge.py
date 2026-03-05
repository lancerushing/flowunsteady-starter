"""
TCP-to-Unix socket bridge for X11 forwarding with Docker Desktop.

Docker Desktop runs containers in a VM, so containers cannot access the host's
X11 Unix socket directly. This script bridges the gap by listening on a random
TCP port on the host and forwarding all traffic to the local X11 Unix socket.

Usage (called by `make test-xeyes`):
    python3 docs/x11bridge.py

Writes two signal files to /tmp:
    .x11bridge_port  - display number (port - 6000) for use in DISPLAY=host.docker.internal:<n>
    .x11bridge_ready - created when the server is ready to accept connections
"""

import socket
import threading


def bridge(src, dst):
    while True:
        b = src.recv(4096)
        if not b:
            break
        dst.sendall(b)


def handle(client):
    unix = socket.socket(socket.AF_UNIX)
    unix.connect("/tmp/.X11-unix/X1")
    for src, dst in [(client, unix), (unix, client)]:
        threading.Thread(target=bridge, args=(src, dst), daemon=True).start()


sv = socket.socket(socket.AF_INET)
sv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sv.bind(("0.0.0.0", 0))
sv.listen(5)

port = sv.getsockname()[1]
open("/tmp/.x11bridge_port", "w").write(str(port - 6000))
open("/tmp/.x11bridge_ready", "w").close()

while True:
    client, _ = sv.accept()
    threading.Thread(target=handle, args=(client,), daemon=True).start()
