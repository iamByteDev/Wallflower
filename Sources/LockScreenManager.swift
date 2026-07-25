import AppKit
import AVFoundation
import Security
import Foundation

/// Manages the macOS lock screen wallpaper through multiple approaches.
///
/// ## macOS Lock Screen Architecture
///
/// On modern macOS (Ventura+), the lock screen wallpaper is determined by:
/// 1. **Screen Saver** — If a screen saver is active, it displays on the lock screen.
///    This is the most reliable approach for animated/video wallpapers.
/// 2. **Desktop Wallpaper** — On some configurations, `setDesktopImageURL` cascades
///    to the lock screen. On newer macOS (Sonoma+), these can be set independently.
/// 3. **Lock Screen Cache** — A static image cached at
///    `/Library/Caches/Desktop Pictures/{userUUID}/lockscreen.png`.
///    Writing here requires root privileges.
///
/// ## Permissions
///
/// | Approach | Permissions Needed |
/// |---|---|
/// | `setDesktopImageURL` | None (sandbox-safe) |
/// | Screen Saver activation | None (writes to user defaults) |
/// | Lock screen cache write | Root (requires AuthorizationRef) |
/// | Open System Settings | None |
final class LockScreenManager {

    private static let saverBundleID = "com.wallflower.screensaver"
    private static let saverName = "Wallflower"

    // MARK: - Approach 1: Desktop Wallpaper (sandbox-safe)

    /// Sets the desktop wallpaper via NSWorkspace. On macOS versions where the
    /// lock screen inherits the desktop wallpaper, this also updates the lock screen.
    ///
    /// - Parameter imageURL: File URL to an image file (png, jpg, heic, etc.)
    /// - Returns: `true` if the operation succeeded.
    @discardableResult
    static func setDesktopWallpaper(imageURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return false
        }

        do {
            try NSWorkspace.shared.setDesktopImageURL(
                imageURL,
                for: NSScreen.main ?? NSScreen.screens.first!,
                options: [:]
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Approach 2: Screen Saver Activation (sandbox-safe, recommended)

    /// Activates the Wallflower screen saver so it plays on the lock screen.
    /// This writes to `com.apple.screensaver` user defaults and notifies
    /// the screen saver engine.
    ///
    /// The .saver bundle must already be installed at
    /// `~/Library/Screen Savers/Wallflower.saver`.
    ///
    /// - Returns: `true` if the saver bundle was found and activation attempted.
    @discardableResult
    static func activateScreenSaver() -> Bool {
        let saverPath = NSHomeDirectory()
            + "/Library/Screen Savers/\(saverName).saver"

        guard FileManager.default.fileExists(atPath: saverPath) else {
            return false
        }

        let defaults = UserDefaults(suiteName: "com.apple.screensaver")
        defaults?.set(saverName, forKey: "moduleName")
        defaults?.set(saverPath, forKey: "modulePath")
        defaults?.set(0, forKey: "tokenRemovalAction")
        defaults?.synchronize()

        DistributedNotificationCenter.default()
            .postNotificationName(
                NSNotification.Name("com.apple.screensaver.willShow"),
                object: nil,
                deliverImmediately: true
            )

        return true
    }

    /// Returns `true` if the Wallflower screen saver is currently selected
    /// as the active screen saver in user defaults.
    static var isScreenSaverActive: Bool {
        let defaults = UserDefaults(suiteName: "com.apple.screensaver")
        return defaults?.string(forKey: "moduleName") == saverName
    }

    // MARK: - Approach 3: Lock Screen Cache (requires root)

    /// Writes an image directly to the lock screen cache at
    /// `/Library/Caches/Desktop Pictures/{userUUID}/lockscreen.png`.
    ///
    /// **Requires root privileges.** Use `promptForPrivileges()` to obtain
    /// an `AuthorizationRef`, then pass it here.
    ///
    /// - Parameters:
    ///   - imageURL: File URL to an image file.
    ///   - auth: An `AuthorizationRef` obtained via `promptForPrivileges()`.
    /// - Returns: `true` if the write succeeded.
    @discardableResult
    static func writeLockScreenCache(
        imageURL: URL,
        authorization auth: AuthorizationRef
    ) -> Bool {
        guard let userUUID = currentUserUUID() else { return false }
        guard let imageData = try? Data(contentsOf: imageURL) else { return false }

        let cacheDir = "/Library/Caches/Desktop Pictures/\(userUUID)"
        let cacheFile = "\(cacheDir)/lockscreen.png"

        let createDir = """
            mkdir -p "\(cacheDir)" && \
            chown "$(stat -f '%Su' /dev/console):_securityagent" "\(cacheDir)" && \
            chmod 750 "\(cacheDir)"
            """

        let writeFile = """
            cat > "\(cacheFile)" && \
            chown "$(stat -f '%Su' /dev/console):_securityagent" "\(cacheFile)" && \
            chmod 640 "\(cacheFile)"
            """

        return executePrivileged(createDir, auth: auth)
            && executePrivilegedWithInput(writeFile, input: imageData, auth: auth)
    }

    /// Extracts a frame from a video URL and writes it to the lock screen cache.
    /// This is a static snapshot — the lock screen won't animate, but at least
    /// shows the wallpaper content.
    ///
    /// - Parameters:
    ///   - videoURL: File URL to a video file.
    ///   - auth: An `AuthorizationRef`.
    /// - Returns: `true` if the write succeeded.
    @discardableResult
    static func writeVideoSnapshotToLockScreen(
        videoURL: URL,
        authorization auth: AuthorizationRef
    ) -> Bool {
        guard let userUUID = currentUserUUID() else { return false }

        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 3840, height: 2160)

        var actualTime = CMTime.zero
        guard let cgImage = try? generator.copyCGImage(
            at: asset.duration.seconds > 1 ? CMTime(seconds: 1, preferredTimescale: 600)
                 : .zero,
            actualTime: &actualTime
        ) else { return false }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)
        guard let pngData = rep.representation(
            using: .png,
            properties: [:]
        ) else { return false }

        let cacheDir = "/Library/Caches/Desktop Pictures/\(userUUID)"
        let cacheFile = "\(cacheDir)/lockscreen.png"

        let createDir = """
            mkdir -p "\(cacheDir)" && \
            chown "$(stat -f '%Su' /dev/console):_securityagent" "\(cacheDir)" && \
            chmod 750 "\(cacheDir)"
            """

        let writeFile = """
            cat > "\(cacheFile)" && \
            chown "$(stat -f '%Su' /dev/console):_securityagent" "\(cacheFile)" && \
            chmod 640 "\(cacheFile)"
            """

        return executePrivileged(createDir, auth: auth)
            && executePrivilegedWithInput(writeFile, input: pngData, auth: auth)
    }

    // MARK: - Approach 4: System Settings (user-guided)

    /// Opens System Settings to the Screen Saver pane so the user can
    /// manually select Wallflower.
    static func openScreenSaverPreferences() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension")!
        )
    }

    /// Opens System Settings to the Wallpaper pane.
    static func openWallpaperPreferences() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!
        )
    }

    // MARK: - Comprehensive Helper

    /// Best-effort attempt to set the lock screen wallpaper.
    /// Tries all available approaches in order of reliability.
    ///
    /// 1. Activate the Wallflower screen saver (works for all wallpaper types).
    /// 2. If the wallpaper is a static image, also call `setDesktopImageURL`
    ///    (sandbox-safe, may cascade to lock screen on some macOS versions).
    /// 3. If root privileges are requested and granted, write the lock screen cache.
    static func applyLockScreen(
        imageURL: URL? = nil,
        requestPrivileges: Bool = false
    ) {
        let saverInstalled = FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Library/Screen Savers/\(saverName).saver"
        )

        if saverInstalled && !isScreenSaverActive {
            activateScreenSaver()
        }

        guard let url = imageURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let isStaticImage = isImageFile(url)

        if isStaticImage {
            setDesktopWallpaper(imageURL: url)
        }

        if requestPrivileges,
           let auth = promptForPrivileges() {
            if isStaticImage {
                writeLockScreenCache(imageURL: url, authorization: auth)
            } else {
                writeVideoSnapshotToLockScreen(videoURL: url, authorization: auth)
            }
        }
    }

    private static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp"].contains(ext)
    }

    // MARK: - Privilege Escalation

    /// Prompts the user for administrator credentials and returns an
    /// `AuthorizationRef` that can execute privileged commands.
    ///
    /// - Parameter message: Explanation shown in the auth dialog.
    /// - Returns: An `AuthorizationRef`, or `nil` if the user cancelled or
    ///   authorization failed.
    static func promptForPrivileges(
        message: String = "Wallflower needs administrator access to update the lock screen wallpaper."
    ) -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(
            nil,
            nil,
            [],
            &authRef
        )

        guard status == errAuthorizationSuccess, let auth = authRef else {
            return nil
        }

        let flags: AuthorizationFlags = [
            .interactionAllowed,
            .extendRights,
            .preAuthorize,
        ]

        let authStatus = "system.privilege.admin".withCString { namePtr in
            var item = AuthorizationItem(
                name: namePtr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                return AuthorizationCopyRights(
                    auth,
                    &rights,
                    nil,
                    flags,
                    nil
                )
            }
        }

        guard authStatus == errAuthorizationSuccess else {
            return nil
        }

        return auth
    }

    // MARK: - Utilities

    /// Returns the current user's UUID as used by the lock screen cache.
    static func currentUserUUID() -> String? {
        guard let consoleUser = NSUserName() as String?,
              !consoleUser.isEmpty else { return nil }

        let cacheDir = "/Library/Caches/Desktop Pictures"
        guard let contents = try? FileManager.default
            .contentsOfDirectory(atPath: cacheDir) else { return nil }

        for uuid in contents {
            let path = "\(cacheDir)/\(uuid)"
            if let attrs = try? FileManager.default
                .attributesOfItem(atPath: path),
               let owner = attrs[.ownerAccountName] as? String,
               owner == consoleUser {
                return uuid
            }
        }

        return nil
    }

    /// Returns the path to the current user's lock screen cache directory.
    static var lockScreenCacheDirectory: String? {
        guard let uuid = currentUserUUID() else { return nil }
        return "/Library/Caches/Desktop Pictures/\(uuid)"
    }

    /// Returns the full path to the lock screen image file.
    static var lockScreenImagePath: String? {
        guard let dir = lockScreenCacheDirectory else { return nil }
        return "\(dir)/lockscreen.png"
    }

    // MARK: - Private Helpers

    private static func executePrivileged(
        _ command: String,
        auth: AuthorizationRef
    ) -> Bool {
        let script = "do shell script \"\(command)\" with administrator privileges"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
        return error == nil
    }

    private static func executePrivilegedWithInput(
        _ command: String,
        input: Data,
        auth: AuthorizationRef
    ) -> Bool {
        let tmpFile = "/tmp/wallflower_lockscreen_temp_\(UUID().uuidString)"
        guard FileManager.default.createFile(
            atPath: tmpFile,
            contents: input
        ) else { return false }

        let fullCommand = "cat \(tmpFile) | \(command); rm -f \(tmpFile)"
        let result = executePrivileged(fullCommand, auth: auth)
        try? FileManager.default.removeItem(atPath: tmpFile)
        return result
    }
}
