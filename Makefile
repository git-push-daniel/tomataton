# Uses Xcode.app's toolchain even if `xcode-select` points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

BUILD_DIR := build
CONFIG ?= Debug
APP = $(BUILD_DIR)/Build/Products/$(CONFIG)/Tomataton.app

INSTALL_DIR ?= /Applications
INSTALLED_APP := $(INSTALL_DIR)/Tomataton.app

# Where `make link-cli` puts the `tomataton` command (must be on PATH).
BIN_DIR ?= /usr/local/bin
# The installed app's CLI if there is one, else the one in the latest build.
CLI = $(if $(wildcard $(INSTALLED_APP)),$(INSTALLED_APP),$(abspath $(APP)))/Contents/Helpers/tomataton

.PHONY: gen build test run install link-cli clean

gen:
	xcodegen generate --quiet

build: gen
	xcodebuild -project Tomataton.xcodeproj -scheme Tomataton -configuration $(CONFIG) \
		-destination 'platform=macOS,arch=arm64' -derivedDataPath $(BUILD_DIR) -quiet build

test:
	cd Packages/TomatoKit && swift test

run: build
	-pkill -x Tomataton
	@while pgrep -x Tomataton >/dev/null; do sleep 0.1; done
	open $(APP)

# Builds a Release copy into /Applications and (re)starts it from there.
# Quitting the running app pauses its timer, so press Start again afterwards.
install: CONFIG = Release
install: build
	-pkill -x Tomataton
	@while pgrep -x Tomataton >/dev/null; do sleep 0.1; done
	rm -rf "$(INSTALLED_APP)"
	ditto "$(APP)" "$(INSTALLED_APP)"
	open "$(INSTALLED_APP)"
	@echo "Installed $(INSTALLED_APP). Put the CLI on PATH with: sudo make link-cli"

# Symlinks the CLI onto PATH; reinstalling or rebuilding updates it in place.
# /usr/local/bin is root-owned, so: `sudo make link-cli`.
link-cli:
	@test -x "$(CLI)" || (echo "Build or install first: make install" && exit 1)
	ln -sf "$(CLI)" "$(BIN_DIR)/tomataton"
	@echo "Linked $(BIN_DIR)/tomataton -> $(CLI)"

clean:
	rm -rf $(BUILD_DIR) Tomataton.xcodeproj
