import AppKit
import AVFoundation
import ExtensionFoundation

@objc protocol WallflowerAgentXPCProtocol {
    func acquireWithId(_ id: Any?, request: Any?, reply: @escaping (Any?, Error?) -> Void)
    func handleNotificationWithNamed(_ name: String, reply: @escaping (Any?, Error?) -> Void)
    func handleDebugRequestFor(_ request: Any?, reply: @escaping (Any?, Error?) -> Void)
}

final class WallflowerXPCHandler: NSObject, WallflowerAgentXPCProtocol {

    private var players: [String: AVPlayer] = [:]
    private var playerLayers: [String: AVPlayerLayer] = [:]
    private var displayLayers: [String: CALayer] = [:]

    func acquireWithId(_ id: Any?, request: Any?, reply: @escaping (Any?, Error?) -> Void) {
        guard let wallpaperURL = savedWallpaperURL() else {
            reply(nil, nil)
            return
        }

        let displayID = extractDisplayID(from: id)
        let idStr = displayID ?? "default"

        switch detectType(from: wallpaperURL) {
        case "video":
            handleVideoAcquire(displayID: idStr, url: wallpaperURL, reply: reply)
        case "image":
            handleImageAcquire(displayID: idStr, url: wallpaperURL, reply: reply)
        default:
            reply(nil, nil)
        }
    }

    func handleNotificationWithNamed(_ name: String, reply: @escaping (Any?, Error?) -> Void) {
        switch name {
        case "pause":
            players.values.forEach { $0.pause() }
        case "resume", "play":
            players.values.forEach { $0.play() }
        default:
            break
        }
        reply(nil, nil)
    }

    func handleDebugRequestFor(_ request: Any?, reply: @escaping (Any?, Error?) -> Void) {
        reply(["status": "active", "wallpapers": players.count] as Any, nil)
    }

    private func handleVideoAcquire(displayID: String, url: URL, reply: @escaping (Any?, Error?) -> Void) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.volume = Float(UserDefaults.standard.double(forKey: "volume"))

        players[displayID] = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayers[displayID] = playerLayer

        let displayLayer = CALayer()
        displayLayer.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        displayLayer.addSublayer(playerLayer)
        playerLayer.frame = displayLayer.bounds
        displayLayers[displayID] = displayLayer

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.players[displayID]?.seek(to: .zero)
            self?.players[displayID]?.play()
        }

        player.play()

        let response: [String: Any] = [
            "displayLayer": displayLayer,
            "choice": [
                "videoID": url.lastPathComponent,
                "displayID": displayID,
            ],
            "type": "video",
        ]
        reply(response, nil)
    }

    private func handleImageAcquire(displayID: String, url: URL, reply: @escaping (Any?, Error?) -> Void) {
        guard let image = NSImage(contentsOf: url) else {
            reply(nil, nil)
            return
        }

        let displayLayer = CALayer()
        displayLayer.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        displayLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        displayLayer.contentsGravity = .resizeAspectFill
        displayLayers[displayID] = displayLayer

        let response: [String: Any] = [
            "displayLayer": displayLayer,
            "choice": [
                "displayID": displayID,
            ],
            "type": "image",
        ]
        reply(response, nil)
    }

    private func savedWallpaperURL() -> URL? {
        let defaults = UserDefaults.standard
        guard let paths = defaults.stringArray(forKey: "wallflowerWallpapers"),
              !paths.isEmpty else { return nil }

        let idx = defaults.integer(forKey: "wallflowerCurrentIndex")
        let clamped = min(max(idx, 0), paths.count - 1)

        guard clamped < paths.count else { return nil }

        let path = paths[clamped]
        let url = URL(fileURLWithPath: path)

        if FileManager.default.fileExists(atPath: path) {
            return url
        }

        for p in paths where FileManager.default.fileExists(atPath: p) {
            return URL(fileURLWithPath: p)
        }

        return nil
    }

    private func detectType(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "m4v", "mkv", "webm", "avi": return "video"
        case "png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp": return "image"
        case "html", "htm": return "web"
        default: return "video"
        }
    }

    private func extractDisplayID(from id: Any?) -> String? {
        if let dict = id as? [String: Any], let dID = dict["displayID"] as? String {
            return dID
        }
        if let str = id as? String { return str }
        return nil
    }
}

final class WallflowerExtensionConfiguration: AppExtensionConfiguration {

    private var handler: WallflowerXPCHandler?

    nonisolated func accept(connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: WallflowerAgentXPCProtocol.self)
        connection.exportedObject = WallflowerXPCHandler()
        connection.resume()
        return true
    }
}

@main
final class WallflowerWallpaperExtension: AppExtension {

    let configuration = WallflowerExtensionConfiguration()

    required init() {}
}
