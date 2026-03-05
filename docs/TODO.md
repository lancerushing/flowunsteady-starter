# TODO

## Test on Windows

X11 display forwarding from a Linux container under Docker Desktop on Windows requires
an external X server. [VcXsrv](https://sourceforge.net/projects/vcxsrv/) is the most
commonly used option.

After installing and launching VcXsrv, run the container with:

```bash
docker run ... -e DISPLAY=host.docker.internal:0 ...
```

The `:0` refers to the display number VcXsrv exposes on the Windows host. This has not
been tested - it is recorded here for future reference.
