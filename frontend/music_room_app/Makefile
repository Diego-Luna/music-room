# Define the Docker binary with a fallback if not in the PATH of the current shell
DOCKER_BIN := $(shell which docker 2>/dev/null || echo /usr/local/bin/docker)
COMPOSE = $(DOCKER_BIN) compose -f docker-compose.yml
UNAME_S := $(shell uname -s)

# Default target to compile for all platforms
build: build-web build-apk build-ios

# * Utility targets running inside Docker
clean:
	$(COMPOSE) run --rm flutter-linux sh -c "flutter clean || (rm -rf build/* .dart_tool/* .flutter-plugins* && exit 0)"

pub-get:
	$(COMPOSE) run --rm flutter-linux flutter pub get

# * Compile targets that automatically clean and fetch packages
build-web: clean pub-get
	$(COMPOSE) run --rm flutter-linux flutter build web --release

build-apk: clean pub-get
	$(COMPOSE) run --rm flutter-linux flutter build apk --release

# * Compile the iOS app.
# If the host is macOS, we build natively (much faster).
# If the host is Linux/Windows, we spin up the virtualized macOS container.
build-ios:
ifeq ($(UNAME_S),Darwin)
	@echo "🍎 macOS detected! Building iOS natively..."
	flutter clean
	flutter pub get
	flutter build ios --release --no-codesign
else
	@echo "🐧/🪟 Non-macOS environment detected. Using dockurr/macos container..."
	@if ! $(COMPOSE) ps --services --filter "status=running" | grep -q "^macos-builder$$"; then \
		echo "Container 'macos-builder' is not running. Spinning it up..."; \
		$(COMPOSE) up -d macos-builder; \
		echo "macOS Sequoia is booting. Please wait a moment for the VM to start, then run 'make build-ios' again."; \
	else \
		$(COMPOSE) exec macos-builder sh -c "cd /storage && flutter build ios --release --no-codesign"; \
	fi
endif

# * Build the web assets and spin up the Nginx local web server on port 8080
run: build-web
	$(COMPOSE) up -d web-server

.PHONY: build build-ios build-apk build-web run clean pub-get