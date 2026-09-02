#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
TEAM_ID="${DEVELOPMENT_TEAM:-386F82P767}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/BunnyBar/BunnyBar.xcodeproj"
BUILD_DIR="$ROOT_DIR/build/app-store-$VERSION"
ARCHIVE_PATH="$BUILD_DIR/BunnyBar.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/BunnyBar.app"

if [[ -z "$TEAM_ID" ]]; then
  echo "DEVELOPMENT_TEAM is required." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme BunnyBar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic

test -d "$APP_PATH"
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_VERSION" != "$VERSION" ]]; then
  echo "Expected version $VERSION but archived $ACTUAL_VERSION." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/BunnyBar")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "Archive is not universal: $ARCHS" >&2
  exit 1
fi

ENTITLEMENTS="$(codesign -d --entitlements - "$APP_PATH" 2>/dev/null)"
if [[ "$ENTITLEMENTS" != *"com.apple.security.app-sandbox"* ]]; then
  echo "App Sandbox entitlement is missing." >&2
  exit 1
fi
if [[ "$ENTITLEMENTS" == *"com.apple.security.get-task-allow"* ]]; then
  echo "Release archive unexpectedly permits debugger attachment." >&2
  exit 1
fi

echo "Mac App Store archive is ready:"
echo "$ARCHIVE_PATH"
