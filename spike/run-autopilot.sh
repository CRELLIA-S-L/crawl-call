#!/bin/sh
# Unattended spike run on the paired iPhone: install, launch with --autopilot, wait for
# the app to exit, pull the CSV, analyse. Usage: sh spike/run-autopilot.sh [minutes] [extra app args]
set -e
cd "$(dirname "$0")"
# The device and the bundle identifier never live in this file: a device UDID is personal
# data and the bundle prefix belongs to whoever builds (CON-PUB-040, concept §17.4).
# DEVICE comes from the environment; the prefix from the git-ignored Signing.xcconfig.
if [ -z "$DEVICE" ]; then
  echo "set DEVICE to the target device: DEVICE=<udid> sh $0 [minutes]" >&2
  echo "  xcrun devicectl list devices   lists them" >&2
  exit 2
fi
PREFIX=$(sed -n 's/^ *BUNDLE_ID_PREFIX *= *//p' ../Signing.xcconfig 2>/dev/null | tr -d ' \r')
BUNDLE=${PREFIX:-com.example}.chompcompany.spike
MINUTES=${1:-20}; shift 2>/dev/null || true
DD=${DD:-/tmp/spike-dd}
OUT=${OUT:-runs}
mkdir -p "$OUT"
STAMP=$(date +%Y%m%d-%H%M%S)

xcodebuild -project Spike.xcodeproj -scheme Spike -configuration Release -destination "id=$DEVICE" \
  -derivedDataPath "$DD" -allowProvisioningUpdates build 2>&1 | grep -E 'error:|BUILD' | sort -u
xcrun devicectl device install app --device "$DEVICE" "$DD/Build/Products/Release-iphoneos/Spike.app" >/dev/null

echo "launching: $MINUTES min, args: $*"
xcrun devicectl device process launch --device "$DEVICE" --console --terminate-existing "$BUNDLE" \
  --autopilot --minutes "$MINUTES" "$@" 2>&1 | grep -v 'PSO compilation' > "$OUT/$STAMP.log" || true

# The newest CSV in the app's Documents.
xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
  --source Documents --destination "$OUT/$STAMP-docs" >/dev/null 2>&1 || true
CSV=$(ls -t "$OUT/$STAMP-docs"/*.csv 2>/dev/null | head -1 || true)
[ -n "$CSV" ] && cp "$CSV" "$OUT/$STAMP.csv" && rm -rf "$OUT/$STAMP-docs"
echo "log: $OUT/$STAMP.log"; [ -n "$CSV" ] && echo "csv: $OUT/$STAMP.csv"
python3 analyze.py "$OUT/$STAMP.csv" "$OUT/$STAMP.log"
