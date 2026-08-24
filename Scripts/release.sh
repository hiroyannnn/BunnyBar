#!/usr/bin/env bash
set -euo pipefail

APP="BunnyBar"
VERSION="${1:-0.1.0}"
ZIP="${APP}-${VERSION}.zip"

# Create zip
ditto -c -k --sequesterRsrc --keepParent "./build/${APP}.app" "${ZIP}"

echo "ZIP created: ${ZIP}"
echo "SHA256: $(shasum -a 256 "${ZIP}")"
