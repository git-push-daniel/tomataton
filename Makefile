# Uses Xcode.app's toolchain even if `xcode-select` points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

BUILD_DIR := build
CONFIG ?= Debug
APP := $(BUILD_DIR)/Build/Products/$(CONFIG)/Tomataton.app

# Where `make link-cli` puts the `tomataton` command (must be on PATH).
BIN_DIR ?= /usr/local/bin
CLI := $(abspath $(APP))/Contents/Helpers/tomataton

.PHONY: gen build test run clean link-cli

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

# Symlinks the CLI inside the built app onto PATH; rebuilding updates it in place.
# /usr/local/bin is root-owned, so: `make build && sudo make link-cli`.
link-cli:
	@test -x "$(CLI)" || (echo "Build first: make build" && exit 1)
	ln -sf "$(CLI)" "$(BIN_DIR)/tomataton"
	@echo "Linked $(BIN_DIR)/tomataton -> $(CLI)"

clean:
	rm -rf $(BUILD_DIR) Tomataton.xcodeproj
