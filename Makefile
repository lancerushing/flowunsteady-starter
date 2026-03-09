IMAGE = flowunsteady-runner:dev-py39
LOG = logs/$$(date +%Y%m%d_%H%M%S)_$(FIDELITY)
FIDELITY ?= lowest
OUTPUT_PATH = /mnt/unlocked/flowunstead_output

STEP1RUN = $(DOCKER_RUN_HEADLESS) $(IMAGE) julia --threads auto --project src/step1_rotorhover.jl
STEP2RUN = $(DOCKER_RUN_HEADLESS) $(IMAGE) julia --threads auto --project src/step2_rotorhover_fluid_domain.jl
STEP3RUN = $(DOCKER_RUN_HEADLESS) $(IMAGE) julia --threads auto --project src/step3_rotorhover_aero_acoustics.jl
STEP4RUN = $(DOCKER_RUN_HEADLESS) $(IMAGE) julia --threads auto --project src/step4_rotorhover_post_processing.jl


DOCKER_RUN = docker run --rm \
	--volume $(CURDIR)/workspace:/workspace \
	--volume $(OUTPUT_PATH):/output \
	--volume $(CURDIR)/.julia:/home/runner/.julia \
	--volume /tmp/.X11-unix:/tmp/.X11-unix \
	--volume $(XDG_RUNTIME_DIR):$(XDG_RUNTIME_DIR) \
	$(if $(WAYLAND_DISPLAY),--volume $(XDG_RUNTIME_DIR)/$(WAYLAND_DISPLAY):$(XDG_RUNTIME_DIR)/$(WAYLAND_DISPLAY)) \
	-e DISPLAY=$(DISPLAY) \
	-e XDG_RUNTIME_DIR=$(XDG_RUNTIME_DIR) \
	-e OMP_NUM_THREADS=$(shell nproc) \
	-e FIDELITY=$(FIDELITY) \
	--privileged

# Headless variant: no X11 forwarding, matplotlib renders to PNG without a display
DOCKER_RUN_HEADLESS = docker run --rm \
	--volume $(CURDIR)/workspace:/workspace \
	--volume $(OUTPUT_PATH):/output \
	--volume $(CURDIR)/.julia:/home/runner/.julia \
	-e OMP_NUM_THREADS=$(shell nproc) \
	-e FIDELITY=$(FIDELITY) \
	-e MPLBACKEND=Agg \
	--privileged

# build a container to run julia. Container does not need context
# see: https://docs.docker.com/build/concepts/context/#empty-context
docker-build:
	docker build --tag $(IMAGE) - < Dockerfile

## Install Julia packages
prepare-julia:
	mkdir -p ./.julia
	$(DOCKER_RUN_HEADLESS) -it $(IMAGE) julia --threads auto --project src/_setup.jl

run-step-1:
	mkdir -p ./logs
	echo "$(STEP1RUN)" >> $(LOG)_step1.log
	$(STEP1RUN) 2>&1 | tee -a $(LOG)_step1.log

visualize-step-1:
	xhost +local:docker
	$(DOCKER_RUN) $(IMAGE) julia --project src/step1_visualize.jl

run-step-2:
	echo "$(STEP2RUN)" >> $(LOG)_step2.log
	$(STEP2RUN) 2>&1 | tee -a $(LOG)_step2.log

run-step-3:
	echo "$(STEP3RUN)" >> $(LOG)_step3.log
	$(STEP3RUN) 2>&1 | tee -a $(LOG)_step3.log

run-step-4:
	echo "$(STEP4RUN)" >> $(LOG)_step4.log
	$(STEP4RUN) 2>&1 | tee -a $(LOG)_step4.log

## Format Julia source files with JuliaFormatter (uses temp env, no project changes)
format:
	$(DOCKER_RUN_HEADLESS) $(IMAGE) julia -e \
		'import Pkg; Pkg.activate(temp=true); Pkg.add("JuliaFormatter"); \
		using JuliaFormatter; format("/workspace/src/", verbose=true)'

## Lint Julia source files with JET static analyzer
lint:
	$(DOCKER_RUN_HEADLESS) $(IMAGE) julia --project -e \
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
