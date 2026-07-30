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

---

## Shipping an update (Sparkle self-update)

> **⚠ Sparkle updates silently fail on unsigned builds.**
> Sparkle's `Autoupdate` XPC helper must be code-signed and the app must be
> notarized. An unsigned release will appear in the appcast but users will
> never be prompted to install it. Complete steps 4–6 of this checklist first.

### One-time setup (done once, not per release)

- [ ] **Generate EdDSA key pair**
  ```bash
  # After Xcode has resolved the Sparkle package:
  SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData \
      -name generate_keys -path "*/Sparkle/*" -type f 2>/dev/null | head -1)
  "$SIGN_UPDATE"
  ```
  The private key is stored in your **macOS Keychain** automatically — it is
  never written to disk or committed to the repo. Back it up with:
  ```bash
  security find-generic-password -s "https://sparkle-project.org" -w | pbcopy
  ```
  Store the copied base64 string in a password manager. If you lose this key,
  existing users cannot verify future updates and you must ship a new
  `SUPublicEDKey` in a future version.

- [ ] **Put the public key in Info.plist**
  The command above prints a line like `Public key (SUPublicEDKey): <base64>`.
  Open `Iris/Info.plist` and replace the `REPLACE_WITH_OUTPUT_OF_generate_keys`
  placeholder with that base64 string.

- [ ] **Enable GitHub Pages**
  Repo Settings → Pages → Source: Deploy from branch → Branch: `main`,
  Folder: `/docs`. After saving, the appcast will be live at:
  `https://jack-attackz101.github.io/eyerest/appcast.xml`

- [ ] **Populate the 1.0.0 appcast entry**
  Once you have the key and a signed 1.0.0 build:
  ```bash
  installer/release_update.sh 1.0.0 1
  ```
  Then commit and push `docs/appcast.xml`.

---

### Per-release steps (every version after 1.0.0)

Complete the main checklist steps 1–7 first (bump version, archive, sign,
notarize, build DMG). Then:

- [ ] **Run the release script**
  ```bash
  installer/release_update.sh <version>
  # e.g. installer/release_update.sh 1.0.1
  ```
  The script zips `Iris.app`, signs the zip with EdDSA (key from Keychain),
  and prepends a new `<item>` block to `docs/appcast.xml`.

- [ ] **Commit and push the updated appcast**
  ```bash
  git add docs/appcast.xml
  git commit -m "release: appcast for v<version>"
  git push origin main
  ```
  GitHub Pages re-publishes within ~60 seconds. Existing users running a
  Sparkle-enabled build will be notified at their next daily check.

- [ ] **Create the GitHub Release and upload the zip**
  ```bash
  gh release create v<version> Iris-<version>.zip \
      --title "Iris <version>" \
      --notes "See useiris.vercel.app for what's new."
  ```
  The enclosure URL in the appcast points to this GitHub Release asset.

- [ ] **Verify the update on a test machine**
  Install the *previous* version, launch it, open Settings → "Check for
  Updates…". Sparkle should find the new version and offer to install it.
  Confirm the install completes and the relaunched app shows the new version.

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
