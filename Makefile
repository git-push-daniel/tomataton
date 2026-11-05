# Uses Xcode.app's toolchain even if `xcode-select` points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

BUILD_DIR := build
CONFIG ?= Debug
APP := $(BUILD_DIR)/Build/Products/$(CONFIG)/Tomataton.app

.PHONY: gen build test run clean

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

clean:
	rm -rf $(BUILD_DIR) Tomataton.xcodeproj
