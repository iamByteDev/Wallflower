import AppKit

final class ScreenManager {

    typealias ScreenChangeHandler = () -> Void

    private var onScreensChanged: ScreenChangeHandler?
    private var activeScreens: [NSScreen] = []

    init(onChange: @escaping ScreenChangeHandler) {
        self.onScreensChanged = onChange
        cacheScreens()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    var screens: [NSScreen] {
        NSScreen.screens
    }

    var primaryScreen: NSScreen? {
        NSScreen.screens.first
    }

    func screenFrame(for screen: NSScreen) -> NSRect {
        screen.frame
    }

    func screenVisibleFrame(for screen: NSScreen) -> NSRect {
        screen.visibleFrame
    }

    @objc private func screenParametersChanged() {
        let previous = activeScreens
        cacheScreens()
        if !areScreensEqual(previous, activeScreens) {
            onScreensChanged?()
        }
    }

    private func cacheScreens() {
        activeScreens = NSScreen.screens
    }

    private func areScreensEqual(_ a: [NSScreen], _ b: [NSScreen]) -> Bool {
        guard a.count == b.count else { return false }
        for (i, screen) in a.enumerated() {
            if !NSEqualRects(screen.frame, b[i].frame) { return false }
        }
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
