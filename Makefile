XCODE_PROJECT = NotifyHub/NotifyHub.xcodeproj
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
MAC_APP = $(shell find $(DERIVED_DATA)/NotifyHub-*/Build/Products/Debug/NotifyHub.app -maxdepth 0 2>/dev/null | head -1)

# --- Backend ---

.PHONY: dev deploy db-local db-remote test

dev:
	npx wrangler dev

deploy:
	npx wrangler deploy

db-local:
	npx wrangler d1 execute notify-hub-db --local --file=schema.sql

db-remote:
	npx wrangler d1 execute notify-hub-db --remote --file=schema.sql

test:
	npx vitest run

# --- Xcode project generation ---

.PHONY: generate

generate:
	cd NotifyHub && xcodegen generate
	@# Restore entitlements (xcodegen wipes them)
	@cat > NotifyHub/Resources/NotifyHub.entitlements << 'EOF'
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>com.apple.security.app-sandbox</key>
		<true/>
		<key>com.apple.security.network.client</key>
		<true/>
	</dict>
	</plist>
	EOF

# --- macOS ---

.PHONY: build-mac run-mac install-mac

build-mac:
	xcodebuild -project $(XCODE_PROJECT) -scheme NotifyHub_macOS \
		-destination 'platform=macOS' -configuration Debug build
	@mkdir -p build
	@rm -rf build/NotifyHub.app
	@cp -R "$(MAC_APP)" build/NotifyHub.app
	@echo "✓ build/NotifyHub.app"

run-mac: build-mac
	@pkill -f NotifyHub 2>/dev/null; sleep 0.5; true
	@open build/NotifyHub.app

install-mac: build-mac
	@pkill -f NotifyHub 2>/dev/null; sleep 0.5; true
	@rm -rf /Applications/NotifyHub.app
	@cp -R build/NotifyHub.app /Applications/NotifyHub.app
	@echo "✓ Installed to /Applications/NotifyHub.app"

# --- iOS ---

.PHONY: build-ios run-ios

build-ios:
	xcodebuild -project $(XCODE_PROJECT) -scheme NotifyHub_iOS \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

run-ios: build-ios
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; true
	open -a Simulator
	xcrun simctl install "iPhone 17 Pro" \
		$$(find $(DERIVED_DATA)/NotifyHub-*/Build/Products/Debug-iphonesimulator/NotifyHub.app -maxdepth 0 | head -1)
	xcrun simctl launch "iPhone 17 Pro" com.notifyhub.app

# --- Device install (requires USB + free/paid provisioning) ---

.PHONY: install-iphone install-ipad

install-iphone:
	xcodebuild -project $(XCODE_PROJECT) -scheme NotifyHub_iOS \
		-destination 'platform=iOS,name=*iPhone*' \
		-configuration Debug build
	@echo "✓ Built and installed to connected iPhone"

install-ipad:
	xcodebuild -project $(XCODE_PROJECT) -scheme NotifyHub_iOS \
		-destination 'platform=iOS,name=*iPad*' \
		-configuration Debug build
	@echo "✓ Built and installed to connected iPad"

# --- All ---

.PHONY: build-all

build-all: build-mac build-ios
	@echo "✓ All targets built"
