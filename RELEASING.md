# Releasing Flare

Every push to `main` runs `.github/workflows/release.yml`. The workflow builds,
tests, signs, notarizes, makes a DMG, and publishes a release to
`Aayush9029/releases`.

## Secrets

| Secret | Status | Value |
|---|---|---|
| `ASC_API_KEY_P8` | set | base64 of the Optimal Life App Store Connect key |
| `ASC_API_KEY_ID` | set | `27TQ78XRSX` |
| `ASC_API_ISSUER_ID` | set | `dbe9e3f9-9c90-4472-b041-5f360ee3dc7c` |
| `RELEASES_TOKEN` | set | token that can create releases in `Aayush9029/releases` |
| `CERTIFICATE_P12` | missing | base64 of the Developer ID Application identity |
| `CERTIFICATE_PASSWORD` | missing | password for that `.p12` |

## The remaining step

Team `6Q29HJZ4AG` holds only an iPhone Distribution certificate, which cannot
sign a Mac app for distribution outside the App Store. The App Store Connect
API refuses to create a Developer ID certificate:

```
This request is forbidden for security reasons:
This operation can only be performed by the Account Holder.
```

Only the Account Holder can create one, in the web portal. A certificate signing
request is already prepared, so no keychain export is needed.

1. Open https://developer.apple.com/account/resources/certificates/add as the
   Optimal Life Account Holder.
2. Choose **Developer ID Application**, then **G2 Sub-CA**.
3. Upload `~/.flare-signing/devid.csr`.
4. Download the certificate.
5. Run:

   ```bash
   ~/.flare-signing/finish-signing.sh ~/Downloads/developerID_application.cer
   ```

The script pairs the certificate with the private key that made the request,
builds a `.p12`, sets both secrets, and imports the identity into the login
keychain for local signing.

Then start a release:

```bash
gh workflow run Release --repo Aayush9029/Flare
```

## Versioning

`MARKETING_VERSION` in `Project.swift` sets the release version. The build
number is the workflow run number, so it always climbs. Tags take the form
`v<marketing>+<run>`.
