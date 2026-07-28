# Iris — Manual Xcode Release Checklist

Work top to bottom. Do not skip a step; each gate protects the one below it.

## 1. Dev flags off
- [ ] `fastCycleRequested` is `false` in `Iris/Support/DebugConfig.swift`.
      This is the dev-only fast-cycle flag for testing the 20-minute timer; it
      must never ship enabled.
- [ ] Confirm the `#if DEBUG` guard forces `fastCycle` to `false` in Release
      builds (the flag is compiled out of Release regardless).
- [ ] Build configuration is **Release**, not Debug.

## 2. Code signing
- [ ] Signing is set to the "Developer ID Application" certificate (not a
      development or App Store cert — this is a directly distributed app).
- [ ] Team ID is correct and the signing identity is valid/unexpired.
- [ ] `codesign --verify --deep --strict --verbose=2` passes on the built
      `Iris.app`.

## 3. Hardened runtime
- [ ] Hardened Runtime is enabled in the target's Signing & Capabilities.
- [ ] Any required entitlements/exceptions are present and justified.
- [ ] `codesign -d --entitlements :- Iris.app` shows the expected entitlements.

## 4. Notarisation
- [ ] Submit the signed app/DMG with `xcrun notarytool submit --wait`.
- [ ] Notarisation returns **Accepted**.
- [ ] Staple the ticket: `xcrun stapler staple Iris.app` (and the DMG).
- [ ] `spctl -a -vvv --type exec Iris.app` reports `accepted / Notarized
      Developer ID`.

## 5. Version bump
- [ ] Bump `CFBundleShortVersionString` (marketing version).
- [ ] Bump `CFBundleVersion` (build number) — strictly greater than the last
      shipped build.
- [ ] Version matches the Git tag and release notes.

## 6. DMG build
- [ ] Regenerate the background if it changed: `python3 installer/gen_dmg_bg.py`.
- [ ] Build the DMG with create-dmg:
      ```
      create-dmg \
        --volname "Iris" \
        --window-size 540 340 \
        --background installer/dmg_background.png \
        --icon "Iris.app" 135 150 \
        --app-drop-link 405 150 \
        Iris.dmg \
        build/Iris.app
      ```
- [ ] Icon positions match the background art (app icon at 135,150;
      Applications alias at 405,150).

## 7. Install-from-DMG smoke test
- [ ] Mount the DMG on a clean machine/account.
- [ ] Drag Iris into Applications and eject the DMG.
- [ ] Launch from `/Applications` — Gatekeeper allows it with no warning
      (notarisation + stapling verified end to end).

## 8. First-launch permissions
- [ ] On first launch the expected permission prompts appear and can be
      granted.
- [ ] After granting, the app functions correctly (the 20-minute timer runs
      at normal cadence — fast-cycle is off).
- [ ] Relaunch confirms permissions persist and no prompts re-appear.
