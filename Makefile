GODOT_VERSION ?= 4.3-stable
DOCKER_COMPOSE ?= docker compose

.PHONY: help dev verify test export screenshots gui

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make dev     Start the interactive development container' \
		'  make gui     Run the game in Docker and view it in a browser at http://localhost:6080/vnc.html' \
		'  make verify  Run headless Godot project validation' \
		'  make test    Run deterministic gameplay tests headlessly' \
		'  make export  Build the Linux desktop artifact into dist/' \
		'  make screenshots  Run the Docker screenshot capture flow into dist/screenshots'

dev:
	$(DOCKER_COMPOSE) run --rm dev

gui:
	$(DOCKER_COMPOSE) up --build gui

verify:
	$(DOCKER_COMPOSE) run --rm export bash /workspace/scripts/verify-headless-build.sh

test:
	$(DOCKER_COMPOSE) run --rm export bash /workspace/scripts/run-godot-tests.sh

export:
	$(DOCKER_COMPOSE) run --rm export bash -lc "bash /workspace/scripts/verify-headless-build.sh && mkdir -p /workspace/dist && godot --headless --path /workspace/game --export-release \"Linux/X11\" /workspace/dist/diceforge.x86_64"

screenshots:
	$(DOCKER_COMPOSE) run --rm export bash /workspace/scripts/take_screenshots.sh
