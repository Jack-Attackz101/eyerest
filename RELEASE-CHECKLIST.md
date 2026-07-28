# Iris Release Checklist

Manual, ordered steps for cutting a signed, notarized Iris release DMG.
Work top to bottom — do not skip a step.

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
- [ ] Sign with the Developer ID Application certificate.
- [ ] Confirm the signing identity and team are correct.

## 5. Enable the hardened runtime
- [ ] Confirm the hardened runtime is enabled on the exported app.
- [ ] Confirm required entitlements are present and no debug entitlements leak.

## 6. Notarize and staple
- [ ] Submit the app to Apple notarization (notarytool).
- [ ] Wait for "Accepted".
- [ ] Staple the notarization ticket to the app.
- [ ] Validate with `spctl -a -vvv` and `stapler validate`.

## 7. Build the DMG
- [ ] Place the signed, stapled `Iris.app` at the repo root.
- [ ] Run `installer/build_dmg.sh` (regenerates the background, runs create-dmg).
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
