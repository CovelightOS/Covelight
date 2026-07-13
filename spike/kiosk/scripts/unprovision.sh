#!/usr/bin/env bash
# Reverses provision.sh: exits lock task, removes Device Owner, removes the
# app. adb over USB is not affected by any of this app's radio/UI policies,
# so this should always work as long as the cable is still plugged in.
set -uo pipefail

PKG="org.covelight.spike.kiosk"
ADMIN="$PKG/.KioskAdminReceiver"

echo "== stopping lock task (if active) =="
adb shell am task lock stop || echo "  (not in lock task, or already stopped — fine)"

echo "== removing device owner =="
adb shell dpm remove-active-admin --user 0 "$ADMIN" \
    || adb shell dpm remove-active-admin "$ADMIN" \
    || echo "  remove-active-admin failed both forms — see fallback below"

echo "== force-stopping and uninstalling =="
adb shell am force-stop "$PKG" || true
adb uninstall "$PKG" || echo "  uninstall failed or was already gone — fine"

cat <<'EOF'

If the device is still locked down after this:
  1. Confirm the cable is connected and `adb devices` shows it.
  2. Re-run this script — dpm remove-active-admin is safe to retry.
  3. If adb genuinely can't reach it: hold Power to get the power menu; if
     even that's blocked, a hardware Power+Volume-down combo into recovery
     and a factory reset is the last resort. This should not be necessary —
     if it is, that itself is the single most important line in
     FINDINGS.md.
EOF
