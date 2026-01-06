.PHONY: build lint lint-fix test clean run release-app release all

# Variables
BINARY_NAME=CCHistory
APP_NAME=$(BINARY_NAME).app
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DIR=.build
RELEASE_DIR=release

# Build the application
build:
	@echo "Building $(BINARY_NAME)..."
	swift build -c release --product $(BINARY_NAME)
	@echo "Build complete: $(BUILD_DIR)/release/$(BINARY_NAME)"

# Run linting checks (same as CI)
lint:
	@echo "Running linters..."
	@if ! command -v swift-format &> /dev/null; then \
		echo "Installing swift-format..."; \
		brew install swift-format; \
	fi
	@echo "Checking Swift formatting..."
	@swift-format lint --recursive Sources/ Tests/
	@echo "Lint passed!"

# Fix linting issues
lint-fix:
	@echo "Fixing Swift formatting..."
	@if ! command -v swift-format &> /dev/null; then \
		echo "Installing swift-format..."; \
		brew install swift-format; \
	fi
	swift-format --in-place --recursive Sources/ Tests/
	@echo "Formatting fixed!"

# Run tests
test:
	@echo "Running tests..."
	@if [ -d "Tests" ]; then \
		swift test --enable-code-coverage; \
	else \
		echo "No tests directory found, skipping tests"; \
	fi

# Create app bundle with code signing
release-app: build
	@echo "Creating app bundle..."
	@rm -rf $(APP_NAME)
	@mkdir -p $(APP_NAME)/Contents/MacOS
	@mkdir -p $(APP_NAME)/Contents/Resources
	@cp $(BUILD_DIR)/release/$(BINARY_NAME) $(APP_NAME)/Contents/MacOS/
	@export DEVELOPER_IDENTITY="$${DEVELOPER_IDENTITY:-Developer ID Application: Vo Minh Tuan Nguyen (6HDG24ZGVT)}"; \
	./build.sh
	@echo "App bundle complete: $(APP_NAME)"

# Create and push new GitHub release (increments version)
release:
	@echo "Preparing new release..."
	@# Get latest version from GitHub
	@LATEST_VERSION=$$(gh release view --json tagName 2>/dev/null | jq -r '.tagName' | sed 's/v//'); \
	if [ -z "$$LATEST_VERSION" ]; then \
		NEW_VERSION="0.0.1"; \
	else \
		NEW_VERSION=$$(echo $$LATEST_VERSION | awk -F. '{printf "%d.%d.%d", $$1, $$2, $$3+1}'); \
	fi; \
	NEW_TAG="v$$NEW_VERSION"; \
	echo "Current version: $$LATEST_VERSION"; \
	echo "New version: $$NEW_VERSION"; \
	# Create tag and push \
	git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
	git push origin "$$NEW_TAG"; \
	echo "Release $$NEW_TAG created and pushed!"; \
	echo "GitHub Actions will build the release automatically."

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf $(APP_NAME)
	rm -rf $(RELEASE_DIR)
	@echo "Clean complete"

# Run the application
run: build
	@echo "Launching $(APP_NAME)..."
	@if [ -d "$(APP_NAME)" ]; then \
		open $(APP_NAME); \
	else \
		swift run CCHistory; \
	fi

# Show all available targets
help:
	@echo "Available targets:"
	@echo "  make build      - Build the application"
	@echo "  make lint       - Run Swift formatting checks"
	@echo "  make lint-fix   - Fix Swift formatting issues automatically"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make release-app- Create signed app bundle"
	@echo "  make release    - Create new GitHub release (version bump)"
	@echo "  make run        - Build and run the application"
	@echo "  make help       - Show this help message"
	@echo "  make all        - Clean and build"

# Default target
all: clean build lint
