# Muninn — build / run / test entry points. Run `make` for the list, `make menu` to pick.
#
# Annotate every public target with `## [Category] description` on the line
# directly above it; `help` and `menu` both read those lines.

APP_NAME  := Muninn
BUNDLE_ID ?= blue.luci.Muninn
# Your Apple developer team ID, to sign a copy under your own identity (see README). Empty builds ad-hoc signed.
TEAM ?=
PROJECT   := $(APP_NAME).xcodeproj
BUILD_DIR := build
APP_PATH  := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# Per-machine settings (TEAM, BUNDLE_ID), gitignored: see make/local.mk.example.
-include make/local.mk

SIGNING := $(if $(TEAM),DEVELOPMENT_TEAM=$(TEAM) -allowProvisioningUpdates,CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) \
  MUNINN_BUNDLE_ID=$(BUNDLE_ID) $(SIGNING)

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
## [Run] Quit a running Muninn
stop:
	-@pkill -x $(APP_NAME) && echo "Stopped $(APP_NAME)" || true

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
## [Tests] Run the unit tests (quits a running Muninn first)
test: generate stop
	$(XCODEBUILD) -quiet test -destination 'platform=macOS'

# ---------------------------------------------------------------------------
# Release
# ---------------------------------------------------------------------------

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
