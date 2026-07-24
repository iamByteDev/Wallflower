import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var engine: WallpaperEngine!
    private var menuBar: MenuBarManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = WallpaperEngine()
        menuBar = MenuBarManager(engine: engine)
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }
}
