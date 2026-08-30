# BunnyBar

BunnyBar is a tiny macOS menu-bar companion: an original lop-ear rabbit makes
short, physical hops along the top edge of every connected display. Its tempo
softly reflects current CPU load, while rest and exploration remain independent
of external load spikes.

## Features

- CPU-aware rabbit animation (0.90×–1.15×) with a lightweight 1.5-second sampler
- Four-phase monochrome lop-ear hop using the accepted still-state texture with only subtle position and squash transforms
- CPU, motion state, speed, and memory information in the menu-bar menu
- Transparent, click-through overlay that does not steal focus
- Short one-to-three-hop exploration bouts with quiet rest and edge-aware turns
- One overlay per display; overlays are rebuilt when displays change and follow all Spaces/fullscreen
- Show/Hide and Quit controls from the 🐰 status item
- Optional **Launch at Login** setting from the status-item menu (managed by macOS Login Items)
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

For the deterministic offscreen behavior check, run from the repository root
on a logged-in Mac:

```sh
xcrun swiftc -warnings-as-errors \
  -module-cache-path /private/tmp/BunnyBarRuntimeCheckModuleCache \
  -framework AppKit -framework Metal -framework SpriteKit \
  BunnyBar/Sources/BunnyBar/App/SystemMetrics.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitNode.swift \
  BunnyBar/Sources/BunnyBar/Scenes/RabbitScene.swift \
  BunnyBar/Tests/RabbitBehaviorRuntimeCheck.swift \
  -o /private/tmp/BunnyBarBehaviorRuntimeCheck && \
  /private/tmp/BunnyBarBehaviorRuntimeCheck
```

## Use

Click the 🐰 status item to see live CPU and memory values. **Hide Bunny**
pauses and removes all overlays; **Show Bunny** restores them. **Quit BunnyBar**
terminates the app. The overlay is intentionally click-through, so regular
menu-bar and application interactions remain unaffected. To start BunnyBar
automatically, enable **Launch at Login** in the menu; if macOS requires
approval, the item opens **System Settings → General → Login Items**.

## Release

For a local archive, use Xcode's Archive action or the scripts in `Scripts/`
after configuring signing. `Scripts/release.sh` and `Scripts/notarize.sh` are
templates and may require an Apple Developer team, certificate, and notarization
credentials. A Debug build is not a distributable signed release.

## Inspiration and license

BunnyBar's concept is inspired by [RunDog](https://github.com/tsuyoshi-otake/run-dog)
and [RunCat Neo](https://github.com/runcat-dev/RunCatNeo). Their names, code, and
artwork are not bundled here; BunnyBar uses its own monochrome rabbit visuals
and MIT licensed source.

## Troubleshooting

- If macOS blocks an unsigned build, open **System Settings → Privacy & Security**
  and allow the app, or run a signed/notarized release.
- If overlays are missing, use the status item to toggle them, then reconnect
  the display or relaunch. The app requires a normal logged-in macOS GUI
  session.

## License

MIT License. See [LICENSE](LICENSE).
