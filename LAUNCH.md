# Launch Day Checklist

Ordered steps for shipping Iris. Do them in order, don't skip ahead.

## 1. Build the DMG

- [ ] Pull latest `main` and confirm the app builds clean in Xcode (Release configuration).
- [ ] Export/archive `Iris.app` and place it at the repo root.
- [ ] Run `installer/gen_dmg_bg.py` (also runs automatically inside the build script) to regenerate the 460x660 background.
- [ ] Run `installer/build_dmg.sh` to produce `Iris.dmg`.

## 2. Sign and notarize

- [ ] Run `installer/sign_and_notarize.sh` with a valid Apple Developer ID (via MARFI once the account is sorted).
- [ ] Re-run `installer/build_dmg.sh` with `DEV_ID` set so the DMG itself gets signed and stapled.
- [ ] Confirm with `xcrun stapler validate Iris.dmg` that the ticket is attached.
- [ ] Confirm with `codesign --verify --deep --strict Iris.app` that the app passes.

## 3. Upload and commit

- [ ] Copy the fresh, signed `Iris.dmg` into `website/Iris.dmg`, replacing the old one.
- [ ] Commit with a clear message (e.g. `chore: ship signed Iris.dmg for launch`).
- [ ] Push to `main` and confirm Vercel redeploys the site with the new file.

## 4. Test on a clean account

- [ ] Download `Iris.dmg` from the live site on a Mac (or account) that has never run Iris before.
- [ ] Confirm Gatekeeper does NOT show "Iris is damaged and can't be opened."
- [ ] Drag Iris into Applications, launch it, and confirm the menu bar icon appears with no crash.
- [ ] Click through the full break flow once (blackout, morning challenge, posture nudge, focus blocker, auto-pause on a test call) to confirm nothing regressed.

## 5. Show HN

- [ ] Post to Show HN with the exact title: `Show HN: Iris, a Mac app that forces me to take breaks`
- [ ] Link straight to `https://useiris.vercel.app`.
- [ ] Stay on the thread for the first few hours to answer questions.

## 6. Product Hunt

- [ ] Schedule or launch the Product Hunt listing same day (or the next available slot).
- [ ] Use the same core screenshots/video as the site.
- [ ] Reply to early comments quickly.

## 7. LinkedIn

- [ ] Post a short launch announcement from Jack's account.
- [ ] Link to the Show HN thread and/or the site directly.
- [ ] Tag or mention anyone relevant (mentors, MARFI) who helped get the signing sorted.
