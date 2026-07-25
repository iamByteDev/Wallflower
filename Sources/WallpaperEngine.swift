import AppKit

final class WallpaperEngine {

    private var windows: [String: WallpaperWindowController] = [:]
    private var screenManager: ScreenManager!
    private var wallpaperURLs: [URL] = []
    private var currentWallpaperIndex: Int = 0
    private var isEngineRunning: Bool = false

    var isPlaying: Bool {
        windows.values.first?.isPlaying ?? false
    }

    var wallpaperCount: Int { wallpaperURLs.count }
    var currentIndex: Int { currentWallpaperIndex }

    func start() {
        guard !isEngineRunning else { return }
        isEngineRunning = true

        applyStoredSettings()
        restoreSession()

        screenManager = ScreenManager { [weak self] in
            self?.reconcileScreens()
        }

        reconcileScreens()

        LockScreenManager.activateScreenSaver()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolumeChange(_:)),
            name: .wallflowerVolumeChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRateChange(_:)),
            name: .wallflowerRateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePauseOnBatteryChange(_:)),
            name: .wallflowerPauseOnBatteryChanged,
            object: nil
        )
    }

    func stop() {
        saveSession()
        isEngineRunning = false
        pauseAll()
        for (_, wc) in windows {
            wc.stop()
            wc.close()
        }
        windows.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    func loadWallpapers(from urls: [URL]) {
        wallpaperURLs = urls
        currentWallpaperIndex = 0
        applyWallpaperToAll()
        saveSession()
    }

    func loadSingleWallpaper(from url: URL) {
        wallpaperURLs = [url]
        currentWallpaperIndex = 0
        applyWallpaperToAll()
        saveSession()
    }

    func nextWallpaper() {
        guard !wallpaperURLs.isEmpty else { return }
        currentWallpaperIndex = (currentWallpaperIndex + 1) % wallpaperURLs.count
        applyWallpaperToAll()
        saveSession()
    }

    func previousWallpaper() {
        guard !wallpaperURLs.isEmpty else { return }
        currentWallpaperIndex = (currentWallpaperIndex - 1 + wallpaperURLs.count)
            % wallpaperURLs.count
        applyWallpaperToAll()
        saveSession()
    }

    func playAll() {
        for (_, wc) in windows { wc.play() }
    }

    func pauseAll() {
        for (_, wc) in windows { wc.pause() }
    }

    func stopAll() {
        for (_, wc) in windows { wc.stop() }
    }

    func setVolumeAll(_ volume: Float) {
        for (_, wc) in windows { wc.setVolume(volume) }
    }

    func setPlaybackRateAll(_ rate: Float) {
        for (_, wc) in windows { wc.setPlaybackRate(rate) }
    }

    func getWindowControllers() -> [WallpaperWindowController] {
        Array(windows.values)
    }

    private func applyStoredSettings() {
        let defaults = UserDefaults.standard
        let volume = Float(defaults.double(forKey: "volume"))
        let rate = Float(defaults.double(forKey: "playbackRate"))
        setVolumeAll(volume)
        setPlaybackRateAll(rate > 0 ? rate : 1.0)
    }

    private func reconcileScreens() {
        let currentIDs = Set(NSScreen.screens.map { uniqueID(for: $0) })
        let existingIDs = Set(windows.keys)

        for id in existingIDs.subtracting(currentIDs) {
            windows[id]?.stop()
            windows[id]?.close()
            windows.removeValue(forKey: id)
        }

        for screen in NSScreen.screens {
            let id = uniqueID(for: screen)
            if windows[id] == nil {
                let wc = WallpaperWindowController(screen: screen)
                windows[id] = wc
                if !wallpaperURLs.isEmpty {
                    let url = wallpaperURLs[currentWallpaperIndex]
                    wc.loadWallpaper(at: url)
                }
                applyStoredSettings()
            } else {
                windows[id]?.updateFrame(to: screen.frame)
            }
        }
    }

    private func applyWallpaperToAll() {
        guard !wallpaperURLs.isEmpty,
              currentWallpaperIndex < wallpaperURLs.count else { return }

        let url = wallpaperURLs[currentWallpaperIndex]
        for (_, wc) in windows {
            wc.loadWallpaper(at: url)
        }
        applyStoredSettings()
        LockScreenManager.applyLockScreen(imageURL: url, requestPrivileges: false)
    }

    private func uniqueID(for screen: NSScreen) -> String {
        let desc = screen.deviceDescription
        if let num = desc[.init("NSScreenNumber")] as? NSNumber {
            return "\(num.intValue)"
        }
        return "\(screen.hash)"
    }

    private func saveSession() {
        let defaults = UserDefaults.standard
        let paths = wallpaperURLs.map { $0.path }
        defaults.set(paths, forKey: "wallflowerWallpapers")
        defaults.set(currentWallpaperIndex, forKey: "wallflowerCurrentIndex")
    }

    private func restoreSession() {
        let defaults = UserDefaults.standard
        guard let paths = defaults.stringArray(forKey: "wallflowerWallpapers"),
              !paths.isEmpty else { return }

        let urls = paths.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !urls.isEmpty else {
            defaults.removeObject(forKey: "wallflowerWallpapers")
            return
        }

        wallpaperURLs = urls
        currentWallpaperIndex = defaults.integer(forKey: "wallflowerCurrentIndex")

        if currentWallpaperIndex >= wallpaperURLs.count {
            currentWallpaperIndex = 0
        }
    }

    @objc private func handleSleep() {
        pauseAll()
    }

    @objc private func handleWake() {
        reconcileScreens()
        playAll()
    }

    @objc private func handleVolumeChange(_ notification: Notification) {
        guard let volume = notification.userInfo?["volume"] as? Float else { return }
        setVolumeAll(volume)
    }

    @objc private func handleRateChange(_ notification: Notification) {
        guard let rate = notification.userInfo?["rate"] as? Float else { return }
        setPlaybackRateAll(rate)
    }

    @objc private func handlePauseOnBatteryChange(_ notification: Notification) {
        guard let shouldPause = notification.userInfo?["value"] as? Bool else { return }
        if shouldPause {
            pauseAll()
        } else {
            playAll()
        }
    }
}
