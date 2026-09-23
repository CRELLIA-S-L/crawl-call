#!/bin/sh
# Runs the test suite the way `specs/50-verification.md` says to: a simulator booted
# by identifier, the build and the run as separate commands, each under a watchdog.
#
# A phase that stops making progress is killed and reported rather than waited out —
# runs here have sat for minutes at no output and no processor, and the wait taught
# nobody anything. Standard tools only (ART-040): no `timeout`, which macOS does not
# ship, and no dependencies.
#
# implements: FR-TOOL-190
#
# Usage: scripts/run-tests.sh [simulator-udid]
#   CRAWLCALL_SIM       the simulator to use, if no argument is given
#   CRAWLCALL_TIMEOUT   seconds a phase may take before it is killed (default 180)
set -eu

SIM="${1:-${CRAWLCALL_SIM:-}}"
LIMIT="${CRAWLCALL_TIMEOUT:-180}"
DERIVED="${CRAWLCALL_DERIVED:-$PWD/.build/tests}"

if [ -z "$SIM" ]; then
  echo "no simulator given: pass a udid or set CRAWLCALL_SIM" >&2
  echo "available:" >&2
  xcrun simctl list devices available | grep -E 'iPhone.*\(' >&2
  exit 2
fi

# A watchdog around one command: run it, and if it outlives the limit, kill it and say
# what it was doing when the time ran out.
# Ends a process and the group it leads, so nothing it started is left behind.
end() {
  signal="${2:-TERM}"
  kill -"$signal" -"$1" 2>/dev/null || kill -"$signal" "$1" 2>/dev/null || true
}

# `done_when` is a pattern that means the phase has said everything it was going to.
# xcodebuild has been seen finishing a suite — printing its counts and its verdict —
# and then sitting blocked at no processor until something kills it, which turned a
# five-second run into a nine-minute wait and lost the result with it. When the log
# says the work is over, the process is ended and the log is what the run reports.
watch() {
  phase="$1"; done_when="$2"; shift 2
  started=$(date +%s)
  # Job control gives the command its own process group, so that ending a phase ends
  # everything it started. Killing the process alone leaves the children orphaned —
  # xcodebuild's are a tree, and a `sleep` outliving its shell is how this was found.
  set -m
  "$@" > "$DERIVED/$phase.log" 2>&1 &
  pid=$!
  set +m
  while kill -0 "$pid" 2>/dev/null; do
    if [ -n "$done_when" ] && grep -qE "$done_when" "$DERIVED/$phase.log" 2>/dev/null; then
      sleep 1                      # let the last lines land
      end "$pid"
      finished=$(date +%s)
      echo "$phase: $((finished - started))s (ended by its own report)"
      return 0
    fi
    now=$(date +%s)
    if [ $((now - started)) -ge "$LIMIT" ]; then
      state=$(ps -o stat=,%cpu= -p "$pid" 2>/dev/null | tr -s ' ')
      end "$pid"
      sleep 2
      end "$pid" KILL
      echo "TIMEOUT  $phase gave up after ${LIMIT}s (process was:${state:-gone})" >&2
      echo "         last of its output:" >&2
      tail -5 "$DERIVED/$phase.log" >&2
      return 124
    fi
    sleep 2
  done
  wait "$pid" 2>/dev/null || status=$?
  finished=$(date +%s)
  echo "$phase: $((finished - started))s"
  return "${status:-0}"
}

mkdir -p "$DERIVED"
echo "simulator ${SIM%%-*}…, watchdog ${LIMIT}s, derived data $DERIVED"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b > /dev/null

watch build '^\*\* TEST BUILD (SUCCEEDED|FAILED)' xcodebuild -project CrawlCall.xcodeproj -scheme CrawlCall \
  -destination "id=$SIM" -derivedDataPath "$DERIVED" build-for-testing
grep -E '^\*\* TEST BUILD (SUCCEEDED|FAILED)' "$DERIVED/build.log" || true

watch tests '^\*\* TEST (SUCCEEDED|FAILED)' xcodebuild -project CrawlCall.xcodeproj -scheme CrawlCall \
  -destination "id=$SIM" -derivedDataPath "$DERIVED" test-without-building
grep -E 'Executed [0-9]+ tests|^\*\* TEST (SUCCEEDED|FAILED)' "$DERIVED/tests.log" | tail -2
grep -E "Test Case.*failed \(" "$DERIVED/tests.log" | sed 's/.*CrawlCallTests\.//' | sort -u || true
