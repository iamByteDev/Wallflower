import ScreenSaver
import AVFoundation
import WebKit
import AppKit

final class WallflowerSaverView: ScreenSaverView {

    private var contentView: NSView?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var imageView: NSImageView?
    private var webView: WKWebView?
    private var gifView: GifSaverView?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        animationTimeInterval = 1 / 30
        loadWallpaper()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        animationTimeInterval = 1 / 30
        loadWallpaper()
    }

    override func startAnimation() {
        super.startAnimation()
        player?.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
    }

    override func animateOneFrame() {
        return
    }

    private func loadWallpaper() {
        guard let url = savedWallpaperURL() else {
            showFallbackMessage()
            return
        }

        let type = detectType(from: url)

        switch type {
        case "video":
            loadVideo(url: url)
        case "image":
            loadImage(url: url)
        case "gif":
            loadGif(url: url)
        case "web":
            loadWeb(url: url)
        default:
            showFallbackMessage()
        }
    }

    private func savedWallpaperURL() -> URL? {
        let defaults = UserDefaults.standard
        guard let paths = defaults.stringArray(forKey: "wallflowerWallpapers"),
              !paths.isEmpty else { return nil }

        let idx = defaults.integer(forKey: "wallflowerCurrentIndex")
        let clamped = min(max(idx, 0), paths.count - 1)
        let path = paths[clamped]
        let url = URL(fileURLWithPath: path)

        if FileManager.default.fileExists(atPath: path) {
            return url
        }

        if let first = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return URL(fileURLWithPath: first)
        }

        return nil
    }

    private func detectType(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "m4v", "mkv", "webm", "avi": return "video"
        case "png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp": return "image"
        case "gif": return "gif"
        case "html", "htm": return "web"
        default:
            let last = url.lastPathComponent
            if last == "index.html" || last == "project.json" { return "web" }
            return "video"
        }
    }

    private func loadVideo(url: URL) {
        clearContent()

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.volume = Float(UserDefaults.standard.double(forKey: "volume"))

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds

        if let layer = playerLayer {
            self.layer?.addSublayer(layer)
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        player?.play()
    }

    private func loadImage(url: URL) {
        clearContent()

        guard let image = NSImage(contentsOf: url) else { return }
        imageView = NSImageView(frame: bounds)
        imageView?.image = image
        imageView?.imageScaling = .scaleProportionallyUpOrDown
        imageView?.autoresizingMask = [.width, .height]
        imageView?.wantsLayer = true

        if let iv = imageView {
            addSubview(iv)
        }
    }

    private func loadGif(url: URL) {
        clearContent()

        gifView = GifSaverView(frame: bounds)
        gifView?.autoresizingMask = [.width, .height]
        gifView?.load(contentsOf: url)
        gifView?.play()

        if let gv = gifView {
            addSubview(gv)
        }
    }

    private func loadWeb(url: URL) {
        clearContent()

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: bounds, configuration: config)
        webView?.autoresizingMask = [.width, .height]
        webView?.setValue(false, forKey: "drawsBackground")

        if let wv = webView {
            addSubview(wv)
            if url.pathExtension == "html" || url.pathExtension == "htm" {
                wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else if url.lastPathComponent == "index.html" {
                wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                wv.loadFileURL(url, allowingReadAccessTo: url)
            }
        }
    }

    private func showFallbackMessage() {
        clearContent()
        let label = NSTextField(labelWithString: "Wallflower")
        label.font = NSFont.systemFont(ofSize: 28, weight: .light)
        label.textColor = NSColor.white.withAlphaComponent(0.6)
        label.alignment = .center
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    private func clearContent() {
        contentView?.removeFromSuperview()
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        imageView?.removeFromSuperview()
        imageView = nil
        webView?.removeFromSuperview()
        webView = nil
        gifView?.removeFromSuperview()
        gifView = nil
        subviews.forEach { $0.removeFromSuperview() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
    }
}

final class GifSaverView: NSView {

    private var frames: [CGImage] = []
    private var durations: [TimeInterval] = []
    private var totalDuration: TimeInterval = 0
    private var imageLayer: CALayer?
    private var displayLink: CVDisplayLink?
    private var startTime: TimeInterval = 0
    private var isAnimating: Bool = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func load(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let count = CGImageSourceGetCount(source)

        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(image)
                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    let delay = max(gif[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1, 0.05)
                    durations.append(delay)
                    totalDuration += delay
                } else {
                    durations.append(0.1)
                    totalDuration += 0.1
                }
            }
        }

        imageLayer = CALayer()
        imageLayer?.frame = bounds
        imageLayer?.contentsGravity = .resizeAspectFill
        if let first = frames.first {
            imageLayer?.contents = first
        }
        if let layer = imageLayer {
            self.layer?.addSublayer(layer)
        }
    }

    func play() {
        guard frames.count > 1 else { return }
        isAnimating = true
        startTime = CACurrentMediaTime()

        guard displayLink == nil else { return }
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
            let view = Unmanaged<GifSaverView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { view.updateFrame() }
            return kCVReturnSuccess
        }, selfPtr)

        CVDisplayLinkStart(link)
    }

    func stop() {
        isAnimating = false
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
        if let first = frames.first {
            imageLayer?.contents = first
        }
    }

    private func updateFrame() {
        guard isAnimating, totalDuration > 0, !durations.isEmpty else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let looped = elapsed.truncatingRemainder(dividingBy: totalDuration)

        var acc: TimeInterval = 0
        for i in 0..<durations.count {
            acc += durations[i]
            if looped <= acc {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                imageLayer?.contents = frames[i]
                CATransaction.commit()
                break
            }
        }
    }

    deinit { stop() }
}
