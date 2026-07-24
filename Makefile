SOURCES = $(wildcard Sources/*.swift)
BUNDLE = Wallflower.app
EXEC = $(BUNDLE)/Contents/MacOS/Wallflower
PLIST = $(BUNDLE)/Contents/Info.plist
ICON = $(BUNDLE)/Contents/Resources/AppIcon.icns
SRC_ICON = Resources/AppIcon.icns

FRAMEWORKS = \
	-framework AppKit \
	-framework AVFoundation \
	-framework WebKit \
	-framework SwiftUI \
	-framework QuartzCore \
	-framework ImageIO \
	-framework CoreVideo

SWIFTC = swiftc
SWIFT_FLAGS = -O -target $(shell uname -m)-apple-macos11.0

.PHONY: all build clean run debug icon

all: build

build: $(EXEC) $(PLIST) $(ICON)

$(EXEC): $(SOURCES)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	$(SWIFTC) $(SWIFT_FLAGS) $(FRAMEWORKS) -o $(EXEC) $(SOURCES)

$(PLIST): Resources/Info.plist
	@mkdir -p $(BUNDLE)/Contents
	cp Resources/Info.plist $(PLIST)

$(ICON): $(SRC_ICON)
	@mkdir -p $(BUNDLE)/Contents/Resources
	cp $(SRC_ICON) $(ICON)
	@echo "Build complete: $(BUNDLE)"

icon:
	@rm -rf tmp.iconset
	@mkdir tmp.iconset
	@for size in 16 32 128 256 512; do \
		sips -z $$size $$size icon.png --out tmp.iconset/icon_$${size}x$${size}.png 2>/dev/null; \
		sips -z $$((size*2)) $$((size*2)) icon.png --out tmp.iconset/icon_$${size}x$${size}@2x.png 2>/dev/null; \
	done
	@iconutil -c icns tmp.iconset -o $(SRC_ICON)
	@rm -rf tmp.iconset
	@echo "Icon generated: $(SRC_ICON)"

debug: SWIFT_FLAGS = -g -Onone -target $(shell uname -m)-apple-macos11.0
debug: $(SOURCES)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	$(SWIFTC) $(SWIFT_FLAGS) $(FRAMEWORKS) -o $(EXEC) $(SOURCES)
	cp Resources/Info.plist $(PLIST)
	@if [ -f $(SRC_ICON) ]; then cp $(SRC_ICON) $(ICON); fi
	@echo "Debug build complete: $(BUNDLE)"

clean:
	rm -rf $(BUNDLE)

run: build
	open $(BUNDLE)
