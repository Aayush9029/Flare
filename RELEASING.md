# Releasing Flare

Every push to `main` runs `.github/workflows/release.yml`. The workflow builds,
tests, signs, notarizes, makes a DMG, and publishes a release to
`Aayush9029/releases`.

## Signing

Flare uses the shared OSS identity, the same one that signs Breeze and Compose:

- Identity: `Developer ID Application: Aayush Pokharel (4538W4A79B)`
- Team: `4538W4A79B`
- API key: `KDZQQND374`, issuer `32b44455-4bec-4cb8-8fbf-eb06754dda95`

The credentials live in `~/Secure/secrets/apple-dev/` and never enter this repo.
See the `oss-macos-release` skill for the full pipeline.

Team `6Q29HJZ4AG` cannot sign a Mac app for distribution outside the App Store.
It holds only an iPhone Distribution certificate, and the App Store Connect API
refuses to create a Developer ID certificate for it, because only the Account
Holder can do that in the web portal.

## Secrets

| Secret | Source |
|---|---|
| `CERTIFICATE_P12` | `~/Secure/secrets/apple-dev/certificate_p12_base64.txt` |
| `ASC_API_KEY_P8` | `~/Secure/secrets/apple-dev/api_key_p8_base64.txt` |
| `ASC_API_KEY_ID` | `KDZQQND374` |
| `ASC_API_ISSUER_ID` | `32b44455-4bec-4cb8-8fbf-eb06754dda95` |
| `RELEASES_TOKEN` | token that can create releases in `Aayush9029/releases` |

The `.p12` carries an empty export password, so the workflow passes `-P ""` and
there is no password secret.

To reset them:

```bash
gh secret set CERTIFICATE_P12 --repo Aayush9029/Flare \
  < ~/Secure/secrets/apple-dev/certificate_p12_base64.txt
gh secret set ASC_API_KEY_P8 --repo Aayush9029/Flare \
  < ~/Secure/secrets/apple-dev/api_key_p8_base64.txt
gh secret set ASC_API_KEY_ID --repo Aayush9029/Flare --body KDZQQND374
gh secret set ASC_API_ISSUER_ID --repo Aayush9029/Flare \
  --body 32b44455-4bec-4cb8-8fbf-eb06754dda95
```

## Versioning

`MARKETING_VERSION` in `Project.swift` sets the release version. The build
number is the workflow run number, so it always climbs. Tags take the form
`v<marketing>+<run>`.

## Starting a release

```bash
gh workflow run Release --repo Aayush9029/Flare
```
