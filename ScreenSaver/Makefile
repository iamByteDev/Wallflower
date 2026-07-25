SAVER_BUNDLE = Wallflower.saver
SAVER_EXEC = $(SAVER_BUNDLE)/Contents/MacOS/WallflowerSaver
SAVER_PLIST = $(SAVER_BUNDLE)/Contents/Info.plist

FRAMEWORKS = \
	-framework ScreenSaver \
	-framework AppKit \
	-framework AVFoundation \
	-framework WebKit \
	-framework QuartzCore \
	-framework ImageIO \
	-framework CoreVideo

SWIFT_FLAGS = -O -target $(shell uname -m)-apple-macos11.0
INSTALL_DIR = $(HOME)/Library/Screen Savers

.PHONY: all build clean install

all: build

build: $(EXEC) $(PLIST)
	@echo "Usage: make build | make install"

# We need to make the saver target work properly
# The issue is we need to use the root makefile's naming convention
# This is a standalone build

saver:
	@mkdir -p $(SAVER_BUNDLE)/Contents/MacOS
	@mkdir -p $(SAVER_BUNDLE)/Contents/Resources
	swiftc $(SWIFT_FLAGS) $(FRAMEWORKS) \
		-o $(SAVER_EXEC) WallflowerSaver.swift
	cp Info.plist $(SAVER_PLIST)
	@echo "Screen saver built: $(SAVER_BUNDLE)"

install: saver
	@mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(SAVER_BUNDLE)"
	cp -R $(SAVER_BUNDLE) "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(SAVER_BUNDLE)"
	@echo "Go to System Settings > Screen Saver and select 'Wallflower'"

clean:
	rm -rf $(SAVER_BUNDLE)
