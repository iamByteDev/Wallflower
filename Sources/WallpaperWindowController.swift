import AppKit

final class WallpaperWindowController: NSWindowController {

    let screenID: String
    private(set) var wallpaperView: (NSView & WallpaperViewProtocol)?

    init(screen: NSScreen) {
        let desc = screen.deviceDescription
        self.screenID = "\((desc[.init("NSScreenNumber")] as? NSNumber)?.intValue ?? screen.hash)"

        let rect = screen.frame
        let window = WallpaperWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = WallpaperWindowController.desktopWallpaperLevel

        super.init(window: window)

        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        window.isMovableByWindowBackground = false
        window.isMovable = false
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    static var desktopWallpaperLevel: NSWindow.Level {
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        return NSWindow.Level(rawValue: iconLevel - 1)
    }

    func loadWallpaper(at url: URL) {
        let type = WallpaperType.detect(from: url)
        let view = type.createView(frame: window?.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true

        window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
        window?.contentView?.addSubview(view)
        view.frame = window?.contentView?.bounds ?? .zero

        wallpaperView = view
        view.load(contentsOf: url)
    }

    func updateFrame(to rect: NSRect) {
        window?.setFrame(rect, display: true, animate: false)
        wallpaperView?.frame = window?.contentView?.bounds ?? rect
    }

    func play() { wallpaperView?.play() }
    func pause() { wallpaperView?.pause() }
    func stop() { wallpaperView?.stop() }
    func setVolume(_ v: Float) { wallpaperView?.setVolume(v) }
    func setPlaybackRate(_ r: Float) { wallpaperView?.setPlaybackRate(r) }
    var isPlaying: Bool { wallpaperView?.isPlaying ?? false }
    var hasAudio: Bool { wallpaperView?.hasAudio ?? false }
}
