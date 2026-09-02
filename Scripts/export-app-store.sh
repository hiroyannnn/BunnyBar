#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$ROOT_DIR/build/app-store-$VERSION/BunnyBar.xcarchive"
EXPORT_PATH="$ROOT_DIR/build/app-store-$VERSION/export"
EXPORT_OPTIONS="$ROOT_DIR/Scripts/AppStoreLocalExportOptions.plist"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

rm -rf "$EXPORT_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "Local App Store export is ready:"
echo "$EXPORT_PATH"
