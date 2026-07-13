#!/usr/bin/env bash
# Installs the spike APK and sets it as Device Owner. Prerequisites this
# script does NOT do for you (Device Owner refuses to set up otherwise):
#   1. Factory-reset the device (or use a device that has never had any
#      account added since its last reset).
#   2. Enable Developer Options + USB debugging, connect via `adb devices`.
#   3. Do NOT sign into any Google/other account on the device.
set -euo pipefail

PKG="org.covelight.spike.kiosk"
ADMIN="$PKG/.KioskAdminReceiver"
APK="${1:-app/build/outputs/apk/debug/app-debug.apk}"

if [ ! -f "$APK" ]; then
    echo "APK not found at $APK — run ./gradlew assembleDebug first, or pass a path." >&2
    exit 1
fi

echo "== waiting for device =="
adb wait-for-device

echo "== installing $APK =="
adb install -r "$APK"

echo "== setting device owner =="
adb shell dpm set-device-owner "$ADMIN"

echo "== launching =="
adb shell am start -n "$PKG/.MainActivity"

cat <<'EOF'

Done. The device should now be showing a solid-colour fullscreen screen.
Run scripts/unprovision.sh from this same machine when you're done — don't
lose the ability to reach the device over adb before you do.
EOF
