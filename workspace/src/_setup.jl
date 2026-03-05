import Pkg

println("Instantiating packages from Project.toml...")
Pkg.instantiate()

println("\n✓ Package installation complete!")
