SAVER = Wallflower.saver
EXEC = $(SAVER)/Contents/MacOS/WallflowerSaver
PLIST = $(SAVER)/Contents/Info.plist
INSTALL = $(HOME)/Library/Screen Savers/$(SAVER)

FRAMEWORKS = \
	-framework ScreenSaver \
	-framework AppKit \
	-framework AVFoundation \
	-framework WebKit \
	-framework QuartzCore \
	-framework ImageIO \
	-framework CoreVideo

SWIFT_FLAGS = -O -target $(shell uname -m)-apple-macos11.0

.PHONY: all clean install

all: $(SAVER)

$(SAVER): WallflowerSaver.swift Info.plist
	@mkdir -p $(SAVER)/Contents/MacOS
	@mkdir -p $(SAVER)/Contents/Resources
	swiftc $(SWIFT_FLAGS) $(FRAMEWORKS) -o $(EXEC) WallflowerSaver.swift
	cp Info.plist $(PLIST)
	codesign --force --deep --sign - $(SAVER)
	@echo "Screen saver built: $(SAVER)"

install: $(SAVER)
	@mkdir -p "$(HOME)/Library/Screen Savers"
	rm -rf "$(INSTALL)"
	cp -R $(SAVER) "$(INSTALL)"
	@echo "Installed. Go to System Settings > Screen Saver and select Wallflower."

clean:
	rm -rf $(SAVER)
