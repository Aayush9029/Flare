# Releasing Flare

Every push to `main` runs `.github/workflows/release.yml`. The workflow builds,
tests, signs, notarizes, makes a DMG, and publishes a release to
`Aayush9029/flare-releases`.

## Signing

Flare is signed with the Optimal Life Technologies identity, the same one that
signs every other Mac app:

- Identity: `Developer ID Application: Optimal Life Technologies, Inc (6Q29HJZ4AG)`
- Team: `6Q29HJZ4AG`
- API key: `27TQ78XRSX`, issuer `dbe9e3f9-9c90-4472-b041-5f360ee3dc7c`

The credentials live in `~/Secure/secrets/optimal-apps/` and never enter this repo.
See the `oss-macos-release` skill for the full pipeline.

## Secrets

| Secret | Source |
|---|---|
| `CERTIFICATE_P12` | `~/Secure/secrets/optimal-apps/developer-id.p12.base64` |
| `CERTIFICATE_P12_PASSWORD` | `~/Secure/secrets/optimal-apps/p12-password.txt` |
| `ASC_API_KEY_P8` | `~/Secure/secrets/optimal-apps/api_key_p8_base64.txt` |
| `ASC_API_KEY_ID` | `27TQ78XRSX` |
| `ASC_API_ISSUER_ID` | `dbe9e3f9-9c90-4472-b041-5f360ee3dc7c` |
| `RELEASES_TOKEN` | token that can create releases in `Aayush9029/flare-releases` |

To reset them:

```bash
S=~/Secure/secrets/optimal-apps
gh secret set CERTIFICATE_P12 --repo Aayush9029/Flare < $S/developer-id.p12.base64
gh secret set CERTIFICATE_P12_PASSWORD --repo Aayush9029/Flare < $S/p12-password.txt
gh secret set ASC_API_KEY_P8 --repo Aayush9029/Flare < $S/api_key_p8_base64.txt
gh secret set ASC_API_KEY_ID --repo Aayush9029/Flare --body 27TQ78XRSX
gh secret set ASC_API_ISSUER_ID --repo Aayush9029/Flare \
  --body dbe9e3f9-9c90-4472-b041-5f360ee3dc7c
```

## Versioning

`MARKETING_VERSION` in `Project.swift` sets the release version. The build
number is the workflow run number, so it always climbs. Tags take the form
`v<marketing>+<run>`.

## Starting a release

```bash
gh workflow run Release --repo Aayush9029/Flare
```
