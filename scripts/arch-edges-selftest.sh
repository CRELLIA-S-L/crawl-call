#!/bin/sh
# Proves that `scripts/arch-edges.py` reads the code by the rule ADR-0071 states, which
# is what FR-TOOL-330 asks for. No repository is needed: each case below is a tree of a
# few files under a temporary root, so what is under test is the command that ships
# rather than a description of it.
#
# file verifies: FR-TOOL-330
# Standard tools only (ART-040).
set -eu

here=$(dirname "$0")
command=$here/arch-edges.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

check() {
  if [ "$2" = "$3" ]; then printf 'ok    %s\n' "$1"
  else printf 'FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"; failures=$((failures + 1)); fi
}

# A tree is two parts, One and Two, each carrying a directory. Every case writes its own
# files into it and reads back how many edges the command found and what it said of them.
tree() {
  rm -rf "$work/tree"
  mkdir -p "$work/tree/Sources/One" "$work/tree/Sources/Two" "$work/tree/arch"
  cat > "$work/tree/arch/00-elements.md" <<'RECORDS'
# Elements

### E-010 — One

```yaml
status: built
carries: [Sources/One]
requirements: [FR-X-010]
depends_on: []
```

The first part.

### E-020 — Two

```yaml
status: built
carries: [Sources/Two]
requirements: [FR-X-020]
depends_on: []
```

The second part.
RECORDS
}

edges() { python3 "$command" --root "$work/tree" >/dev/null 2>&1; }
# `grep -c` prints a count and still leaves with 1 when the count is nought, so the
# status is dropped and the missing file is the only case that needs a stand-in.
count() { found=$(grep -c '"from"' "$work/tree/arch/edges.json" 2>/dev/null || true); printf '%s' "${found:-0}"; }
via() { sed -n 's/.*"via": "\(.*\)"/\1/p' "$work/tree/arch/edges.json"; }

# A type one part declares and the other names is an edge, and `via` says which symbol
# witnessed it, how many references the pair has and how many files they came from.
tree
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
enum User {
    static func use(_ thing: Thing) -> Thing { thing }
}
SWIFT
edges
check "a reference between parts is an edge" "$(count)" "1"
check "the witness names the symbol, the weight and the files" "$(via)" "Thing:2 — one witness of 2 reference(s) from 1 file(s)"

# Two files of the same part referring to each other is not an edge: the model is about
# what the parts lean on, and a part does not lean on itself.
tree
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/One/Neighbour.swift" <<'SWIFT'
enum Neighbour { static func use(_ thing: Thing) {} }
SWIFT
edges
check "a reference inside one part is not an edge" "$(count)" "0"

# A name inside a string literal names nothing: on 2026-10-10 "Sight line" in a piece of
# text produced an edge that did not exist.
tree
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
enum User {
    static let label = "Thing is not referred to here"
}
SWIFT
edges
check "a name in a string literal is not a reference" "$(count)" "0"

# Nor is a name in a comment, on its own line or after code, or inside a block comment.
tree
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
// Thing is described here and not used.
/* Thing again, in a block
   that runs over two lines, Thing. */
enum User {
    static let size = 1 // Thing once more
}
SWIFT
edges
check "a name in a comment is not a reference" "$(count)" "0"

# A file naming a type of its own is not referring to another part, however deep the
# type sits: `Birds` has a nested `Flight` and the squads have a `Flight` of their own.
tree
cat > "$work/tree/Sources/One/Flight.swift" <<'SWIFT'
enum Flight { case up }
SWIFT
cat > "$work/tree/Sources/Two/Birds.swift" <<'SWIFT'
struct Birds {
    struct Flight: Equatable { let number: Int }
    func flight(_ number: Int) -> Flight { Flight(number: number) }
}
SWIFT
edges
check "a file's own nested name is not a reference" "$(count)" "0"

# A name written after a dot is a member or a nested type, and what the line refers to is
# the container before the dot. The mention sits in a third file, which declares no
# `Flight` of its own, so nothing but this rule keeps it from reading as a reference to
# the other part's `Flight` — which is how `Setting/SceneryBuilder.swift` writing
# `Birds.Flight` produced an edge that did not exist.
tree
cat > "$work/tree/Sources/One/Flight.swift" <<'SWIFT'
enum Flight { case up }
SWIFT
cat > "$work/tree/Sources/Two/Birds.swift" <<'SWIFT'
struct Birds {
    struct Flight: Equatable { let number: Int }
}
SWIFT
cat > "$work/tree/Sources/Two/Keeper.swift" <<'SWIFT'
enum Keeper {
    static func hold(_ flight: Birds.Flight) {}
}
SWIFT
edges
check "a qualified name refers to its container" "$(count)" "0"

# A name two files declare belongs to neither as far as this rule goes: the mention
# cannot be attributed, so it is left out rather than guessed at.
tree
cat > "$work/tree/Sources/One/Name.swift" <<'SWIFT'
struct Name { let text: String }
SWIFT
cat > "$work/tree/Sources/Two/Name.swift" <<'SWIFT'
struct Name { let other: String }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
enum User { static func use(_ name: Name) {} }
SWIFT
edges
check "a name two files declare is not attributed" "$(count)" "0"

# A part still designed claims none of its files, so a reference to one of them resolves
# to no part and is left alone (`srs-dd/arch.md`, Designing a cut).
tree
sed 's/^status: built$/status: proposed/' "$work/tree/arch/00-elements.md" > "$work/tree/arch/records.tmp"
mv "$work/tree/arch/records.tmp" "$work/tree/arch/00-elements.md"
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
enum User { static func use(_ thing: Thing) {} }
SWIFT
edges
check "a proposed part claims nothing" "$(count)" "0"

# `--check` is what a gate runs: it says whether the file on disk is what the code says,
# and writes nothing either way.
tree
cat > "$work/tree/Sources/One/Thing.swift" <<'SWIFT'
struct Thing { let size: Int }
SWIFT
cat > "$work/tree/Sources/Two/User.swift" <<'SWIFT'
enum User { static func use(_ thing: Thing) {} }
SWIFT
edges
python3 "$command" --root "$work/tree" --check >/dev/null 2>&1
check "--check passes on a fresh file" "$?" "0"
printf '[]\n' > "$work/tree/arch/edges.json"
set +e
python3 "$command" --root "$work/tree" --check >/dev/null 2>&1
code=$?
set -e
check "--check fails on a stale file" "$code" "1"
check "--check wrote nothing" "$(cat "$work/tree/arch/edges.json")" "[]"

# A tree with no sources at all is a file with no edges, not a crash.
tree
edges
check "no sources is no edges" "$(count)" "0"

if [ "$failures" -eq 0 ]; then printf '\nall checks passed\n'; else printf '\n%s check(s) failed\n' "$failures"; exit 1; fi
