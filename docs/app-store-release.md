# Mac App Store release checklist

This flow is separate from the Developer ID and notarization flow in `docs/release.md`.

## 1. Local readiness

```sh
Scripts/verify.sh
plutil -lint BunnyBar/Sources/BunnyBar/Resources/Info.plist
plutil -lint BunnyBar/Sources/BunnyBar/Resources/PrivacyInfo.xcprivacy
```

Confirm that the release commit is clean and pushed. Store builds use version `1.0.0`, build `1`, bundle ID `com.hiroyannnn.BunnyBar`, and Apple Developer Team `386F82P767`.

## 2. Apple signing

In Xcode, sign in to the intended Apple Developer account and ensure the BunnyBar target resolves automatic signing for Team `386F82P767`.

```sh
security find-identity -v -p codesigning
Scripts/archive-app-store.sh 1.0.0
Scripts/export-app-store.sh 1.0.0
```

The archive script verifies the universal binary, App Sandbox entitlement, release version, and absence of the debug entitlement. The export script performs a local App Store Connect distribution export without uploading it.

## 3. App Store Connect

Create or verify the macOS app record before upload:

- Name: BunnyBar
- Bundle ID: `com.hiroyannnn.BunnyBar`
- SKU: `bunnybar-macos-1`
- Primary language: Japanese
- Price: Free

Use `docs/app-store-metadata.md` for the product page, privacy, age rating, export compliance, and review notes.

Upload the prepared 1440 x 900 PNG screenshots from:

- `docs/app-store/screenshots/ja/` for Japanese
- `docs/app-store/screenshots/en/` for English

Regenerate them from production rabbit assets with `Scripts/generate-app-store-screenshots.swift`.

## 4. Upload gate

Uploading creates an external build record in App Store Connect. After the archive passes local QA and upload is explicitly approved, run:

```sh
BUNNYBAR_CONFIRM_UPLOAD=1 Scripts/upload-app-store.sh 1.0.0
```

Wait for Apple processing to finish, then select the processed build on the `1.0.0` version page.

## 5. Submission gate

Before submitting to App Review, verify all localizations, screenshots, URLs, privacy answers, age rating, export compliance, pricing, availability, and App Review contact information. The final **Submit for Review** action requires action-time approval.
