# BunnyBar

BunnyBar is a tiny macOS menu-bar companion: an original vector rabbit runs
along the top edge of every connected display. Its animation speed reflects the
current CPU load, so the rabbit stays calm while the Mac is idle and zooms when
work picks up.

## Features

- CPU-aware rabbit animation (0.75×–1.65×) with a lightweight 1.5-second sampler
- Four-frame monochrome lop-ear silhouette cycle drawn with Core Graphics paths
- CPU, motion state, speed, and memory information in the menu-bar menu
- Transparent, click-through overlay that does not steal focus
- One overlay per display; overlays are rebuilt when displays change and follow all Spaces/fullscreen
- Show/Hide and Quit controls from the 🐰 status item
- No external frameworks or runtime services

## Build and run

The canonical Xcode project is [`BunnyBar/BunnyBar.xcodeproj`](BunnyBar/BunnyBar.xcodeproj).
The project explicitly builds sources under `BunnyBar/Sources/BunnyBar`; the
older top-level `Sources/BunnyBar` tree is retained as historical material and
is not part of the target.

```sh
xcodebuild -project BunnyBar/BunnyBar.xcodeproj \
  -scheme BunnyBar -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/BunnyBar.app
```

Or open the project in Xcode, select the `BunnyBar` scheme, and press Run. The
app is an accessory/menu-bar app, so it does not open a normal Dock window.

## Use

Click the 🐰 status item to see live CPU and memory values. **Hide Bunny**
pauses and removes all overlays; **Show Bunny** restores them. **Quit BunnyBar**
terminates the app. The overlay is intentionally click-through, so regular
menu-bar and application interactions remain unaffected.

## Release

For a local archive, use Xcode's Archive action or the scripts in `Scripts/`
after configuring signing. `Scripts/release.sh` and `Scripts/notarize.sh` are
templates and may require an Apple Developer team, certificate, and notarization
credentials. A Debug build is not a distributable signed release.

## Inspiration and license

BunnyBar's concept is inspired by [RunDog](https://github.com/tsuyoshi-otake/run-dog)
and [RunCat Neo](https://github.com/runcat-dev/RunCatNeo). Their names, code, and
artwork are not bundled here; BunnyBar uses its own vector rabbit and MIT
licensed source.

## Troubleshooting

- If macOS blocks an unsigned build, open **System Settings → Privacy & Security**
  and allow the app, or run a signed/notarized release.
- If overlays are missing, use the status item to toggle them, then reconnect
  the display or relaunch. The app requires a normal logged-in macOS GUI
  session.

## License

MIT License. See [LICENSE](LICENSE).
