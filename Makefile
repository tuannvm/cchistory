.PHONY: build lint lint-fix test clean run release notarize all

# Variables
BINARY_NAME=CCHistory
APP_NAME=$(BINARY_NAME).app
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_DIR=.build
RELEASE_DIR=release

# Notarization credentials (set via environment or keychain profile)
# Export these or use --keychain-profile instead:
#   NOTARY_APPLE_ID, NOTARY_PASSWORD, NOTARY_TEAM_ID
KEYCHAIN_PROFILE ?= cchistory-notary-profile

# Build the application and create signed app bundle
build:
	@echo "Building $(BINARY_NAME)..."
	swift build -c release --product $(BINARY_NAME)
	@echo "Build complete: $(BUILD_DIR)/release/$(BINARY_NAME)"
	@echo "Creating app bundle..."
	@rm -rf $(APP_NAME)
	@mkdir -p $(APP_NAME)/Contents/MacOS
	@mkdir -p $(APP_NAME)/Contents/Resources
	@cp $(BUILD_DIR)/release/$(BINARY_NAME) $(APP_NAME)/Contents/MacOS/
	@if [ -f "$(BINARY_NAME).icns" ]; then \
		cp $(BINARY_NAME).icns $(APP_NAME)/Contents/Resources/; \
	fi
	@sed -e 's/EXECUTABLE_NAME/$(BINARY_NAME)/g' \
	     -e 's/BUNDLE_NAME/$(BINARY_NAME)/g' \
	     -e 's/VERSION/$(VERSION)/g' \
	     Info.plist.template > $(APP_NAME)/Contents/Info.plist
	@echo "Code signing with $(DEVELOPER_IDENTITY)..."
	@xattr -cr $(APP_NAME)
	@codesign --force --options runtime --sign "$(DEVELOPER_IDENTITY)" $(APP_NAME)
	@codesign -vvv $(APP_NAME)
	@echo "Build complete: $(APP_NAME)"

# Run linting checks (same as CI)
lint:
	@echo "Running linters..."
	@if ! command -v swift-format &> /dev/null; then \
		echo "Installing swift-format..."; \
		brew install swift-format; \
	fi
	@echo "Checking Swift formatting..."
	@swift-format lint --recursive --strict Sources/CCHistory
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

# Notarize the app (requires build first)
notarize: build
	@echo "Creating zip for notarization..."
	@zip -r $(RELEASE_DIR)/$(BINARY_NAME).zip $(APP_NAME)
	@echo "Submitting to Apple notary service..."
	@if [ -n "$$NOTARY_APPLE_ID" ] && [ -n "$$NOTARY_PASSWORD" ] && [ -n "$$NOTARY_TEAM_ID" ]; then \
		xcrun notarytool submit $(RELEASE_DIR)/$(BINARY_NAME).zip \
			--apple-id "$$NOTARY_APPLE_ID" \
			--password "$$NOTARY_PASSWORD" \
			--team-id "$$NOTARY_TEAM_ID" \
			--wait; \
	else \
		xcrun notarytool submit $(RELEASE_DIR)/$(BINARY_NAME).zip \
			--keychain-profile "$(KEYCHAIN_PROFILE)" \
			--wait; \
	fi
	@echo "Stapling notarization ticket..."
	@xcrun stapler staple $(APP_NAME)
	@echo "Verifying notarization..."
	@spctl -a -vvvv $(APP_NAME)
	@echo "Notarization complete!"
	@echo "Recreating zip with stapled app..."
	@rm -f $(RELEASE_DIR)/$(BINARY_NAME).zip
	@zip -r $(RELEASE_DIR)/$(BINARY_NAME).zip $(APP_NAME)

# Create and push new GitHub release (increments version, notarizes, uploads to release)
release: clean notarize
	@echo "Preparing new release..."
	@LATEST_VERSION=$$(gh release view --json tagName 2>/dev/null | jq -r '.tagName' | sed 's/v//'); \
	if [ -z "$$LATEST_VERSION" ]; then \
		NEW_VERSION="0.0.1"; \
	else \
		NEW_VERSION=$$(echo $$LATEST_VERSION | awk -F. '{printf "%d.%d.%d", $$1, $$2, $$3+1}'); \
	fi; \
	NEW_TAG="v$$NEW_VERSION"; \
	echo "Current version: $$LATEST_VERSION"; \
	echo "New version: $$NEW_VERSION"; \
	echo "Creating and pushing tag..."; \
	git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
	git push origin "$$NEW_TAG"; \
	echo "Creating GitHub release..."; \
	gh release create "$$NEW_TAG" --title "$$NEW_TAG" --notes "Release $$NEW_TAG" $(RELEASE_DIR)/$(BINARY_NAME).zip; \
	echo "Release $$NEW_TAG created with notarized $(BINARY_NAME).zip!"

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
	@echo "  make build      - Build and sign app bundle"
	@echo "  make notarize   - Build, sign, and notarize app for Gatekeeper"
	@echo "  make lint       - Run Swift formatting checks"
	@echo "  make lint-fix   - Fix Swift formatting issues automatically"
	@echo "  make test       - Run tests"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make release    - Create new GitHub release (version bump + notarize + upload)"
	@echo "  make run        - Build and run the application"
	@echo "  make help       - Show this help message"
	@echo "  make all        - Clean and build"
	@echo ""
	@echo "Environment variables:"
	@echo "  DEVELOPER_IDENTITY - Code signing identity"
	@echo "  NOTARY_APPLE_ID   - Apple ID for notarization (or use keychain profile)"
	@echo "  NOTARY_PASSWORD   - App-specific password for notarization"
	@echo "  NOTARY_TEAM_ID    - Apple Developer team ID"
	@echo "  KEYCHAIN_PROFILE  - Keychain profile name (default: cchistory-notary-profile)"
	@echo ""
	@echo "Notarization setup:"
	@echo "  1. Create app-specific password: https://appleid.apple.com"
	@echo "  2. Store credentials in keychain:"
	@echo "     xcrun notarytool store-credentials \"cchistory-notary-profile\""
	@echo ""
	@echo "Or set environment variables for one-time use:"
	@echo "  NOTARY_APPLE_ID=\"you@example.com\" \\"
	@echo "  NOTARY_PASSWORD=\"abcd-efgh-ijkl-mnop\" \\"
	@echo "  NOTARY_TEAM_ID=\"ABC123XYZ\" \\"
	@echo "  make notarize"

# Default target
all: clean build lint
