#!/bin/sh
# Proves that `scripts/run-on-device.sh` closes the app it launched whatever happens
# to the run, which is what FR-TOOL-180 asks for. No device and no app: `xcrun` is
# replaced on the path by one that records what it was asked to do, so what is under
# test is the script that ships rather than a description of it.
#
# file verifies: FR-TOOL-180, FR-TOOL-250
# Standard tools only (ART-040).
set -eu

here=$(dirname "$0")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

check() {
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"; failures=$((failures + 1)); fi
}

# An app is an Info.plist with a bundle identifier in it; the script reads it with
# `plutil`, so the real one is used here rather than a fake.
mkdir -p "$work/Fake.app" "$work/bin"
cat > "$work/Fake.app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>test.crawlcall.fake</string>
</dict></plist>
PLIST

# The stand-in for `xcrun`: it writes down every call, and each knob below makes one
# of them fail, which is how the paths that stop early are reached.
cat > "$work/bin/xcrun" <<'FAKE'
#!/bin/sh
echo "$*" >> "$FAKELOG"
json=""; prev=""
for a in "$@"; do
  case "$prev" in
    --json-output) json="$a" ;;
    --destination) dest="$a" ;;
  esac
  prev="$a"
done
case "$*" in
  *"install app"*)
    exit "${FAKE_INSTALL_FAILS:-0}" ;;
  *"process launch"*)
    printf '{"result":{"process":{"processIdentifier":4321}}}' > "$json" ;;
  *"capture screenshot"*)
    [ "${FAKE_SHOT_FAILS:-0}" = 0 ] || exit 1
    : > "$dest" ;;
  *"info processes"*)
    [ "${FAKE_STILL_UP:-0}" = 0 ] || echo "test.crawlcall.fake  4321" ;;
  *"copy from"*)
    [ -n "${FAKE_RECORD:-}" ] || exit 1
    cp "$FAKE_RECORD" "$dest" ;;
esac
exit 0
FAKE
chmod +x "$work/bin/xcrun"
PATH="$work/bin:$PATH"
export PATH
export CRAWLCALL_DEVICE=fake-device
export CRAWLCALL_WATCH=0

run() {
  FAKELOG="$work/$1.log"; export FAKELOG
  : > "$FAKELOG"
  shift
  if sh "$here/run-on-device.sh" "$@" > "$work/out.txt" 2>&1; then echo 0; else echo $?; fi
}

# 1. The run that goes well closes the app, and says so last: nothing is reported
#    after the app is still up.
code=$(run happy "$work/Fake.app" "$work/shot.png")
check "a run that goes well succeeds" "$code" "0"
check "it terminated the process it launched" \
  "$(grep -c 'process terminate .* --pid 4321' "$work/happy.log")" "1"
check "it asked the device whether the app had gone" \
  "$(grep -c 'info processes' "$work/happy.log")" "1"
check "the last thing it reports is that the app is closed" "$(tail -1 "$work/out.txt")" "closed"
check "it took the screenshot it was asked for" "$([ -f "$work/shot.png" ] && echo yes || echo no)" "yes"
# The terminate comes before the question about what is still running, or the answer
# would be about a process nobody had ended.
terminate=$(grep -n 'process terminate' "$work/happy.log" | cut -d: -f1)
asked=$(grep -n 'info processes' "$work/happy.log" | cut -d: -f1)
[ "$terminate" -lt "$asked" ] \
  || { echo "FAIL  it asked whether the app had gone before ending it"; failures=$((failures + 1)); }

# 2. A run that stops early — the screenshot fails — still closes the app. This is
#    the path FR-TOOL-180 is written for, and the one the spike's instrument missed.
export FAKE_SHOT_FAILS=1
code=$(run early "$work/Fake.app" "$work/none.png")
check "a run that stops early fails" "$([ "$code" = 0 ] && echo no || echo yes)" "yes"
check "and closes the app on its way out" \
  "$(grep -c 'process terminate .* --pid 4321' "$work/early.log")" "1"
check "and still reports the app closed" "$(grep -c '^closed$' "$work/out.txt")" "1"
unset FAKE_SHOT_FAILS

# 3. Nothing was launched, so nothing is terminated: a trap that fired blindly would
#    be ending somebody else's process.
export FAKE_INSTALL_FAILS=1
code=$(run noinstall "$work/Fake.app")
check "a run that cannot install fails" "$([ "$code" = 0 ] && echo no || echo yes)" "yes"
check "and terminates nothing" "$(grep -c 'process terminate' "$work/noinstall.log")" "0"
unset FAKE_INSTALL_FAILS

# 4. The device still listing the app is reported as such, or "closed" would be a
#    word the script prints rather than a fact it checked.
export FAKE_STILL_UP=1
code=$(run stillup "$work/Fake.app")
check "an app that is still there is not called closed" "$(tail -1 "$work/out.txt")" "STILL RUNNING"
check "and the run fails, because the next measurement is on a warm device" \
  "$([ "$code" = 0 ] && echo no || echo yes)" "yes"
unset FAKE_STILL_UP

# 5. The device is named by the environment; without it the run refuses rather than
#    guessing, and installs nothing. Refusing is the point: a default device baked in
#    here is how an identifier gets into the repository.
FAKELOG="$work/nodevice.log"; export FAKELOG; : > "$FAKELOG"
if CRAWLCALL_DEVICE= sh "$here/run-on-device.sh" "$work/Fake.app" > "$work/out.txt" 2>&1; then code=0; else code=$?; fi
check "a run with no device refuses" "$code" "2"
check "and installs nothing" "$(grep -c 'install app' "$work/nodevice.log")" "0"

# 6. The frame record's summary (FR-TOOL-250), taken from the runner like the rest.
cat > "$work/frames.csv" <<'CSV'
frame,time_ms,interval_ms,step_ms,deliberation_ms,see_through_ms,draw_ms,thermal,events
1,0.000,16.667,0.400,0.000,0.100,0.200,nominal,match_began
2,16.700,25.000,0.500,0.000,0.100,0.200,nominal,
3,33.400,25.001,0.500,0.000,0.100,0.200,fair,
4,50.100,100.000,12.000,11.500,0.300,0.200,serious,deliberation*2;first_hole
5,66.800,33.300,0.500,0.000,9.000,0.200,fair,look_changed
CSV
sed -n '/^LATE_MS=/p;/^frames_report() {/,/^}/p' "$here/run-on-device.sh" > "$work/report.sh"
grep -q '^frames_report() {' "$work/report.sh" || { echo "FAIL  the runner has no frames_report() to test"; exit 1; }
( . "$work/report.sh"; frames_report "$work/frames.csv" 2 ) > "$work/report.txt"
check "it counts the frames" "$(grep -c '^frames: 5,' "$work/report.txt")" "1"
# 25.000 is on the line and not late; 25.001, 33.3 and 100 are.
check "late is more than 25 ms, not 25 itself" "$(grep -c 'late (over 25 ms): 3$' "$work/report.txt")" "1"
# By number, not by text: 100 comes before 33.3, as "100" would not.
check "it counts the frames in each thermal state, in the order they came" \
  "$(sed -n 2p "$work/report.txt")" "thermal: nominal 2, fair 2, serious 1"
check "the slowest comes first" "$(sed -n 3p "$work/report.txt" | grep -c 'frame 4 at 50.100 ms: interval 100.000')" "1"
check "then the next slowest" "$(sed -n 4p "$work/report.txt" | grep -c 'frame 5 ')" "1"
check "and no more than asked" "$(wc -l < "$work/report.txt" | tr -d ' ')" "4"
check "with where its time went, how hot the device was and what happened in it" \
  "$(sed -n 3p "$work/report.txt" | grep -c 'step 12.000 (deliberation 11.500), see-through 0.300, draw 0.200, thermal serious — deliberation\*2;first_hole')" "1"

# 7. A run asked for the record switches it on in the app, takes it off the device
#    after the app has gone — the app writes it when it is terminated — and sums it up.
export CRAWLCALL_RECORD="$work/taken.csv" FAKE_RECORD="$work/frames.csv"
code=$(run record "$work/Fake.app")
check "a recorded run succeeds" "$code" "0"
check "it launched the app with the record switched on" \
  "$(grep -c 'process launch .*--environment-variables {"CRAWLCALL_FRAMES":"1"}' "$work/record.log")" "1"
check "it took the record from the app's container" \
  "$(grep -c 'copy from .*--domain-type appDataContainer --domain-identifier test.crawlcall.fake --source Documents/frames.csv' "$work/record.log")" "1"
terminate=$(grep -n 'process terminate' "$work/record.log" | cut -d: -f1)
copied=$(grep -n 'copy from' "$work/record.log" | cut -d: -f1)
[ "$terminate" -lt "$copied" ] \
  || { echo "FAIL  it took the record before the app had written it on its way out"; failures=$((failures + 1)); }
check "and printed its summary" "$(grep -c '^frames: 5, late (over 25 ms): 3$' "$work/out.txt")" "1"
unset FAKE_RECORD

# 8. No record on the device is said, and the run still succeeds: a run need not have
#    one (FR-TOOL-250, "where there is one").
code=$(run norecord "$work/Fake.app")
check "a run with no record on the device still succeeds" "$code" "0"
check "and says there was none" "$(tail -1 "$work/out.txt")" "no frame record on the device"
unset CRAWLCALL_RECORD

# 9. A run not asked for the record does not switch it on.
code=$(run plain "$work/Fake.app")
check "a plain run launches without the record" "$(grep -c 'environment-variables' "$work/plain.log")" "0"
check "and takes nothing off the device" "$(grep -c 'copy from' "$work/plain.log")" "0"

[ "$failures" -eq 0 ] && echo "device runner self-test passed" || echo "$failures check(s) failed"
exit "$failures"
