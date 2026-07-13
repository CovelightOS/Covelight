# Kiosk spike — throwaway

**This is not `/app`. This code will be deleted.** It exists to answer one
question before Phase 2 (`docs/plan/03-phase2-kiosk.md`, T2.2) is built for
real: **does Android Device Owner + lock task actually hold on real
hardware** — Pixel-class and, especially, hostile vendor skins (MIUI,
One UI, ColorOS)?

Not a Covelight kiosk. No Godot, no shell, no signed content, no parent
exit path, no Companion. A single fullscreen `Activity` that draws a solid
colour and applies the Device Owner policy set from ARCHITECTURE §3.1 —
nothing else. If it's on-screen, it's either that colour or a crash log in
`adb logcat`.

Findings go in [FINDINGS.md](FINDINGS.md), one filled-in copy per device
tested. Nothing here updates `docs/plan/` — this is a spike, not a task.

## What it does

- Provisions itself as Device Owner (`dpm set-device-owner` over adb — the
  device must be factory-reset / account-free first, same requirement the
  real product will have).
- Applies, and logs the pass/fail of, each policy in ARCHITECTURE §3.1:
  lock task mode with all system UI features off, persistent default
  launcher, disabled keyguard, Wi-Fi/Bluetooth/install/uninstall/safe-boot/
  factory-reset/unknown-sources restrictions.
- Attempts to programmatically turn Wi-Fi off (`WifiManager.isWifiEnabled`)
  — Device Owner apps are *documented* as exempt from the API 29+ no-op for
  this call. "Documented as" is the whole reason this is a spike and not
  already in `/app`.
- Relaunches itself on `BOOT_COMPLETED`.

## What it deliberately does NOT do

- **Mobile data is not touched programmatically.** There's no public,
  documented Device Owner API that reliably kills cellular data across
  OEMs, and this project doesn't use private/reflection APIs (CLAUDE.md).
  The real mitigation is SIM removal at setup — this spike is exactly
  where we find out whether that's still necessary.
- No parent exit path, no PIN screen, no unprovision-from-the-device-itself
  flow. Getting out is `scripts/unprovision.sh` from a computer, full stop.

## Build & run

Requires the Android SDK (`compileSdk 36`, `minSdk 26`) and a device with
USB debugging enabled, factory-reset, no accounts signed in.

```sh
./gradlew assembleDebug
scripts/provision.sh          # installs + dpm set-device-owner + launches
# ... run the test protocol in FINDINGS.md ...
scripts/unprovision.sh        # get your phone back
```

`scripts/provision.sh` and `scripts/unprovision.sh` are plain adb wrapper
scripts, not part of the app. Read them before running them.

## Test protocol

See [FINDINGS.md](FINDINGS.md) — it has the exhaustive escape-attempt list
(every button/combo, notification shade, power menu, recovery combo, SIM
removal, low battery, incoming call) plus adb commands that check actual
radio state rather than trusting what the screen shows.
