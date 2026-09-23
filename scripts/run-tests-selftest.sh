#!/bin/sh
# Proves the watchdog in `scripts/run-tests.sh` does what FR-TOOL-190 says: ends a
# phase that outlives its limit, and reports which one, how long it had, and what the
# process was doing. Standard tools only (ART-040).
#
# verifies: FR-TOOL-190
set -eu

here=$(dirname "$0")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

check() {
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"; failures=$((failures + 1)); fi
}

# The watchdog is the part under test, so it is taken from the runner rather than
# rewritten here: a copy that drifted would prove nothing about what ships.
sed -n '/^end() {/,/^}/p;/^watch() {/,/^}/p' "$here/run-tests.sh" > "$work/watch.sh"
grep -q '^watch() {' "$work/watch.sh" || { echo "FAIL  the runner has no watch() to test"; exit 1; }
grep -q '^end() {' "$work/watch.sh" || { echo "FAIL  the runner has no end() to test"; exit 1; }

DERIVED="$work"
. "$work/watch.sh"

# 1. A command that finishes inside its limit passes and reports its time.
LIMIT=10
started=$(date +%s)
if watch quick "" sleep 1 > "$work/quick.out" 2>&1; then quick=0; else quick=$?; fi
elapsed=$(( $(date +%s) - started ))
check "a quick phase succeeds" "$quick" "0"
check "a quick phase reports its own time" "$(grep -c 'quick: [0-9]*s' "$work/quick.out")" "1"
[ "$elapsed" -lt 8 ] || { echo "FAIL  a one-second phase took ${elapsed}s"; failures=$((failures + 1)); }

# 2. A command that outlives its limit is killed, and says so.
LIMIT=3
started=$(date +%s)
if watch stuck "" sleep 60 > "$work/stuck.out" 2>&1; then stuck=0; else stuck=$?; fi
elapsed=$(( $(date +%s) - started ))
check "a stuck phase fails with the timeout code" "$stuck" "124"
check "the report names the phase" "$(grep -c 'TIMEOUT  stuck' "$work/stuck.out")" "1"
check "the report names the limit" "$(grep -c 'after 3s' "$work/stuck.out")" "1"
check "the report says what the process was doing" "$(grep -c 'process was:' "$work/stuck.out")" "1"
[ "$elapsed" -lt 12 ] || { echo "FAIL  the watchdog took ${elapsed}s to give up on a 3s limit"; failures=$((failures + 1)); }
# Nothing the phase started may outlive it, children included: the command below
# leaves a sleeping child behind if only its own process is signalled.
LIMIT=3
watch orphan "" sh -c 'sleep 90 & wait' > "$work/orphan.out" 2>&1 || true
sleep 1
if pgrep -f 'sleep 90' > /dev/null 2>&1; then
  echo "FAIL  a child of the stuck phase is still running"; failures=$((failures + 1))
  pkill -f 'sleep 90' 2>/dev/null || true
else
  echo "ok    the stuck phase took its children with it"
fi

# 3. A phase that says it is done is ended on its own word, not waited out.
LIMIT=30
started=$(date +%s)
if watch spoken 'FINISHED' sh -c 'echo FINISHED; sleep 60' > "$work/spoken.out" 2>&1; then spoken=0; else spoken=$?; fi
elapsed=$(( $(date +%s) - started ))
check "a phase that reports completion succeeds" "$spoken" "0"
check "and says it ended on its own report" "$(grep -c 'ended by its own report' "$work/spoken.out")" "1"
[ "$elapsed" -lt 15 ] || { echo "FAIL  waited ${elapsed}s for a phase that had already reported"; failures=$((failures + 1)); }

[ "$failures" -eq 0 ] && echo "watchdog self-test passed" || echo "$failures check(s) failed"
exit "$failures"
