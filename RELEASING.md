# Releasing

Releases are built by GitHub Actions (`.github/workflows/release.yml`). Pushing a `vX.Y.Z` tag:

1. Builds the app for Apple Silicon and Intel.
2. Signs and notarizes it, if a Developer ID certificate is configured.
3. Creates a DMG (for new users) and a ZIP (for Sparkle updates), and signs the `appcast.xml` update feed.
4. Uploads everything to a **draft** GitHub release.

Publishing the draft rolls the update out: running copies of the app find it on their next update check.

## For each release

```sh
scripts/set-version.sh 0.2.0      # sets the version and bumps the build number
git commit -am "Release 0.2.0"
git tag v0.2.0
git push && git push --tags
```

Then review the draft release on GitHub and publish it.

> Sparkle compares **build numbers**. If you release without the script, make sure `CURRENT_PROJECT_VERSION` goes up.

## One-time setup: repository secrets

| Secret | Required | Purpose |
|---|---|---|
| `SPARKLE_PRIVATE_KEY` | Yes | Signs updates |
| `DEVELOPER_ID_CERTIFICATE` | For signing | Developer ID Application certificate (.p12, base64) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | For signing | Password of the .p12 |
| `APPLE_ID` | For notarization | Apple account email |
| `APPLE_APP_PASSWORD` | For notarization | App-specific password from appleid.apple.com |
| `APPLE_TEAM_ID` | For signing and notarization | Team ID of the developer account |

**Sparkle key:** the private key is stored in the login Keychain of the machine that generated it; the public key is in `project.yml` (`SPARKLE_PUBLIC_KEY`). To add the private key as a secret:

```sh
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt
gh secret set SPARKLE_PRIVATE_KEY < sparkle-private-key.txt
rm sparkle-private-key.txt
```

If this key is lost, existing installations can no longer be updated. Keep a backup somewhere safe.

**Developer ID:** requires a paid Apple Developer Program membership. Without it releases still work, but they are not notarized and new users have to right-click › Open on first launch. Create the certificate in Xcode › Settings › Accounts › Manage Certificates, export it as .p12 from Keychain Access, then:

```sh
base64 -i DeveloperID.p12 | gh secret set DEVELOPER_ID_CERTIFICATE
```
