# Define the Docker binary with a fallback if not in the PATH of the current shell
DOCKER_BIN := $(shell which docker 2>/dev/null || echo /usr/local/bin/docker)
COMPOSE = $(DOCKER_BIN) compose -f docker-compose.yml

# Default target to compile for all platforms
build: build-web build-apk build-ios

# Compile the Flutter web application inside our Linux builder container
build-web:
	$(COMPOSE) run --rm flutter-linux flutter build web --release

# Compile the Android APK inside our Linux builder container
build-apk:
	$(COMPOSE) run --rm flutter-linux flutter build apk --release

# ! Work in progress
# Compile the iOS ipa inside the running virtualized macOS container.
# If the container is not running, we automatically spin it up.
build-ios:
	$(error "Not implemented yet")
	@if ! $(COMPOSE) ps --services --filter "status=running" | grep -q "^macos-builder$$"; then \
		echo "Container 'macos-builder' is not running. Spinning it up..."; \
		$(COMPOSE) up -d macos-builder; \
		echo "macOS Sequoia is booting. Please wait a moment for the VM to start, then run 'make build-ios' again."; \
	else \
		$(COMPOSE) exec macos-builder sh -c "cd /storage && flutter build ios --release --no-codesign"; \
	fi

# Build the web assets and spin up the Nginx local web server on port 8080
run: build-web
	$(COMPOSE) up -d web-server


.PHONY: build build-ios build-apk build-web run