#!/usr/bin/env bash
set -euo pipefail

ZIP="${1:?Usage: notarize.sh BunnyBar-VERSION.zip}"
PROFILE="${2:-AC_PASSWORD}"

xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait
