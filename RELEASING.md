# Releasing

Every push to `main` runs `.github/workflows/release.yml`: test, archive, sign, notarize,
build a DMG, notarize the DMG, and publish it as a release in `Aayush9029/releases`.

The version comes from `MARKETING_VERSION` in `Project.swift`; the build number is the
workflow run number, so it always increases.

## Required secrets

The workflow cannot run until these exist on `Aayush9029/Flare`
(Settings → Secrets and variables → Actions):

| Secret | What it is | How to get it |
|---|---|---|
| `CERTIFICATE_P12` | Base64 of a **Developer ID Application** `.p12` for team `6Q29HJZ4AG` | Export from Keychain Access, then `base64 -i cert.p12 \| pbcopy` |
| `CERTIFICATE_PASSWORD` | The password set when exporting that `.p12` | You choose it during export |
| `ASC_API_KEY_P8` | Base64 of the App Store Connect API key `.p8` | App Store Connect → Users and Access → Integrations → Keys |
| `ASC_API_KEY_ID` | The key's 10-character ID | Shown beside the key |
| `ASC_API_ISSUER_ID` | The issuer UUID | Shown above the key list |
| `RELEASES_TOKEN` | A PAT with `contents: write` on `Aayush9029/releases` | GitHub → Settings → Developer settings → Fine-grained tokens |

## Blocker: the signing certificate does not exist yet

Team `6Q29HJZ4AG` (Optimal Life Technologies, Inc) currently has only an **iPhone
Distribution** certificate. macOS distribution outside the App Store needs a
**Developer ID Application** certificate, which has to be created once in the
developer portal:

1. developer.apple.com → Certificates, Identifiers & Profiles → Certificates → **+**
2. Choose **Developer ID Application**, with `6Q29HJZ4AG` as the team.
3. Upload a CSR from Keychain Access (Certificate Assistant → Request a Certificate
   from a Certificate Authority → saved to disk).
4. Download, double-click to install, then export as `.p12` for `CERTIFICATE_P12`.

Only an Account Holder can create this, so it cannot be scripted from here.

Until that exists the workflow fails at "Import signing certificate". Local debug
builds are unaffected: they sign ad-hoc and run fine.

## Verifying a build locally

```bash
tuist install && tuist generate --no-open
xcodebuild build -workspace Flare.xcworkspace -scheme Flare -configuration Release \
  -destination 'platform=macOS'
```
