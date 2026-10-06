APP_NAME = Sonotype
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
ENTITLEMENTS = Sonotype.entitlements
INFO_PLIST = Resources/Info.plist

.PHONY: all build check local run clean

all: build

check:
	@echo "==> A executar testes e verificações..."
	swift test

build:
	@echo "==> A compilar $(APP_NAME) com Swift 6..."
	swift build -c release

local: build
	@echo "==> A criar bundle de aplicação $(APP_BUNDLE)..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp $(INFO_PLIST) $(CONTENTS_DIR)/Info.plist
	@if [ -f $(ENTITLEMENTS) ]; then cp $(ENTITLEMENTS) $(RESOURCES_DIR)/; fi
	@echo "==> A assinar com entitlements locais..."
	@codesign --force --sign - --entitlements $(ENTITLEMENTS) $(APP_BUNDLE)
	@echo "==> Bundle pronto em $(APP_BUNDLE)"

run: local
	@echo "==> A iniciar $(APP_NAME)..."
	@open $(APP_BUNDLE)

clean:
	@echo "==> A limpar artefactos de compilação..."
	@rm -rf .build $(BUILD_DIR)
