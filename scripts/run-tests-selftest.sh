#!/bin/sh
# Proves the watchdog in `scripts/run-tests.sh` does what FR-TOOL-190 says: ends a
# phase that outlives its limit, and reports which one, how long it had, and what the
# process was doing. Standard tools only (ART-040).
#
# file verifies: FR-TOOL-190, FR-TOOL-210, FR-TOOL-220
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

# 4. What a run prints at its end and how it exits (FR-TOOL-210), taken from the
# runner like the watchdog and fed logs of each kind of ending.
sed -n '/^build_report() {/,/^}/p;/^tests_report() {/,/^}/p' "$here/run-tests.sh" > "$work/report.sh"
grep -q '^tests_report() {' "$work/report.sh" || { echo "FAIL  the runner has no tests_report() to test"; exit 1; }
. "$work/report.sh"

printf "Test Suite 'All tests' failed at now.\n\t Executed 12 tests, with 2 failures (0 unexpected) in 1.0 (1.0) seconds\n" > "$work/failed.log"
printf "Test Case '-[CrawlCallTests.ATests testOne]' failed (0.1 seconds).\nTest Case '-[CrawlCallTests.BTests testTwo]' failed (0.1 seconds).\n" >> "$work/failed.log"
if tests_report "$work/failed.log" 124 > "$work/failed.out" 2>&1; then got=0; else got=$?; fi
check "a run with failures exits non-zero though its watchdog cut it short" "$got" "65"
check "and prints its count" "$(grep -c 'Executed 12 tests, with 2 failures' "$work/failed.out")" "1"
check "and names each failed test" "$(grep -cE 'ATests testOne|BTests testTwo' "$work/failed.out")" "2"

printf "Test Suite 'All tests' passed at now.\n\t Executed 12 tests, with 0 failures (0 unexpected) in 1.0 (1.0) seconds\n** TEST SUCCEEDED **\n" > "$work/passed.log"
if tests_report "$work/passed.log" 124 > "$work/passed.out" 2>&1; then got=0; else got=$?; fi
check "a run that counted every test passing exits zero, hang or not" "$got" "0"

printf "Test Suite 'All tests' failed at now.\n\t Executed 12 tests, with 3 tests skipped and 3 failures (3 unexpected) in 1.0 (1.0) seconds\n" > "$work/skipped.log"
printf "Test Case '-[CrawlCallTests.CTests testThree]' failed (0.1 seconds).\n" >> "$work/skipped.log"
if tests_report "$work/skipped.log" 0 > "$work/skipped.out" 2>&1; then got=0; else got=$?; fi
check "a run whose count has skipped tests in it is read, and fails" "$got" "65"
check "and prints that count" "$(grep -c 'with 3 tests skipped and 3 failures' "$work/skipped.out")" "1"
check "and names the failed test" "$(grep -c 'CTests testThree' "$work/skipped.out")" "1"
printf "Test Suite 'All tests' passed at now.\n\t Executed 12 tests, with 2 tests skipped and 0 failures (0 unexpected) in 1.0 (1.0) seconds\n" > "$work/skiponly.log"
if tests_report "$work/skiponly.log" 0 > "$work/skiponly.out" 2>&1; then got=0; else got=$?; fi
check "a run with skipped tests and no failures is not a pass" "$got" "65"

printf "Test Suite 'All tests' started\n" > "$work/silent.log"
if tests_report "$work/silent.log" 0 > "$work/silent.out" 2>&1; then got=0; else got=$?; fi
check "a run with no count in its log is not a pass" "$got" "1"

# Cut off between the whole suite's verdict and its count: the last count in the log
# is one suite's, and a failure in another must not pass for want of the total.
{
  printf "Test Suite 'ATests' failed at now.\n\t Executed 2 tests, with 1 failure (0 unexpected) in 0.1 (0.1) seconds\n"
  printf "Test Suite 'BTests' passed at now.\n\t Executed 3 tests, with 0 failures (0 unexpected) in 0.1 (0.1) seconds\n"
  printf "Test Suite 'All tests' failed at now.\n"
} > "$work/cut.log"
if tests_report "$work/cut.log" 0 > "$work/cut.out" 2>&1; then got=0; else got=$?; fi
check "a run cut off before the whole suite's count is not a pass" "$got" "1"

# A test that prints an odd byte makes grep call the whole log binary and answer
# "Binary file matches" in place of the line — which would fail a run that passed.
printf "\0odd byte\nTest Suite 'All tests' passed at now.\n\t Executed 3 tests, with 0 failures (0 unexpected) in 1.0 (1.0) seconds\n" > "$work/binary.log"
if tests_report "$work/binary.log" 0 > "$work/binary.out" 2>&1; then got=0; else got=$?; fi
check "a passing log with an odd byte in it still passes" "$got" "0"
check "and prints its count, not a binary-file notice" "$(grep -c 'Executed 3 tests' "$work/binary.out")" "1"

printf "/x/A.swift:3:5: error: cannot find 'q' in scope\n** TEST BUILD FAILED **\n" > "$work/build.log"
if build_report "$work/build.log" 0 > "$work/build.out" 2>&1; then got=0; else got=$?; fi
check "a failed build is a failure even when its process said nothing" "$got" "65"
check "and prints its errors" "$(grep -c "cannot find 'q' in scope" "$work/build.out")" "1"

# 5. The build's warnings about the project, and only those (FR-TOOL-220).
sed -n '/^warnings_report() {/,/^}/p' "$here/run-tests.sh" > "$work/warnings.sh"
grep -q '^warnings_report() {' "$work/warnings.sh" || { echo "FAIL  the runner has no warnings_report() to test"; exit 1; }
. "$work/warnings.sh"
root=/repo
{
  echo "/repo/Tests/A.swift:3:5: warning: variable 'x' was never used"
  echo "/repo/Tests/A.swift:3:5: warning: variable 'x' was never used"
  echo "    |- warning: a note under the first, not a warning of its own"
  echo "warning: 'UIOldKey' has been deprecated (in target 'CrawlCall' from project 'CrawlCall')"
  echo "2026-09-24 17:06:49.798 appintentsmetadataprocessor[1:2] warning: Metadata extraction skipped"
  echo "/elsewhere/Lib.swift:1:1: warning: not ours"
} > "$work/warned.log"
warnings_report "$work/warned.log" "$root" > "$work/warned.out"
check "the project's warnings are counted once each" "$(head -1 "$work/warned.out")" "build warnings: 2"
check "a file's warning is named by its path in the repository" "$(grep -c '^Tests/A.swift:3:5: warning' "$work/warned.out")" "1"
check "a setting's warning is named" "$(grep -c 'UIOldKey' "$work/warned.out")" "1"
check "a tool's notice is not among them" "$(grep -c 'appintents' "$work/warned.out")" "0"
echo "/repo/A.swift:1:1: error: nothing to warn about here" > "$work/clean.log"
check "a build with none says so" "$(warnings_report "$work/clean.log" "$root")" "build warnings: 0"

[ "$failures" -eq 0 ] && echo "watchdog self-test passed" || echo "$failures check(s) failed"
exit "$failures"
