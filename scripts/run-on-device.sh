#!/bin/sh
# Runs a built app on a device the way an unattended measurement needs it run:
# install, launch, look for a while, and close it again before anything is reported
# (FR-TOOL-180). The next run has to start on a cold device, and an app left
# rendering in the background is what makes the next number unreproducible
# (`specs/50-verification.md`).
#
# Closing is a trap and not a last line, because the runs most likely to leave the app
# behind are the ones that stop early: a failed screenshot, a Ctrl-C, a device that
# went away. The happy path closes it explicitly, before it reports; every other path
# closes it on the way out.
#
# The device is named by the environment and never by this file. No requirement says
# so — the specification is about signing identifiers (CON-PUB-040) and secrets
# (CON-PUB-060), and a device identifier is neither — it is the maintainer's standing
# rule that one never enters the repository, said out loud here rather than passed off
# as a rule. The runner beside this one takes its simulator the same way.
#
# Standard tools only (ART-040): `xcrun devicectl` and `plutil`, which read the JSON
# `devicectl` writes without a language runtime in between.
#
# implements: FR-TOOL-180
#
# Usage: CRAWLCALL_DEVICE=<udid> scripts/run-on-device.sh <app> [screenshot]
#   CRAWLCALL_DEVICE   the device to install on; required
#   CRAWLCALL_WATCH    seconds to leave the app running before closing it (default 6)
#   CRAWLCALL_RECORD   where to put the frame record: the app records its frames, and
#                      the record is taken off the device and summed up (FR-TOOL-250)
#   CRAWLCALL_RECORD_TOP  how many of the slowest frames the summary names (default 5)
set -eu

APP="${1:-}"
SHOT="${2:-}"
DEVICE="${CRAWLCALL_DEVICE:-}"
WATCH="${CRAWLCALL_WATCH:-6}"
RECORD="${CRAWLCALL_RECORD:-}"
TOP="${CRAWLCALL_RECORD_TOP:-5}"

# The frame record's summary (FR-TOOL-250): how many frames, how many came late, and
# the slowest by name with where their time went. Late is one and a half frame periods
# at 60 a second, 25 ms: an on-time frame is 16.7 ms, one after a skipped frame 33.
# The columns are the app's own (FrameRecording.header): frame, time, interval, step,
# deliberation, see-through, draw, events.
#
# implements: FR-TOOL-250
LATE_MS=25
frames_report() {
  file="$1"; top="$2"
  frames=$(awk 'NR > 1' "$file" | wc -l | tr -d ' ')
  late=$(awk -F, -v late="$LATE_MS" 'NR > 1 && $3 + 0 > late + 0 { n++ } END { print n + 0 }' "$file")
  echo "frames: $frames, late (over ${LATE_MS} ms): $late"
  awk 'NR > 1' "$file" | sort -t, -k3,3 -g -r | head -n "$top" | awk -F, '{
    printf "  frame %s at %s ms: interval %s ms — step %s (deliberation %s), see-through %s, draw %s", $1, $2, $3, $4, $5, $6, $7
    if ($8 != "") printf " — %s", $8
    printf "\n"
  }'
}

if [ -z "$APP" ]; then
  echo "usage: CRAWLCALL_DEVICE=<udid> $0 <app> [screenshot]" >&2
  exit 2
fi
if [ ! -f "$APP/Info.plist" ]; then
  echo "$APP is not a built app: no Info.plist in it" >&2
  exit 2
fi
if [ -z "$DEVICE" ]; then
  echo "no device given: set CRAWLCALL_DEVICE" >&2
  echo "available:" >&2
  xcrun devicectl list devices >&2 || true
  exit 2
fi

BUNDLE=$(plutil -extract CFBundleIdentifier raw -o - "$APP/Info.plist")
work=$(mktemp -d)
launched=""

# Ends the app this run started, and says whether it is actually gone. Safe to call
# twice: the second call has no process to close and does nothing, which is what lets
# the happy path close before it reports and the trap close after everything else.
#
# Fails when the app is still there, and the run fails with it: the reason for closing
# is the next measurement, so a run that left the device warm has not succeeded
# whatever else it did.
close() {
  [ -n "$launched" ] || return 0
  pid="$launched"
  launched=""
  xcrun devicectl device process terminate --device "$DEVICE" --pid "$pid" > /dev/null 2>&1 || true
  # A terminate that was accepted is not a process that has gone; asked again a moment
  # later, the device is the one that answers.
  sleep 2
  if xcrun devicectl device info processes --device "$DEVICE" 2>/dev/null | grep -q "$BUNDLE"; then
    echo "STILL RUNNING"
    return 1
  fi
  echo "closed"
}
trap 'status=$?; if ! close && [ "$status" -eq 0 ]; then status=1; fi; rm -rf "$work"; exit $status' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

started=$(date +%s)
xcrun devicectl device install app --device "$DEVICE" "$APP" > /dev/null
echo "installed in $(( $(date +%s) - started ))s"

# The record is switched on in the app by its launch environment (FR-TOOL-230).
if [ -n "$RECORD" ]; then
  set -- --environment-variables '{"CRAWLCALL_FRAMES":"1"}'
else
  set --
fi
xcrun devicectl device process launch --device "$DEVICE" "$@" "$BUNDLE" \
  --json-output "$work/launch.json" > /dev/null
launched=$(plutil -extract result.process.processIdentifier raw -o - "$work/launch.json")
echo "launched"

sleep "$WATCH"

if [ -n "$SHOT" ]; then
  xcrun devicectl device capture screenshot --device "$DEVICE" --destination "$SHOT" > /dev/null
  echo "screenshot taken"
fi

# Before it reports, not after: a step past the report is a step that gets skipped.
close

# The app wrote its record when it was asked to terminate (FR-TOOL-240); it is taken
# off the device now that the app has gone, and summed up.
if [ -n "$RECORD" ]; then
  if xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
       --domain-identifier "$BUNDLE" --source Documents/frames.csv --destination "$RECORD" > /dev/null 2>&1 \
     && [ -s "$RECORD" ]; then
    echo "frame record: $RECORD"
    frames_report "$RECORD" "$TOP"
  else
    echo "no frame record on the device"
  fi
fi
