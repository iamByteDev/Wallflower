import AppKit
import AVFoundation

final class VideoWallpaperView: NSView, WallpaperViewProtocol {

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var _currentURL: URL?
    private var _hasAudio: Bool = true
    private var _isPlaying: Bool = false
    private var playbackObserver: NSKeyValueObservation?

    var isPlaying: Bool { _isPlaying }

    var hasAudio: Bool { _hasAudio }

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
        playerLayer?.frame = bounds
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        playerLayer?.frame = bounds
    }

    func load(contentsOf url: URL) {
        _currentURL = url
        _isPlaying = false

        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playbackObserver?.invalidate()
        playbackObserver = nil

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        player = newPlayer

        playerLayer = AVPlayerLayer(player: newPlayer)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = bounds

        if let layer = playerLayer {
            self.layer?.addSublayer(layer)
            layer.zPosition = 0
        }

        _hasAudio = asset.tracks(withMediaType: .audio).count > 0
        setupLooping(for: playerItem)

        configurePlayerItem(playerItem, url: url)
        play()
    }

    func play() {
        _isPlaying = true
        guard let p = player, p.currentItem?.status == .readyToPlay else {
            return
        }
        p.play()
    }

    func pause() {
        _isPlaying = false
        player?.pause()
    }

    func stop() {
        _isPlaying = false
        player?.pause()
        player?.seek(to: .zero)
    }

    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    func setPlaybackRate(_ rate: Float) {
        player?.rate = rate
    }

    private func setupLooping(for item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerItemDidEnd(_ notification: Notification) {
        guard let player = player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished, self._isPlaying else { return }
            self.player?.play()
        }
    }

    private func configurePlayerItem(_ item: AVPlayerItem, url: URL) {
        playbackObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                if self?._isPlaying == true {
                    self?.player?.play()
                }
            case .failed:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.reloadCurrent()
                }
            default:
                break
            }
        }
    }

    private func reloadCurrent() {
        guard let url = _currentURL else { return }
        load(contentsOf: url)
    }

    deinit {
        playbackObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        playerLayer?.removeFromSuperlayer()
    }
}
