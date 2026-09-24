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

# What a run prints at its end, and how it exits (FR-TOOL-210). Both read the phase's
# log rather than trusting the process's status: the process is the one seen hanging
# after its verdict (FR-TOOL-190). `-a` because a log is text even where a test put
# an odd byte into it, and grep would otherwise answer "binary file matches".
#
# implements: FR-TOOL-210

# The build's verdict, and its errors where it failed. Returns 0 where it succeeded.
build_report() {
  log="$1"; status="$2"
  LC_ALL=C grep -aE '^\*\* TEST BUILD (SUCCEEDED|FAILED)' "$log" || true
  if [ "$status" -eq 0 ] && LC_ALL=C grep -qaE '^\*\* TEST BUILD SUCCEEDED' "$log"; then return 0; fi
  echo "build failed; its errors:" >&2
  LC_ALL=C grep -aE ': error: ' "$log" | sort -u | head -40 >&2 || true
  [ "$status" -ne 0 ] && return "$status"
  return 65
}

# The count of tests run and failed, and the name of each that failed. Returns 0 only
# where the log counts the whole suite and no failure in it.
tests_report() {
  log="$1"; status="$2"
  summary=$(LC_ALL=C grep -aE 'Executed [0-9]+ tests?, with [0-9]+ failures?' "$log" | tail -1)
  if [ -z "$summary" ]; then
    echo "no test count in the log: the suite did not report" >&2
    [ "$status" -ne 0 ] && return "$status"
    return 1
  fi
  echo "$summary"
  LC_ALL=C grep -aE "Test Case .*failed \(" "$log" | sed 's/.*CrawlCallTests\.//' | sort -u >&2 || true
  case "$summary" in
    *"with 0 failures"*) return 0 ;;
    *) return 65 ;;
  esac
}

# The build's warnings about the project's own files and settings, and how many
# (FR-TOOL-220, ART-080): a line that starts with a path inside the repository, or a
# setting's warning that names this project's target. Notices of Xcode's own tools
# carry a timestamp and name no file of ours, so they are not among them. Printed,
# never failed: the maintainer's choice.
#
# implements: FR-TOOL-220
warnings_report() {
  log="$1"; root="$2"
  found=$(LC_ALL=C grep -aE "^$root/[^ ]+: warning: |^warning: .*\(in target '[^']+' from project 'CrawlCall'\)" "$log" \
            | sed "s|^$root/||" | sort -u)
  if [ -z "$found" ]; then
    echo "build warnings: 0"
  else
    echo "build warnings: $(printf '%s\n' "$found" | wc -l | tr -d ' ')"
    printf '%s\n' "$found"
  fi
}

build_status=0
watch build '^\*\* TEST BUILD (SUCCEEDED|FAILED)' xcodebuild -project CrawlCall.xcodeproj -scheme CrawlCall \
  -destination "id=$SIM" -derivedDataPath "$DERIVED" build-for-testing || build_status=$?
build_report "$DERIVED/build.log" "$build_status" || exit $?
warnings_report "$DERIVED/build.log" "$PWD"

# The suite's own last line ends the phase too: with failing tests xcodebuild has been
# seen printing it and its counts, then hanging without the `** TEST FAILED` verdict.
tests_status=0
watch tests "^\*\* TEST (SUCCEEDED|FAILED)|^Test Suite 'All tests' (passed|failed)" \
  xcodebuild -project CrawlCall.xcodeproj -scheme CrawlCall \
  -destination "id=$SIM" -derivedDataPath "$DERIVED" test-without-building || tests_status=$?
tests_report "$DERIVED/tests.log" "$tests_status"
