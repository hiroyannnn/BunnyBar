#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$ROOT_DIR/build/app-store-$VERSION/BunnyBar.xcarchive"
EXPORT_OPTIONS="$ROOT_DIR/Scripts/AppStoreExportOptions.plist"

if [[ "${BUNNYBAR_CONFIRM_UPLOAD:-}" != "1" ]]; then
  echo "Upload is gated. Set BUNNYBAR_CONFIRM_UPLOAD=1 after explicit approval." >&2
  exit 1
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates
