APP_NAME = Sonotype
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
ENTITLEMENTS = Sonotype.entitlements
INFO_PLIST = Resources/Info.plist
REQUIREMENTS = Resources/Sonotype.requirements
DOWNLOADS_DIR = $(HOME)/Downloads
DOWNLOADS_APP = $(DOWNLOADS_DIR)/$(APP_NAME).app
DMG_FILE = $(BUILD_DIR)/$(APP_NAME).dmg
DMG_STAGING = $(BUILD_DIR)/dmg-staging

.PHONY: all build check local dmg run clean

all: build

check:
	@echo "==> A executar testes e verificações..."
	swift test

build:
	@echo "==> A compilar $(APP_NAME) com Swift 6 (Release)..."
	swift build -c release

local: build
	@echo "==> A criar bundle de aplicação $(APP_BUNDLE)..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@cp $(INFO_PLIST) $(CONTENTS_DIR)/Info.plist
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(RESOURCES_DIR)/; fi
	@if [ -f Resources/SonotypeLogo.png ]; then cp Resources/SonotypeLogo.png $(RESOURCES_DIR)/; fi
	@if [ -f Resources/AppIcon.png ]; then cp Resources/AppIcon.png $(RESOURCES_DIR)/; fi
	@echo "==> A assinar bundle localmente com entitlements e designated requirement..."
	@codesign --force --deep --sign - --entitlements $(ENTITLEMENTS) -r="designated => identifier \"com.sonotype.Sonotype\"" $(APP_BUNDLE)
	@codesign --verify --deep --strict $(APP_BUNDLE)
	@rm -rf $(DOWNLOADS_APP) 2>/dev/null || true
	@echo "==> Executável assinado e pronto em $(APP_BUNDLE)"

dmg: local
	@echo "==> A preparar staging para imagem DMG..."
	@rm -rf $(DMG_STAGING) $(DMG_FILE)
	@mkdir -p $(DMG_STAGING)
	@cp -R $(APP_BUNDLE) $(DMG_STAGING)/$(APP_NAME).app
	@ln -s /Applications $(DMG_STAGING)/Applications
	@echo "==> A gerar imagem de disco $(DMG_FILE)..."
	@hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_FILE)"
	@rm -rf $(DMG_STAGING)
	@echo "==> A verificar integridade da imagem DMG..."
	@hdiutil verify $(DMG_FILE)
	@echo "==> Imagem DMG distribuível pronta em $(DMG_FILE)"

run: local
	@echo "==> A iniciar $(APP_NAME)..."
	@open $(APP_BUNDLE)

clean:
	@echo "==> A limpar artefactos de compilação..."
	@rm -rf .build $(BUILD_DIR)
