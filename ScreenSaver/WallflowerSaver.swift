import ScreenSaver
import AVFoundation
import WebKit
import AppKit

final class WallflowerSaverView: ScreenSaverView {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var imageView: NSImageView?
    private var webView: WKWebView?
    private var gifView: GifSaverView?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        animationTimeInterval = 1 / 30
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        animationTimeInterval = 1 / 30
    }

    deinit {
        player?.pause()
        NotificationCenter.default.removeObserver(self)
    }

    override func startAnimation() {
        super.startAnimation()
        loadWallpaper()
        player?.play()
        gifView?.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
        gifView?.stop()
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
    }

    override func animateOneFrame() {}

    private func loadWallpaper() {
        guard let url = savedWallpaperURL() else {
            showLabel("Wallflower")
            return
        }

        let ext = url.pathExtension.lowercased()

        switch ext {
        case "mp4", "mov", "m4v", "mkv", "webm", "avi":
            loadVideo(url)
        case "png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp":
            loadImage(url)
        case "gif":
            loadGif(url)
        case "html", "htm":
            loadWeb(url)
        default:
            loadVideo(url)
        }
    }

    private func savedWallpaperURL() -> URL? {
        let sharedPath = NSHomeDirectory()
            + "/Library/Application Support/Wallflower/current-wallpaper.txt"

        if let content = try? String(contentsOfFile: sharedPath, encoding: .utf8) {
            let path = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        let defaults = UserDefaults.standard
        guard let paths = defaults.stringArray(forKey: "wallflowerWallpapers"),
              !paths.isEmpty else { return nil }
        let idx = max(0, min(defaults.integer(forKey: "wallflowerCurrentIndex"), paths.count - 1))
        guard idx < paths.count else { return nil }
        let url = URL(fileURLWithPath: paths[idx])
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func clearContent() {
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

    private func loadVideo(_ url: URL) {
        clearContent()

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        let p = AVPlayer(playerItem: item)
        p.volume = Float(UserDefaults.standard.double(forKey: "volume"))
        player = p

        playerLayer = AVPlayerLayer(player: p)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds

        if let pl = playerLayer {
            layer?.addSublayer(pl)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        p.play()
    }

    @objc private func videoDidEnd() {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    private func loadImage(_ url: URL) {
        clearContent()
        guard let img = NSImage(contentsOf: url) else { return }
        let iv = NSImageView(frame: bounds)
        iv.image = img
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)
        imageView = iv
    }

    private func loadGif(_ url: URL) {
        clearContent()
        let gv = GifSaverView(frame: bounds)
        gv.autoresizingMask = [.width, .height]
        gv.load(contentsOf: url)
        gv.play()
        addSubview(gv)
        gifView = gv
    }

    private func loadWeb(_ url: URL) {
        clearContent()
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: bounds, configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.setValue(false, forKey: "drawsBackground")
        wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        addSubview(wv)
        webView = wv
    }

    private func showLabel(_ text: String) {
        clearContent()
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 28, weight: .light)
        label.textColor = NSColor.white.withAlphaComponent(0.5)
        label.alignment = .center
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
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
        fatalError()
    }

    func load(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            if let img = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(img)
                let delay: TimeInterval
                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    delay = max(gif[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1, 0.05)
                } else {
                    delay = 0.1
                }
                durations.append(delay)
                totalDuration += delay
            }
        }

        imageLayer = CALayer()
        imageLayer?.frame = bounds
        imageLayer?.contentsGravity = .resizeAspectFill
        if let first = frames.first {
            imageLayer?.contents = first
        }
        if let il = imageLayer { layer?.addSublayer(il) }
    }

    func play() {
        guard frames.count > 1, displayLink == nil else { return }
        isAnimating = true
        startTime = CACurrentMediaTime()
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
            let v = Unmanaged<GifSaverView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { v.tick() }
            return kCVReturnSuccess
        }, ptr)
        CVDisplayLinkStart(link)
    }

    func stop() {
        isAnimating = false
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    private func tick() {
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
