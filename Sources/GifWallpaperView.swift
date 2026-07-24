import AppKit
import ImageIO
import QuartzCore

final class GifWallpaperView: NSView, WallpaperViewProtocol {

    private var imageSource: CGImageSource?
    private var frameCount: Int = 0
    private var frames: [CGImage] = []
    private var durations: [TimeInterval] = []
    private var totalDuration: TimeInterval = 0
    private var displayLink: CVDisplayLink?
    private var startTime: TimeInterval = 0
    private var _isPlaying: Bool = false
    private var _currentURL: URL?
    private var imageLayer: CALayer?

    var isPlaying: Bool { _isPlaying }
    var hasAudio: Bool { false }
    var currentURL: URL? { _currentURL }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            stopDisplayLink()
        } else if _isPlaying {
            startDisplayLink()
        }
        imageLayer?.frame = bounds
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        imageLayer?.frame = bounds
    }

    func load(contentsOf url: URL) {
        _currentURL = url
        stopDisplayLink()
        frames.removeAll()
        durations.removeAll()
        totalDuration = 0

        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        imageSource = source
        frameCount = CGImageSourceGetCount(source)

        for i in 0..<frameCount {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(image)

                if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    let delay = (gifProps[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
                    durations.append(max(delay, 0.05))
                    totalDuration += max(delay, 0.05)
                } else {
                    durations.append(0.1)
                    totalDuration += 0.1
                }
            }
        }

        imageLayer = CALayer()
        imageLayer?.frame = bounds
        imageLayer?.contentsGravity = .resizeAspectFill
        if let firstFrame = frames.first {
            imageLayer?.contents = firstFrame
        }

        if let layer = imageLayer {
            self.layer?.addSublayer(layer)
        }

        play()
    }

    func play() {
        guard frameCount > 1 else {
            if let first = frames.first {
                imageLayer?.contents = first
            }
            return
        }
        _isPlaying = true
        startTime = CACurrentMediaTime()
        startDisplayLink()
    }

    func pause() {
        _isPlaying = false
        stopDisplayLink()
    }

    func stop() {
        _isPlaying = false
        stopDisplayLink()
        if let first = frames.first {
            imageLayer?.contents = first
        }
    }

    func setVolume(_ volume: Float) {}
    func setPlaybackRate(_ rate: Float) {}

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, context) -> CVReturn in
            let view = Unmanaged<GifWallpaperView>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async { view.updateFrame() }
            return kCVReturnSuccess
        }, selfPtr)

        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    private func updateFrame() {
        guard _isPlaying, totalDuration > 0, !durations.isEmpty else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let looped = elapsed.truncatingRemainder(dividingBy: totalDuration)

        var accumulated: TimeInterval = 0
        for i in 0..<durations.count {
            accumulated += durations[i]
            if looped <= accumulated {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                imageLayer?.contents = frames[i]
                CATransaction.commit()
                break
            }
        }
    }

    deinit {
        stopDisplayLink()
    }
}
