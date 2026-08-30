# Release checklist

BunnyBar targets macOS 13 Ventura and later. The target uses App Sandbox and
Hardened Runtime. Public distribution requires a Developer ID Application
certificate and Apple notarization.

## 1. Verify the source tree

From the repository root, build Debug and run both deterministic checks, then
create the local Release candidate:

```sh
Scripts/verify.sh
Scripts/build-unsigned-rc.sh 0.1.0
```

The unsigned candidate is only for local installation testing. Check launch,
quit, Launch at Login, display reconnection, fullscreen Spaces, sleep/wake, and
the Show/Hide command. Never upload the `-unsigned-rc.zip` file.

## 2. Prepare Apple signing

Install a valid **Developer ID Application** certificate in the login keychain.
Create a `notarytool` keychain profile without putting credentials in the repo:

```sh
xcrun notarytool store-credentials BUNNYBAR_NOTARY
```

This interactive Apple credential step is intentionally not automated. Do not
commit Apple IDs, app-specific passwords, API keys, Team IDs, or certificates.

## 3. Build, sign, notarize, and staple

Run the credential-gated release script with the Apple Developer Team ID and
the keychain profile name:

```sh
DEVELOPMENT_TEAM=TEAMID \
NOTARY_PROFILE=BUNNYBAR_NOTARY \
Scripts/release.sh 0.1.0
```

The script archives the Release target, exports it with Developer ID, verifies
the signature, submits it for notarization, staples and validates the ticket,
then creates:

```text
build/release-0.1.0/BunnyBar-0.1.0.zip
build/release-0.1.0/BunnyBar-0.1.0.zip.sha256
```

The final ZIP is created after stapling. `spctl` must accept the exported app.
The script also rejects a non-universal binary, a missing App Sandbox
entitlement, or an exported app that still permits debugger attachment.

## 4. Publication gate

Before publishing, confirm all of the following:

- `git status --short` is empty and the release commit is pushed.
- The version is `0.1.0` and the tag will be `v0.1.0`.
- The SHA-256 file matches the final stapled ZIP.
- A fresh Mac can open the downloaded ZIP and launch BunnyBar without a
  Gatekeeper warning.
- Release notes include supported macOS versions and the Launch at Login note.
- `docs/release-notes-0.1.0.md` matches the final build.

Creating or pushing the tag, creating the GitHub Release, and uploading assets
are deliberate public actions. They are not performed by the scripts.

## 5. Optional Homebrew Cask

After GitHub Release publication, copy the final version and checksum into
`docs/homebrew_formula_template.rb`. Homebrew distribution is a separate step
and should follow the first direct-download release.
