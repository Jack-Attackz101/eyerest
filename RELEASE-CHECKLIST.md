# Iris — Release Checklist

Manual, repeatable steps to cut a signed, notarised Iris release and ship the DMG.
Do these in order. Do not skip the smoke test.

App: **Iris** · Bundle ID: `com.iris.app` · Min macOS: 13.0

---

## 0. Prerequisites (one-time)

- [ ] Xcode installed, command-line tools selected (`xcode-select -p`).
- [ ] `create-dmg` installed: `brew install create-dmg`.
- [ ] `python3` with Pillow for the DMG background: `pip3 install pillow`.
- [ ] Apple Developer account with a **Developer ID Application** certificate in the login keychain.
- [ ] A `notarytool` keychain profile created once:
      `xcrun notarytool store-credentials iris-notary --apple-id "<you>@apple.id" --team-id "<TEAMID>" --password "<app-specific-password>"`

## 1. Dev flags OFF

- [ ] `Iris/Support/DebugConfig.swift` → `fastCycleRequested = false`.
      The 20-minute timer must run at real speed. This flag is also force-compiled to `false`
      in Release via `#if DEBUG`, but keep the source value `false` too.
- [ ] No other debug/test switches left on: `grep -rn "fastCycle\|TODO: remove" Iris/`.

## 2. Version bump

- [ ] Bump `MARKETING_VERSION` in `Iris.xcodeproj` (e.g. 1.0.0 → 1.0.1) for both Debug and Release.
- [ ] Bump `CURRENT_PROJECT_VERSION` (build number) — must be higher than the last shipped build.
- [ ] Update `website/latest-version.txt` to match `MARKETING_VERSION` (this is what `UpdateChecker` polls).
- [ ] Commit the version bump.

## 3. Build & archive (Release)

- [ ] Select a generic destination (**Any Mac**).
- [ ] Product → Archive, **or** run `./build_dmg.sh` with `SIGN_ID` / `TEAM_ID` / `NOTARY_PROFILE` set.
- [ ] Configuration is **Release**, not Debug.

## 4. Signing

- [ ] Signed with the **Developer ID Application** identity (not Apple Development).
- [ ] Verify: `codesign --verify --deep --strict --verbose=2 build/export/Iris.app`.
- [ ] Confirm identity: `codesign -dvv build/export/Iris.app` shows `Authority=Developer ID Application: ...`.

## 5. Hardened runtime

- [ ] Hardened runtime enabled (`--options=runtime` / "Hardened Runtime" capability ON).
- [ ] Verify: `codesign -dvv build/export/Iris.app | grep -i runtime` reports the `runtime` flag.
- [ ] `NSCameraUsageDescription` still present in Info.plist (used by call auto-pause / detection).

## 6. Notarisation

- [ ] Submit and wait: `xcrun notarytool submit <zip|dmg> --keychain-profile iris-notary --wait`.
- [ ] Status returns **Accepted**.
- [ ] Staple the ticket: `xcrun stapler staple Iris.app` and `xcrun stapler staple Iris.dmg`.
- [ ] Validate: `xcrun stapler validate Iris.dmg` and `spctl -a -vvv -t install Iris.dmg`.

## 7. Build the DMG

- [ ] Run `./build_dmg.sh` (regenerates the background, then runs `create-dmg`).
- [ ] Layout is the minimal design: 540×340 window, Iris.app at (135,150),
      Applications alias at (405,150), a chalk arrow between them, one line of instruction text.
- [ ] `Iris.dmg` opens with the correct background and icon positions.

## 8. Install-from-DMG smoke test

- [ ] On a clean Mac (or a fresh user account), double-click `Iris.dmg`.
- [ ] Drag **Iris** onto **Applications** — no Gatekeeper block ("Apple could not verify" must NOT appear on a notarised build).
- [ ] Launch from /Applications. App appears in the menu bar (`LSUIElement`, no Dock icon).
- [ ] Eject the DMG; the app keeps running from /Applications.

## 9. First-launch permissions

- [ ] Camera permission prompt appears on first use of call/auto-pause detection (matches `NSCameraUsageDescription`).
- [ ] Accessibility permission (if used for app/site blocking or unlock movement) — grant in
      System Settings → Privacy & Security → Accessibility.
- [ ] Screen-dim overlay works: after 20 minutes the screen dims for 20 seconds with no skip button.
- [ ] Update check hits `https://useiris.vercel.app/latest-version.txt` and matches the shipped version.

## 10. Publish

- [ ] Copy the notarised, stapled `Iris.dmg` to `website/Iris.dmg`.
- [ ] Confirm `website/latest-version.txt` == the shipped `MARKETING_VERSION`.
- [ ] Deploy the website so `https://useiris.vercel.app/Iris.dmg` serves the new build.
- [ ] Download from the live URL and re-run the smoke test (step 8) once more.
- [ ] Tag the release: `git tag v<version> && git push --tags`.
