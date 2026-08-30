#!/usr/bin/env bash
set -euo pipefail

ZIP="${1:?Usage: notarize.sh BunnyBar-VERSION.zip KEYCHAIN_PROFILE}"
PROFILE="${2:?Usage: notarize.sh BunnyBar-VERSION.zip KEYCHAIN_PROFILE}"

xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait
