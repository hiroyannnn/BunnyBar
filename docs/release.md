# Release checklist

This project is a macOS accessory app. A distributable release must be signed
with Developer ID and notarized; a Debug build is suitable only for local use.

## 1. Archive

From the repository root, set a real signing team in Xcode first, then run:

```sh
mkdir -p build
xcodebuild archive \
  -project BunnyBar/BunnyBar.xcodeproj \
  -scheme BunnyBar \
  -configuration Release \
  -archivePath build/BunnyBar.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=TEAMID
```

Replace `TEAMID` with the Apple Developer Team ID and configure the matching
Developer ID Application certificate/profile in the project or command line.

## 2. Export

Create an `ExportOptions.plist` for the selected team (the exact signing
settings are account-specific), then export the archive:

```sh
xcodebuild -exportArchive \
  -archivePath build/BunnyBar.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Confirm the exported app is at `build/export/BunnyBar.app` and inspect its
signature:

```sh
codesign --verify --deep --strict --verbose=2 build/export/BunnyBar.app
spctl --assess --type execute --verbose=2 build/export/BunnyBar.app
```

## 3. Zip and checksum

```sh
ditto -c -k --sequesterRsrc --keepParent \
  build/export/BunnyBar.app build/BunnyBar-0.1.0.zip
shasum -a 256 build/BunnyBar-0.1.0.zip
```

The helper `Scripts/release.sh` creates the same style of archive when the
signed app has been copied to `build/BunnyBar.app`.

## 4. Notarize and staple

Store notarization credentials in a keychain profile, then submit the zip:

```sh
Scripts/notarize.sh build/BunnyBar-0.1.0.zip AC_PASSWORD
xcrun stapler staple build/export/BunnyBar.app
xcrun stapler validate build/export/BunnyBar.app
```

`AC_PASSWORD` is a placeholder profile name, not a password. Never commit
Apple IDs, app-specific passwords, API keys, or certificates to this repo.

## 5. Publish

Upload the notarized zip and its SHA-256 to the release page, and update the
Homebrew **Cask** template in `docs/homebrew_formula_template.rb` with the final
version and checksum. The path retains its historical name, but the file's DSL
is intentionally `cask`, because BunnyBar is distributed as an `.app` bundle.
GitHub tagging, publication, and Homebrew submission are deliberate release
gates and are not performed by the local build scripts.
