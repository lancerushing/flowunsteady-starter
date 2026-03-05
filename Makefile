IMAGE = flowunsteady-runner:dev
LOG = logs/$$(date +%Y%m%d_%H%M%S)

## `--threads "auto" or "N" when (N>1)` triggers 
##  a segfault for step1 for fidelity "low" or higher

JULIA = julia --threads auto 
#JULIA = julia

STEP1 = src/step1_rotorhover.jl
STEP2 = src/step2_rotorhover_fluid_domain.jl
STEP3 = src/step3_rotorhover_aero_acoustics.jl

RUN = $(DOCKER_RUN) $(IMAGE) $(JULIA) --project

DOCKER_RUN = docker run --rm \
	--volume $(CURDIR)/workspace:/workspace \
	--volume $(CURDIR)/.julia:/home/runner/.julia \
	--volume /tmp/.X11-unix:/tmp/.X11-unix \
	--volume $(XDG_RUNTIME_DIR):$(XDG_RUNTIME_DIR) \
	$(if $(WAYLAND_DISPLAY),--volume $(XDG_RUNTIME_DIR)/$(WAYLAND_DISPLAY):$(XDG_RUNTIME_DIR)/$(WAYLAND_DISPLAY)) \
	-e DISPLAY=$(DISPLAY) \
	-e XDG_RUNTIME_DIR=$(XDG_RUNTIME_DIR) \
	-e OMP_NUM_THREADS=$(shell nproc) \
	--privileged

# build a container to run julia. Container does not need context
# see: https://docs.docker.com/build/concepts/context/#empty-context
docker-build:
	docker build --tag $(IMAGE) - < Dockerfile

## Install Julia packages
prepare-julia:
	xhost +local:docker
	$(DOCKER_RUN) -it $(IMAGE) $(JULIA) --project src/_setup.jl

run-step-1:
	xhost +local:docker
	echo "$(RUN) $(STEP1)" >> $(LOG)_step1.log
	$(RUN) $(STEP1) 2>&1 | tee -a $(LOG)_step1.log

visualize-step-1:
	xhost +local:docker
	$(RUN) src/step1_visualize.jl

run-step-2:
	xhost +local:docker
	echo "$(RUN) $(STEP2)" >> $(LOG)_step2.log
	$(RUN) $(STEP2) 2>&1 | tee -a $(LOG)_step2.log

run-step-3:
	xhost +local:docker
	echo "$(RUN) $(STEP3)" >> $(LOG)_step3.log
	$(RUN) $(STEP3) 2>&1 | tee -a $(LOG)_step3.log

## Format Julia source files with JuliaFormatter (uses temp env, no project changes)
format:
	$(DOCKER_RUN) $(IMAGE) julia -e \
		'import Pkg; Pkg.activate(temp=true); Pkg.add("JuliaFormatter"); \
		using JuliaFormatter; format("/workspace/src/", verbose=true)'

## Lint Julia source files with JET static analyzer
## NOTE: adds JET to the workspace project on first run
lint:
	$(DOCKER_RUN) $(IMAGE) $(JULIA) --project -e \
		'import Pkg; Pkg.add("JET"); using JET; \
		for f in filter(f->endswith(f,".jl"), readdir("/workspace/src/", join=true)); \
			println("\nAnalyzing: ", basename(f)); report_file(f); \
		end'

## Utility target to run bash command to explore container
run-bash:
	xhost +local:docker
	$(DOCKER_RUN) -it $(IMAGE) bash

## Utility target to test x11 forwarding
test-xeyes:
	xhost +local:docker
	$(DOCKER_RUN) $(IMAGE) xeyes
