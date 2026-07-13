# Kiosk spike — findings

Copy this whole file to `FINDINGS-<codename>.md` per device tested (e.g.
`FINDINGS-beryllium.md` for a Poco F1). Keep every filled-in copy — this is
raw material for `docs/devices/device-matrix.md` and for T2.2's real
implementation, not a single mutable scratch file.

## Device

- Model / marketing name:
- Codename (if known):
- Android version / security patch level:
- Vendor skin + version (e.g. MIUI 15, One UI 6, ColorOS 14, stock AOSP):
- Build date tested:

## Policy checklist

One row per call `MainActivity.applyKioskPolicies()` makes. "Result" comes
from `adb logcat -s KioskSpike` (each attempt logs `OK: <label>` or
`FAILED: <label> — <exception>`) — **logged success is not the same as
verified-true**; the columns after it are where you actually check.

| Policy (matches the code, in order) | Logged result | Independently verified? | Notes |
|---|---|---|---|
| `setLockTaskPackages` | | | |
| `setLockTaskFeatures(LOCK_TASK_FEATURE_NONE)` | | | Verify: no status bar, no recents, no home gesture works |
| `setKeyguardDisabled` | | | |
| `addPersistentPreferredActivity` (HOME) | | | Verify after reboot, not just first launch |
| `DISALLOW_SAFE_BOOT` | | | Verify: try booting to safe mode (see below) |
| `DISALLOW_FACTORY_RESET` | | | Verify: Settings > factory reset option gone/blocked |
| `DISALLOW_INSTALL_APPS` | | | |
| `DISALLOW_UNINSTALL_APPS` | | | Verify: can't uninstall via Settings even if reached |
| `DISALLOW_INSTALL_UNKNOWN_SOURCES` | | | |
| `DISALLOW_CONFIG_WIFI` | | | Blocks the *toggle*, not necessarily the radio — see below |
| `DISALLOW_BLUETOOTH` | | | This restriction is documented to actually disable the radio |
| `DISALLOW_CONFIG_MOBILE_NETWORKS` | | | |
| `wifi disable` (`WifiManager.isWifiEnabled = false`) | | | **The most uncertain one — see Radio verification** |
| `startLockTask` | | | |

## Radio verification — don't trust the screen, check with adb + a second device

Run these over adb (works over USB regardless of what the lock-task screen
shows) and record actual output:

```sh
adb shell dumpsys wifi | grep -i "Wi-Fi is"
adb shell dumpsys bluetooth_manager | grep -i state
adb shell settings get global airplane_mode_on
adb shell settings get global wifi_on
```

Then, independently of what Android *reports*:

- **Wi-Fi:** from a second device, does an access point still see this
  device associate or probe-request? A scanner app on another phone is
  more honest than trusting `dumpsys`.
- **Bluetooth:** from a second device/phone, does a BLE/Classic scanner see
  this device advertising?
- **Mobile data:** was a SIM even present? If yes: does the device still
  register on the carrier network (`adb shell dumpsys telephony.registry`
  or just watch for a signal indicator, if any UI surface still shows one)?

This distinction matters: Tier 1's claim is **policy**, not structural
(CLAUDE.md #7). If `dumpsys` says a radio is off but a second device still
sees it broadcasting, that's not a logging bug — that's the actual finding
this spike exists to catch, and it's disqualifying for shipping the claim
as-is.

## Escape-attempt protocol

Try each of these for real, on hardware, not in an emulator. Check the box
and add a note for anything that got you out of the kiosk screen, however
briefly.

- [ ] Hardware/gesture Home
- [ ] Hardware/gesture Back
- [ ] Recents / Overview (button or gesture)
- [ ] Notification shade, one-finger pull from top
- [ ] Quick Settings, two-finger pull from top
- [ ] Edge-swipe gestures — left edge, right edge, bottom edge (back
      gesture), bottom edge held (recents gesture)
- [ ] Power button, single press (screen off, then on again)
- [ ] Power button, long press (power menu — does it even appear? if so,
      does Reboot/Power off/Emergency work from it?)
- [ ] Power + Volume-up (screenshot combo — harmless, but confirm nothing
      else surfaces alongside it)
- [ ] Power + Volume-down held (recovery mode entry attempt)
- [ ] Volume up + Volume down held together
- [ ] Assistant trigger — long-press Home/Power, "Hey Google"/Bixby if a
      mic is live
- [ ] Vendor hardware button, if the device has one (Bixby key, etc.)
- [ ] Accessibility triple-tap / shortcut gesture, if enabled by default on
      this skin
- [ ] Incoming call from a second phone — does the dialer UI break lock
      task?
- [ ] Low battery warning dialog (or simulate via
      `adb shell dumpsys battery set level 5`)
- [ ] Critical battery forced shutdown
- [ ] SIM removal while running (if applicable)
- [ ] SIM insertion while running (if it was absent)
- [ ] USB cable unplug / replug
- [ ] Random mashing + swiping + button-holding, 10 continuous minutes
      (T2.2's "small child abuse test")
- [ ] `adb shell am force-stop org.covelight.spike.kiosk` — does anything
      relaunch it, or does the device fall through to the vendor launcher?
- [ ] Reboot (`adb reboot`) — does it come back into the kiosk screen
      automatically, and how long does that take?
- [ ] Physical reboot (hold power to force restart) — same check
- [ ] Any vendor-specific "kids mode," "one-handed mode," or gesture
      shortcut this skin ships that summons system UI

## Vendor-skin-specific behavior

Free-form: anything this skin does differently from stock AOSP — extra
permission prompts, a vendor "protected apps"/"autostart" setting that
must be manually enabled for `BOOT_COMPLETED` to fire, aggressive
background-kill (MIUI is known hostile terrain per ARCHITECTURE §3.3),
a vendor dialog that appears over the lock-task screen, etc.

## Overall verdict for this device

- [ ] Held completely — no escape found in the protocol above
- [ ] Held with caveats — note exactly which check failed and how
- [ ] Did not hold — describe the escape

## Open questions this run raised

(Anything the protocol above didn't think to test, or a result that needs
a second device/session to confirm.)
