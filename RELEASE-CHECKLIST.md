# Iris Release Checklist

Manual, ordered steps for cutting a signed, notarized Iris release DMG.
Work top to bottom — do not skip a step.

---

## Prerequisites (one-time — dad's Apple Developer account)

- [ ] Apple Developer Program enrolled at developer.apple.com ($99/year, must be 18+)
- [ ] "Developer ID Application" certificate created and in Keychain:
      Keychain Access → Certificate Assistant → Request a Certificate from CA
      → upload `.certSigningRequest` at developer.apple.com → Certificates → "+"
      → "Developer ID Application" → download `.cer` → double-click to install
- [ ] App-specific password created at appleid.apple.com → Sign-In & Security → App-Specific Passwords
- [ ] Team ID noted from developer.apple.com → Account (10-character string, e.g. `AB12CD34EF`)

---

## 1. Confirm the fast-cycle dev flag is OFF
- [ ] Verify `fastCycleRequested` is disabled for release. It is already
      double-guarded, but confirm before every build — a shipped fast-cycle
      build breaks the real 20-minute timer.
- [ ] Grep the source for `fastCycleRequested` and confirm no code path forces
      it on in a Release configuration.

## 2. Bump version and build number
- [ ] Increment the marketing version (CFBundleShortVersionString).
- [ ] Increment the build number (CFBundleVersion).
- [ ] Commit the bump.

## 3. Archive in Xcode
- [ ] Select the release scheme and a Release configuration.
- [ ] Product → Archive.
- [ ] Confirm the archive appears in the Organizer.

## 4. Sign with Developer ID

Export `Iris.app` from the archive (Xcode Organizer → Distribute App → Developer ID)
or copy the Release build to the repo root:

```bash
cp -R build/Build/Products/Release/Iris.app ./Iris.app
```

## 5. Enable the hardened runtime
- [ ] Confirm the hardened runtime is enabled on the exported app.
- [ ] Confirm required entitlements are present and no debug entitlements leak.
      (`Iris/Iris.entitlements` — camera access for call detection).

## 6. Notarize and staple

Run the signing and notarization script:

```bash
export APPLE_ID="dad@example.com"
export TEAM_ID="AB12CD34EF"

chmod +x installer/sign_and_notarize.sh
installer/sign_and_notarize.sh \
  "Developer ID Application: Dad Name (AB12CD34EF)" \
  <app-specific-password>
```

The script signs `Iris.app` with hardened runtime, submits to Apple's notary
service, waits for the result (2–10 min), staples the ticket, then verifies with:

```bash
codesign --verify --deep --strict --verbose=2 Iris.app
spctl -a -vvv -t install Iris.app
xcrun stapler validate Iris.app
```

All three must pass before continuing.

- [ ] `notarytool` returned "Accepted"
- [ ] `spctl` output contains "accepted" and "source=Notarized Developer ID"
- [ ] `stapler validate` returned "The staple and validate action worked!"

## 7. Build the DMG

```bash
chmod +x installer/build_dmg.sh
DEV_ID="Developer ID Application: Dad Name (AB12CD34EF)" \
  ./installer/build_dmg.sh
```

The script regenerates the background, builds the DMG, then signs and staples
the DMG itself. If `DEV_ID` is not set it prints a loud warning and the DMG
will trigger the "damaged" error for any downloader.

- [ ] Place the signed, stapled `Iris.app` at the repo root before running.
- [ ] Script ends with "✓ Iris.dmg is signed and stapled."
- [ ] Confirm `Iris.dmg` is produced with the correct window layout.

## 8. Install-from-DMG smoke test on a clean account
- [ ] Mount `Iris.dmg` on a clean macOS user account.
- [ ] Drag Iris into Applications from the DMG.
- [ ] Launch the installed copy (not the one inside the DMG).

## 9. First launch: permissions and Gatekeeper
- [ ] First launch via right-click → Open.
- [ ] Confirm Gatekeeper accepts the notarized app.
- [ ] Grant and verify each permissions prompt the app requests.

## 10. Verify the 20-minute timer on real timing
- [ ] With fast-cycle OFF, confirm the break timer fires on real 20-minute
      timing — not the dev fast-cycle interval.

---

## If a user reports "Iris is damaged"

The app is not damaged. macOS attached a quarantine flag when the file was
downloaded, and Gatekeeper is rejecting it because the DMG is not notarized.

**One-line fix the user can run themselves:**

```bash
xattr -d com.apple.quarantine /path/to/Iris.dmg
```

Replace `/path/to/Iris.dmg` with the actual path (e.g. `~/Downloads/Iris.dmg`).
After running this, the DMG opens normally.

**Permanent fix:** complete steps 6 and 7 of this checklist and redeploy
`website/Iris.dmg`. Once the DMG is properly signed and notarized, no user
will ever see this error.
