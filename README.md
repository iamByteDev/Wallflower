# Wallflower

Native macOS wallpaper engine — animated wallpapers for your desktop.

Supports video, HTML/Web, GIF, and static image wallpapers across multiple monitors.

## Features

- **Video wallpapers** — MP4, MOV, MKV, WebM with audio and seamless looping
- **Web wallpapers** — HTML/CSS/JS wallpapers via WKWebView (supports `index.html`)
- **GIF wallpapers** — frame-accurate animation via ImageIO + CVDisplayLink
- **Static images** — PNG, JPG, HEIC, TIFF, BMP, WebP
- **Multi-monitor** — auto-detects connect, disconnect, and resolution changes
- **Persistence** — remembers your wallpaper across restarts
- **Sleep/wake** — pauses on sleep, resumes on wake
- **Volume control** — per-wallpaper audio, adjustable in Settings
- **Playback speed** — 0.25x to 4x

## Requirements

- macOS 11 (Big Sur) or later
- Apple Silicon or Intel

## Build

```bash
make        # release build
make debug  # debug build
make run    # build and launch
```

Regenerate the app icon from `icon.png`:

```bash
make icon && make
```

## Lock Screen

Wallflower includes a companion screen saver that shows your wallpaper on the lock screen.

```bash
cd ScreenSaver && make install
```

Then go to **System Settings > Screen Saver** and select **Wallflower**. Set it to show on lock screen. The screen saver reads the same wallpaper you set in the desktop app.

## Controls

| Action | Shortcut |
|---|---|
| Pause / Play | Space |
| Next wallpaper | Cmd+Shift+N |
| Previous wallpaper | Cmd+Shift+P |
| Open wallpaper | Cmd+O |
| Settings | Cmd+, |
| Quit | Cmd+Q |

## How it works

Wallflower creates borderless desktop-level windows between the Finder wallpaper and desktop icons. Each monitor gets its own window. The window ignores mouse events so clicks pass through to your desktop icons.

Video wallpapers use AVPlayer with AVPlayerLayer. Web wallpapers use WKWebView with auto-playing video/audio elements. GIFs are decoded frame-by-frame using ImageIO and synced to the display refresh rate.

## License

MIT
