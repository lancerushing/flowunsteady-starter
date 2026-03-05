# Internal Notes

Developer notes for maintaining and updating this project.

---

## How to upgrade a Julia package

Most packages in this project are pinned to specific git tags via the `[sources]` and
`[compat]` sections of [`workspace/Project.toml`](../workspace/Project.toml). To
upgrade a package to a new version:

**1. Update `Project.toml`** - change the `rev` tag in `[sources]` and the version in
`[compat]`:

```toml
[sources]
BPM = {rev = "v3.0.0", url = "https://github.com/byuflowlab/BPM.jl"}

[compat]
BPM = "3.0.0"
```

**2. Resolve the new version** - run inside the container (or with the project active):

```bash
julia --project -e 'using Pkg; Pkg.add(PackageSpec(name="BPM", rev="v3.0.0"))'
```

This fetches the new tag from GitHub and updates `Manifest.toml` with the new
`git-tree-sha1`. Commit both files after a successful upgrade.

> If the new version introduces breaking changes, check the package changelog and
> update any affected call sites in `workspace/src/`.
