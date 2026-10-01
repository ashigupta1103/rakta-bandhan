#!/usr/bin/env bash
# Runs integration_test/app_flow_test.dart on a connected Android emulator
# and saves a screenshot at every `SNAP:<name>` the test prints.
#
# Prerequisites:
#   - an Android emulator running (adb devices shows emulator-5554)
#   - Firebase emulators running for the app's project:
#       firebase emulators:start --project rakta-bandhan2026 --only auth,firestore,functions,storage
#
# Usage: bash tool/e2e_screenshots.sh [output-dir]
set -u
OUT="${1:-build/e2e_screenshots}"
ADB="${ADB:-adb}"
PKG=com.raktabandhan.app
LOG="$OUT/run.log"
mkdir -p "$OUT"
: > "$LOG"

# GPS at Chennai Central, so registration finds a real fix.
"$ADB" emu geo fix 80.2707 13.0827 >/dev/null 2>&1

# Grant runtime permissions as soon as the app is installed, so system
# dialogs don't cover the screens being captured.
(
  for _ in $(seq 1 600); do
    if "$ADB" shell pm list packages 2>/dev/null | grep -q "$PKG"; then
      for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS RECORD_AUDIO CAMERA; do
        "$ADB" shell pm grant "$PKG" "android.permission.$p" >/dev/null 2>&1
      done
    fi
    sleep 1
  done
) &
GRANTER=$!

# Google's one-time "Location Accuracy" prompt (shown the first time an app
# asks for a precise fix): tap "Turn on", as a user would. Detected by the
# focused window belonging to Google Play services; "Turn on" sits at the
# dialog's bottom right (72% across, 73.5% down on a phone-shaped screen).
(
  read -r W H < <("$ADB" shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | tr 'x' ' ')
  for _ in $(seq 1 600); do
    if "$ADB" shell dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedWindow' | grep -q 'com.google.android.gms'; then
      "$ADB" shell input tap $(( W * 72 / 100 )) $(( H * 735 / 1000 ))
      echo "tapped Location Accuracy: Turn on"
      sleep 3
    fi
    sleep 1
  done
) &
DISMISSER=$!

# Screenshot every SNAP line as it appears.
(
  seen=""
  for _ in $(seq 1 3600); do
    for name in $(grep -o 'SNAP:[A-Za-z0-9_]*' "$LOG" 2>/dev/null | cut -d: -f2); do
      case " $seen " in *" $name "*) continue ;; esac
      "$ADB" exec-out screencap -p > "$OUT/$name.png"
      seen="$seen $name"
      echo "captured $name"
    done
    sleep 0.5
  done
) &
SHOOTER=$!

flutter test integration_test/app_flow_test.dart -d emulator-5554 --dart-define=USE_EMULATORS=true 2>&1 | tee -a "$LOG"
STATUS=${PIPESTATUS[0]}
sleep 4
kill "$GRANTER" "$SHOOTER" "$DISMISSER" 2>/dev/null
echo "screenshots in $OUT (exit $STATUS)"
exit "$STATUS"
