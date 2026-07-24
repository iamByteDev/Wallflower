import AppKit
import AVFoundation

final class VideoWallpaperView: NSView, WallpaperViewProtocol {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var looper: NSObject?
    private var _currentURL: URL?
    private var _hasAudio: Bool = true

    var isPlaying: Bool {
        player?.rate ?? 0 > 0
    }

    var hasAudio: Bool {
        _hasAudio
    }

    var currentURL: URL? {
        _currentURL
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        playerLayer?.frame = bounds
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        playerLayer?.frame = bounds
    }

    func load(contentsOf url: URL) {
        _currentURL = url

        player?.pause()
        playerLayer?.removeFromSuperlayer()
        looper = nil

        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds

        if let layer = playerLayer {
            self.layer?.addSublayer(layer)
            layer.zPosition = 0
        }

        _hasAudio = asset.tracks(withMediaType: .audio).count > 0
        setupLooping()

        if let window = window, !window.isVisible {
            return
        }
        play()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
    }

    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    func setPlaybackRate(_ rate: Float) {
        player?.rate = rate
    }

    private func setupLooping() {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            self?.player?.play()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
}
