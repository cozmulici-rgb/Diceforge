GODOT_VERSION ?= 4.3-stable
DOCKER_COMPOSE ?= docker compose

.PHONY: help dev verify test export

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make dev     Start the interactive development container' \
		'  make verify  Run headless Godot project validation' \
		'  make test    Run deterministic gameplay tests headlessly' \
		'  make export  Build the Linux desktop artifact into dist/'

dev:
	$(DOCKER_COMPOSE) run --rm dev

verify:
	$(DOCKER_COMPOSE) run --rm export bash /workspace/scripts/verify-headless-build.sh

test:
	$(DOCKER_COMPOSE) run --rm export bash /workspace/scripts/run-godot-tests.sh

export:
	$(DOCKER_COMPOSE) run --rm export bash -lc "bash /workspace/scripts/verify-headless-build.sh && mkdir -p /workspace/dist && godot --headless --path /workspace/game --export-release \"Linux/X11\" /workspace/dist/facetbound.x86_64"
