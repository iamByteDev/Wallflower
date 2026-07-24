import AppKit
import WebKit

final class WebWallpaperView: WKWebView, WallpaperViewProtocol {

    private var _currentURL: URL?
    private var _isPlaying: Bool = false
    private var _hasAudio: Bool = false
    private var _volume: Float = 1.0

    var isPlaying: Bool { _isPlaying }
    var hasAudio: Bool { _hasAudio }
    var currentURL: URL? { _currentURL }

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = []

        super.init(frame: frame, configuration: config)

        autoresizingMask = [.width, .height]
        wantsLayer = true

        uiDelegate = self
        navigationDelegate = self

        setValue(false, forKey: "drawsBackground")
        enclosingScrollView?.drawsBackground = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func load(contentsOf url: URL) {
        _currentURL = url
        _isPlaying = true

        if url.pathExtension == "html" || url.pathExtension == "htm" {
            let dir = url.deletingLastPathComponent()
            loadFileURL(url, allowingReadAccessTo: dir)
        } else if url.lastPathComponent == "index.html" {
            let dir = url.deletingLastPathComponent()
            loadFileURL(url, allowingReadAccessTo: dir)
        } else if FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path) {
            let indexURL = url.appendingPathComponent("index.html")
            _currentURL = indexURL
            loadFileURL(indexURL, allowingReadAccessTo: url)
        } else {
            loadFileURL(url, allowingReadAccessTo: url)
        }
    }

    func play() {
        _isPlaying = true
        evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.play())", completionHandler: nil)
        evaluateJavaScript("document.querySelectorAll('audio').forEach(a => a.play())", completionHandler: nil)
    }

    func pause() {
        _isPlaying = false
        evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())", completionHandler: nil)
        evaluateJavaScript("document.querySelectorAll('audio').forEach(a => a.pause())", completionHandler: nil)
    }

    func stop() {
        _isPlaying = false
        evaluateJavaScript("document.querySelectorAll('video').forEach(v => { v.pause(); v.currentTime = 0 })", completionHandler: nil)
    }

    func setVolume(_ volume: Float) {
        _volume = volume
        evaluateJavaScript(
            "document.querySelectorAll('video, audio').forEach(e => e.volume = \(volume))",
            completionHandler: nil
        )
    }

    func setPlaybackRate(_ rate: Float) {
        evaluateJavaScript(
            "document.querySelectorAll('video').forEach(v => v.playbackRate = \(rate))",
            completionHandler: nil
        )
    }
}

extension WebWallpaperView: WKUIDelegate {
    func webViewDidClose(_ webView: WKWebView) {}
}

extension WebWallpaperView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        evaluateJavaScript(
            """
            document.querySelectorAll('video').forEach(v => { v.loop = true; v.muted = false });
            document.querySelectorAll('audio').forEach(a => { a.loop = true; a.muted = false });
            """,
            completionHandler: nil
        )
    }
}
