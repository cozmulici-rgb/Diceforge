GODOT_VERSION ?= 4.3-stable
DOCKER_COMPOSE ?= docker compose

.PHONY: dev verify export

dev:
	$(DOCKER_COMPOSE) run --rm dev

verify:
	@echo "Phase 03 will implement headless verification."

export:
	@echo "Phase 03 will implement Linux export."
