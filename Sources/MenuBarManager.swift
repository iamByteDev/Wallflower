import AppKit

final class MenuBarManager: NSObject {

    private var statusItem: NSStatusItem!
    private weak var engine: WallpaperEngine?

    init(engine: WallpaperEngine) {
        self.engine = engine
        super.init()
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = .removalAllowed

        if let button = statusItem.button {
            button.image = createMenuBarIcon(size: NSSize(width: 40, height: 40))
            button.image?.isTemplate = true
            button.title = ""
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Wallflower")

        let playPauseItem = NSMenuItem(
            title: "Pause",
            action: #selector(togglePlayPause),
            keyEquivalent: " "
        )
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        let nextItem = NSMenuItem(
            title: "Next Wallpaper",
            action: #selector(nextWallpaper),
            keyEquivalent: ""
        )
        nextItem.keyEquivalentModifierMask = [.command, .shift]
        nextItem.keyEquivalent = "N"
        nextItem.target = self
        menu.addItem(nextItem)

        let prevItem = NSMenuItem(
            title: "Previous Wallpaper",
            action: #selector(previousWallpaper),
            keyEquivalent: ""
        )
        prevItem.keyEquivalentModifierMask = [.command, .shift]
        prevItem.keyEquivalent = "P"
        prevItem.target = self
        menu.addItem(prevItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(
            title: "Open Wallpaper...",
            action: #selector(openWallpaper),
            keyEquivalent: "o"
        )
        openItem.keyEquivalentModifierMask = .command
        openItem.target = self
        menu.addItem(openItem)

        let openDirItem = NSMenuItem(
            title: "Open Wallpaper Directory...",
            action: #selector(openWallpaperDirectory),
            keyEquivalent: ""
        )
        openDirItem.keyEquivalentModifierMask = [.command, .shift]
        openDirItem.keyEquivalent = "O"
        openDirItem.target = self
        menu.addItem(openDirItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Wallflower",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func togglePlayPause(_ sender: NSMenuItem) {
        guard let engine = engine else { return }
        if engine.isPlaying {
            engine.pauseAll()
            sender.title = "Play"
        } else {
            engine.playAll()
            sender.title = "Pause"
        }
    }

    @objc private func nextWallpaper() {
        engine?.nextWallpaper()
    }

    @objc private func previousWallpaper() {
        engine?.previousWallpaper()
    }

    @objc private func openWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .mpeg4Movie, .quickTimeMovie, .html,
            .png, .jpeg, .gif, .heic, .tiff, .bmp,
            .folder,
        ]
        panel.title = "Choose a Wallpaper"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            if url.hasDirectoryPath {
                let files = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )) ?? []

                let supported = files.filter {
                    WallpaperType.detect(from: $0) != .image
                }

                if !supported.isEmpty {
                    self?.engine?.loadWallpapers(from: supported)
                } else if !files.isEmpty {
                    self?.engine?.loadWallpapers(from: files)
                }
            } else {
                self?.engine?.loadSingleWallpaper(from: url)
            }
        }
    }

    @objc private func openWallpaperDirectory() {
        guard let engine = engine, engine.wallpaperCount > 0 else { return }
        let current = engine.getWindowControllers().first?.wallpaperView?.currentURL
        if let dir = current?.deletingLastPathComponent() {
            NSWorkspace.shared.activateFileViewerSelecting([dir])
        }
    }

    @MainActor @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsWindow.shared.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func updatePlayPauseTitle() {
        guard let menu = statusItem.menu, let firstItem = menu.item(at: 0) else { return }
        firstItem.title = (engine?.isPlaying ?? false) ? "Pause" : "Play"
    }

    func updateMenuItems() {
        statusItem.menu = buildMenu()
    }

    private func createMenuBarIcon(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.controlTextColor.setFill()
        let w = size.width
        let h = size.height
        let cx = w / 2
        let cy = h / 2
        let r = min(w, h) * 0.35

        let petalPath = NSBezierPath()
        for i in 0..<5 {
            let angle = Double(i) * .pi * 2 / 5 - .pi / 2
            let px = cx + CGFloat(cos(angle)) * r * 0.52
            let py = cy + CGFloat(sin(angle)) * r * 0.52
            let ctrlR = r * 0.55
            let c1x = cx + CGFloat(cos(angle - 0.55)) * ctrlR
            let c1y = cy + CGFloat(sin(angle - 0.55)) * ctrlR
            let c2x = cx + CGFloat(cos(angle + 0.55)) * ctrlR
            let c2y = cy + CGFloat(sin(angle + 0.55)) * ctrlR
            petalPath.move(to: NSPoint(x: cx, y: cy))
            petalPath.curve(
                to: NSPoint(x: px, y: py),
                controlPoint1: NSPoint(x: c1x, y: c1y),
                controlPoint2: NSPoint(x: c2x, y: c2y)
            )
            petalPath.curve(
                to: NSPoint(x: cx, y: cy),
                controlPoint1: NSPoint(x: c2x, y: c2y),
                controlPoint2: NSPoint(x: c1x, y: c1y)
            )
        }
        petalPath.lineWidth = 1.2
        petalPath.stroke()

        let centerDot = NSBezierPath(
            ovalIn: NSRect(
                x: cx - r * 0.15,
                y: cy - r * 0.15,
                width: r * 0.3,
                height: r * 0.3
            )
        )
        centerDot.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
