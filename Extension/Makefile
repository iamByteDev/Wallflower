EXT_BUNDLE = WallflowerWallpaperExtension.appex
EXT_EXEC = $(EXT_BUNDLE)/Contents/MacOS/WallflowerWallpaperExtension
EXT_PLIST = $(EXT_BUNDLE)/Contents/Info.plist

FRAMEWORKS = \
	-framework ExtensionFoundation \
	-framework AppKit \
	-framework AVFoundation \
	-framework QuartzCore \
	-framework Foundation

SWIFT_FLAGS = -parse-as-library -O -target arm64e-apple-macos15.0

.PHONY: all clean

all: $(EXT_BUNDLE)

$(EXT_BUNDLE): WallflowerWallpaperExtension.swift Info.plist
	@mkdir -p $(EXT_BUNDLE)/Contents/MacOS
	@mkdir -p $(EXT_BUNDLE)/Contents/Resources
	swiftc $(SWIFT_FLAGS) $(FRAMEWORKS) \
		-o $(EXT_EXEC) WallflowerWallpaperExtension.swift
	cp Info.plist $(EXT_PLIST)
	@echo "Extension built: $(EXT_BUNDLE)"

clean:
	rm -rf $(EXT_BUNDLE)
