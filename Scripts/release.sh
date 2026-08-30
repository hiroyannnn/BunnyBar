#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BunnyBar"
VERSION="${1:-0.1.0}"
TEAM_ID="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Developer Team ID}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Invalid release version: ${VERSION}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${ROOT_DIR}/BunnyBar/BunnyBar.xcodeproj"
BUILD_DIR="${ROOT_DIR}/build/release-${VERSION}"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_OPTIONS="${BUILD_DIR}/ExportOptions.plist"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
NOTARY_ZIP="${BUILD_DIR}/${APP_NAME}-${VERSION}-notarization.zip"
RELEASE_ZIP="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
CHECKSUM_FILE="${RELEASE_ZIP}.sha256"

if ! security find-identity -v -p codesigning | grep -q 'Developer ID Application'; then
  echo "No valid Developer ID Application identity was found in the keychain." >&2
  exit 1
fi

mkdir -p "${BUILD_DIR}"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"
rm -f "${EXPORT_OPTIONS}" "${NOTARY_ZIP}" "${RELEASE_ZIP}" "${CHECKSUM_FILE}"
plutil -create xml1 "${EXPORT_OPTIONS}"
plutil -insert method -string developer-id "${EXPORT_OPTIONS}"
plutil -insert signingStyle -string automatic "${EXPORT_OPTIONS}"
plutil -insert teamID -string "${TEAM_ID}" "${EXPORT_OPTIONS}"
plutil -insert destination -string export "${EXPORT_OPTIONS}"

xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=macOS' \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  CODE_SIGN_STYLE=Automatic \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  -allowProvisioningUpdates

BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Contents/Info.plist")"
if [[ "${BUNDLE_VERSION}" != "${VERSION}" ]]; then
  echo "Bundle version ${BUNDLE_VERSION} does not match requested version ${VERSION}." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
ARCHITECTURES="$(lipo -archs "${APP_PATH}/Contents/MacOS/${APP_NAME}")"
for REQUIRED_ARCH in arm64 x86_64; do
  if [[ " ${ARCHITECTURES} " != *" ${REQUIRED_ARCH} "* ]]; then
    echo "Exported app is missing ${REQUIRED_ARCH}: ${ARCHITECTURES}" >&2
    exit 1
  fi
done

ENTITLEMENTS="$(codesign -d --entitlements - "${APP_PATH}" 2>/dev/null)"
if [[ "${ENTITLEMENTS}" != *"com.apple.security.app-sandbox"* ]]; then
  echo "Exported app is missing the App Sandbox entitlement." >&2
  exit 1
fi
if [[ "${ENTITLEMENTS}" == *"com.apple.security.get-task-allow"* ]]; then
  echo "Exported app unexpectedly allows debugger attachment." >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${NOTARY_ZIP}"
"${SCRIPT_DIR}/notarize.sh" "${NOTARY_ZIP}" "${NOTARY_KEYCHAIN_PROFILE}"
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"

# Package again after stapling so the distributed app contains the ticket.
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${RELEASE_ZIP}"
CHECKSUM="$(shasum -a 256 "${RELEASE_ZIP}" | awk '{print $1}')"
printf '%s  %s\n' "${CHECKSUM}" "$(basename "${RELEASE_ZIP}")" > "${CHECKSUM_FILE}"
spctl --assess --type execute --verbose=2 "${APP_PATH}"

echo "Release candidate is signed, notarized, and ready for the publication gate:"
echo "  ${RELEASE_ZIP}"
echo "  ${CHECKSUM_FILE}"
