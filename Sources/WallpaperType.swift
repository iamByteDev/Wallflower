import AppKit
import AVFoundation

protocol WallpaperViewProtocol: AnyObject {
    func load(contentsOf url: URL)
    func play()
    func pause()
    func stop()
    func setVolume(_ volume: Float)
    func setPlaybackRate(_ rate: Float)
    var isPlaying: Bool { get }
    var hasAudio: Bool { get }
    var currentURL: URL? { get }
}

enum WallpaperType {
    case video
    case web
    case image
    case gif

    static func detect(from url: URL) -> WallpaperType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "m4v", "mkv", "webm", "avi":
            return .video
        case "html", "htm":
            return .web
        case "gif":
            return .gif
        case "png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp":
            return .image
        default:
            if url.lastPathComponent == "index.html" || url.lastPathComponent == "project.json" {
                return .web
            }
            return .video
        }
    }

    func createView(frame: NSRect) -> (NSView & WallpaperViewProtocol) {
        switch self {
        case .video: return VideoWallpaperView(frame: frame)
        case .web:   return WebWallpaperView(frame: frame)
        case .image: return ImageWallpaperView(frame: frame)
        case .gif:   return GifWallpaperView(frame: frame)
        }
    }
}
