#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BunnyBar"
VERSION="${1:-0.1.0}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Invalid release version: ${VERSION}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${ROOT_DIR}/BunnyBar/BunnyBar.xcodeproj"
DERIVED_DATA="${ROOT_DIR}/build/DerivedData-Release"
SOURCE_APP="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
OUTPUT_DIR="${ROOT_DIR}/build/unsigned-rc-${VERSION}"
OUTPUT_APP="${OUTPUT_DIR}/${APP_NAME}.app"
OUTPUT_ZIP="${OUTPUT_DIR}/${APP_NAME}-${VERSION}-unsigned-rc.zip"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

mkdir -p "${OUTPUT_DIR}"
rm -rf "${OUTPUT_APP}"
rm -f "${OUTPUT_ZIP}" "${OUTPUT_ZIP}.sha256"
ditto "${SOURCE_APP}" "${OUTPUT_APP}"

BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${OUTPUT_APP}/Contents/Info.plist")"
if [[ "${BUNDLE_VERSION}" != "${VERSION}" ]]; then
  echo "Bundle version ${BUNDLE_VERSION} does not match requested version ${VERSION}." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${OUTPUT_APP}"
ARCHITECTURES="$(lipo -archs "${OUTPUT_APP}/Contents/MacOS/${APP_NAME}")"
for REQUIRED_ARCH in arm64 x86_64; do
  if [[ " ${ARCHITECTURES} " != *" ${REQUIRED_ARCH} "* ]]; then
    echo "Release candidate is missing ${REQUIRED_ARCH}: ${ARCHITECTURES}" >&2
    exit 1
  fi
done
ditto -c -k --sequesterRsrc --keepParent "${OUTPUT_APP}" "${OUTPUT_ZIP}"
shasum -a 256 "${OUTPUT_ZIP}" > "${OUTPUT_ZIP}.sha256"

echo "Unsigned local-test candidate created (do not publish this archive):"
echo "  ${OUTPUT_ZIP}"
echo "  Architectures: ${ARCHITECTURES}"
