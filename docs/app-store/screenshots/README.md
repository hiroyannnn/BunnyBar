# App Store screenshots

These screenshots are generated at the Apple-supported macOS size of 1440 x 900 pixels. They use BunnyBar's production rabbit and status-item assets with restrained explanatory overlays.

- `ja/`: Japanese localization
- `en/`: English localization

Regenerate from the repository root:

```sh
swift -module-cache-path /private/tmp/BunnyBarStoreScreenshotModuleCache \
  Scripts/generate-app-store-screenshots.swift
```

Visually inspect every generated file before uploading it to App Store Connect.
