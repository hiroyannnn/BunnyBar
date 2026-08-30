# BunnyBar

BunnyBar is a tiny macOS menu-bar companion: an original lop-ear rabbit makes
short, physical hops along the top edge of every connected display. Its tempo
softly reflects current CPU load, while rest and exploration remain independent
of external load spikes.

## Features

- CPU-aware rabbit animation (0.90×–1.15×) with a lightweight 1.5-second sampler
- Six-pose monochrome lop-ear half-bound based on real indoor rabbit locomotion
- CPU, motion state, speed, and memory information in the menu-bar menu
- Transparent, click-through overlay that does not steal focus
- Short two-to-four-hop exploration bouts with quiet rest and edge-aware turns
- One overlay per display; overlays are rebuilt when displays change and follow all Spaces/fullscreen
- Show/Hide and Quit controls from the monochrome rabbit status item
- Optional **Launch at Login** setting from the status-item menu (managed by macOS Login Items)
- Single-instance protection so Debug/Release copies cannot create duplicate rabbits
- No external frameworks or runtime services
- Native macOS app icon based on the same monochrome lop-ear silhouette
- Supports macOS 13 Ventura and later

## Install

1. Download `BunnyBar-0.1.0.zip` from the [latest GitHub Release](https://github.com/hiroyannnn/BunnyBar/releases/latest).
2. Expand the ZIP and move `BunnyBar.app` to `/Applications`.
3. Open BunnyBar. It runs as a menu-bar app and does not create a Dock icon.
4. Optionally enable **Launch at Login** from the rabbit menu.

Public release archives are universal (Apple silicon and Intel), signed with a
Developer ID certificate, notarized by Apple, and include a stapled notarization
ticket. The Release page also provides a SHA-256 checksum.

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

Run `Scripts/verify.sh` for the Debug build and both deterministic native checks.
The verification also renders all six production hop poses at the real 88×44
overlay size and rejects unexpected apparent-size changes.
Regenerate the complete AppIcon asset from the adopted silhouette with
`swift -module-cache-path /private/tmp/BunnyBarIconModuleCache Scripts/generate-app-icon.swift`.
The menu-bar symbol is a separate 22x18pt asset; regenerate it with
`swift -module-cache-path /private/tmp/BunnyBarStatusIconModuleCache Scripts/generate-status-icon.swift`.

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

Click the rabbit status item to see live CPU and memory values. **Hide Bunny**
pauses and removes all overlays; **Show Bunny** restores them. **Quit BunnyBar**
terminates the app. The overlay is intentionally click-through, so regular
menu-bar and application interactions remain unaffected. To start BunnyBar
automatically, enable **Launch at Login** in the menu; if macOS requires
approval, the item opens **System Settings → General → Login Items**.

## Release

To create an unsigned Release candidate for local testing, run
`Scripts/build-unsigned-rc.sh 0.1.0`. Do not publish that archive. A public
release must be signed with Developer ID, notarized, and stapled; the complete
credential-gated flow is implemented by `Scripts/release.sh`. See
[`docs/release.md`](docs/release.md) for the final checklist. A Debug build is
not a distributable signed release.

The observed movement model and the timing contract used by the production
animation are documented in
[`docs/indoor-lop-motion-study.md`](docs/indoor-lop-motion-study.md).

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
