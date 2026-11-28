# Muninn — build / run / test entry points. Run `make` for the list, `make menu` to pick.
#
# Annotate every public target with `## [Category] description` on the line
# directly above it; `help` and `menu` both read those lines.

APP_NAME  := Muninn
BUNDLE_ID ?= blue.luci.Muninn
# Your Apple developer team ID, to sign a copy under your own identity (see README). Empty builds ad-hoc signed.
TEAM ?=
# Test builds run a separate dev app so the checks never launch, quit or reset the owner's installed Muninn.
TEST_APP_NAME  := Muninn Dev
TEST_BUNDLE_ID := blue.luci.Muninn.dev
PROJECT   := $(APP_NAME).xcodeproj
BUILD_DIR := build
APP_PATH  := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# Per-machine settings (TEAM, BUNDLE_ID), gitignored: see make/local.mk.example.
-include make/local.mk

# The build box declares itself in make/local.mk with `BOX_NAME := prod-build`; see the Release section.
BOX_NAME ?= dev

SIGNING := $(if $(TEAM),DEVELOPMENT_TEAM=$(TEAM) -allowProvisioningUpdates,CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) \
  MUNINN_BUNDLE_ID=$(BUNDLE_ID) $(SIGNING)

# Test builds: dev bundle id (tests: $(TEST_BUNDLE_ID).tests) and product name. Only the app target reads
# MUNINN_PRODUCT_NAME (project.yml), so the tests bundle keeps its own name and the module stays Muninn.
TEST_XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) \
  MUNINN_BUNDLE_ID=$(TEST_BUNDLE_ID) MUNINN_PRODUCT_NAME="$(TEST_APP_NAME)" $(SIGNING)

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

.PHONY: run
## [Run] Build, then (re)launch Muninn — look for the raven in the menu bar
run: build stop
	open $(APP_PATH)
	@echo "Muninn is a menu bar app: no Dock icon. Look for the icon at the top right."

.PHONY: stop
## [Run] Quit your running Muninn (the real app; run by hand, never part of the tests)
stop:
	-@pkill -x $(APP_NAME) && echo "Stopped $(APP_NAME)" || true

.PHONY: stop-dev
## [Run] Quit the Muninn Dev app that the tests build (leaves your real Muninn alone)
stop-dev:
	-@pkill -x "$(TEST_APP_NAME)" && echo "Stopped $(TEST_APP_NAME)" || true

.PHONY: logs
## [Run] Stream Muninn's logs (Ctrl-C to stop)
logs:
	log stream --style compact --predicate 'process == "$(APP_NAME)"'

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

.PHONY: build
## [Build] Build the debug app into ./build
build: generate
	$(XCODEBUILD) -quiet build

.PHONY: screenshots
## [Build] Render the App Store screenshots from the real views with fixture data (quits a running Muninn)
screenshots: build stop
	@mkdir -p listing/screenshots/ms
	@rm -f "$(HOME)/Library/Containers/$(BUNDLE_ID)/Data/tmp/shots/"*.png
	@sleep 2  # LaunchServices needs a moment after the quit
	@# Launch in screenshot mode, then `open` the running app again so it comes forward: controls only draw in
	@# their live colors (not dimmed) in an active app.
	@open -W $(APP_PATH) --args --screenshots & \
	  sleep 3; open $(APP_PATH); wait
	@rm -f listing/screenshots/ms/*.png   # so a renamed or removed scene can't leave a stale file behind
	@cp "$(HOME)/Library/Containers/$(BUNDLE_ID)/Data/tmp/shots/"*.png listing/screenshots/ms/
	@ls -1 listing/screenshots/ms

.PHONY: listing-check
## [Build] Validate listing/ (metadata.json, app.json, screenshots) against Apple's limits (offline)
listing-check:
	@command -v deno >/dev/null 2>&1 || { echo "deno not installed — run: brew install deno"; exit 1; }
	@deno run --allow-read --allow-env scripts/listing_metadata.ts check
	@deno run --allow-read scripts/listing_screenshots.ts check
	@deno run --allow-read scripts/store_setup.ts check

# The Xcode project is generated from project.yml and gitignored. build/test depend on this
# (it's fast) so newly added source files are always picked up.
.PHONY: generate
## [Build] Regenerate Muninn.xcodeproj from project.yml
generate:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not installed — run: brew install xcodegen"; exit 1; }
	@xcodegen generate --quiet

.PHONY: xcode
## [Build] Open the project in Xcode
xcode: generate
	open $(PROJECT)

.PHONY: install
## [Build] Build a Release app and copy it to /Applications
install: generate stop
	xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Release -derivedDataPath $(BUILD_DIR) \
	  MUNINN_BUNDLE_ID=$(BUNDLE_ID) $(SIGNING) -quiet build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app /Applications/
	@echo "Installed /Applications/$(APP_NAME).app"

.PHONY: clean
## [Build] Remove build output and the generated Xcode project
clean: stop
	rm -rf $(BUILD_DIR) $(PROJECT)

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

.PHONY: test
## [Tests] Run the unit tests in a separate "Muninn Dev" app (never touches your running Muninn)
test: generate stop-dev
	$(TEST_XCODEBUILD) -quiet test -destination 'platform=macOS'

.PHONY: test-listing
## [Tests] Store-listing tools (Deno): diff/plan logic, Apple's limits, and a check of listing/ (offline, no credentials)
test-listing: listing-check
	@command -v deno >/dev/null 2>&1 || { echo "deno not installed — run: brew install deno"; exit 1; }
	deno test --allow-read --allow-run=make scripts/

.PHONY: build-for-testing
## [Tests] Compile the app and its unit-test target without running anything (unsigned, no launch, no simulator)
build-for-testing: generate
	$(TEST_XCODEBUILD) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- -destination 'platform=macOS' build-for-testing

# ---------------------------------------------------------------------------
# Release
# ---------------------------------------------------------------------------

# The App Store targets touch the live App Store Connect API key, so they only exist as make rules on the box that
# declares BOX_NAME := prod-build in make/local.mk. Elsewhere `make testflight` fails with "No rule to make target".
ifeq ($(BOX_NAME),prod-build)
-include make/store.mk
endif

# Needs a Developer ID Application certificate for your team, an App Store Connect API key (used for notarization)
# in your environment, and the `gh` CLI signed in. See DISTRIBUTION.md.
VERSION ?= 1.0.$(shell git rev-list --count HEAD)

.PHONY: github-release
## [Release] Build a Developer ID-signed, notarized Muninn and attach it to a GitHub Release (v1.0.<commit count>)
github-release:
	@test -n "$(TEAM)" || { echo "✗ TEAM is required (your Apple team ID): set it in make/local.mk"; exit 1; }
	@./scripts/release_preflight.sh git xcodebuild xcodegen gh
	@git diff --quiet && git diff --cached --quiet || { echo "✗ working tree dirty: commit or stash before releasing"; exit 1; }
	@$(MAKE) --no-print-directory generate
	VERSION=$(VERSION) BUILD=$$(git rev-list --count HEAD) BUNDLE_ID=$(BUNDLE_ID) TEAM=$(TEAM) ./scripts/direct_release.sh

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

.PHONY: help
## [Utilities] List targets, grouped by category
help:
	@awk -f scripts/makefile_help.awk $(MAKEFILE_LIST)

.PHONY: menu
## [Utilities] Interactive grouped target picker (fzf + preview)
menu:
	@command -v fzf >/dev/null 2>&1 || { echo "fzf not installed — run: brew install fzf"; exit 1; }
	@bash scripts/menu.sh
