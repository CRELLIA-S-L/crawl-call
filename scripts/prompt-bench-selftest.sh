#!/bin/sh
# Checks what the prompt bench reports without calling the model (FR-TOOL-150,
# FR-TOOL-160): the report is built from `Sources/PromptBench/BenchReport.swift` alone,
# which does not import FoundationModels, together with the checks in
# `Tests/PromptBenchTests/main.swift`. Needs the Swift compiler and nothing else.
#
# file verifies: FR-TOOL-150, FR-TOOL-160
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
xcrun --sdk macosx swiftc -target arm64-apple-macos27.0 \
  "$here/Sources/PromptBench/BenchReport.swift" "$here/Tests/PromptBenchTests/main.swift" -o "$work/check"
"$work/check"
