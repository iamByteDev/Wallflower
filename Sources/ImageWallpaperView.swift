import AppKit

final class ImageWallpaperView: NSView, WallpaperViewProtocol {

    private var imageView: NSImageView?
    private var _currentURL: URL?

    var isPlaying: Bool { true }
    var hasAudio: Bool { false }
    var currentURL: URL? { _currentURL }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func load(contentsOf url: URL) {
        _currentURL = url

        imageView?.removeFromSuperview()

        guard let image = NSImage(contentsOf: url) else { return }

        let iv = NSImageView(frame: bounds)
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        iv.wantsLayer = true

        addSubview(iv)
        imageView = iv
    }

    func play() {}
    func pause() {}
    func stop() {}
    func setVolume(_ volume: Float) {}
    func setPlaybackRate(_ rate: Float) {}
}
