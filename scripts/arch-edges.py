#!/usr/bin/env python3
"""Writes arch/edges.json from the Swift sources, by the rule ADR-0071 states.

The architecture layer declares what each part leans on; the checker reads imports in
Python and nothing else, so for a project written in Swift the comparison has to be fed
(`srs-dd/arch.md`, *The dependencies*). This command is what feeds it, so that the model
is compared against the code of the day rather than against a list somebody kept.

The rule, from ADR-0071:
  a type declared at the top level of a Swift file under Sources/ is that file's name;
  a mention of such a name in another file -- outside a string literal, outside a
  comment, and not a name the mentioning file declares itself -- is a reference;
  a reference between two files owned by different parts is an edge.
Nested types are excluded, because another file cannot name one without naming its
container first.

The file holds one witness per pair of parts rather than every file pair: the checker
resolves each end to its part, so one real reference per pair is all the comparison
needs, and `via` carries the weight of the edge beside it.

file implements: FR-TOOL-330
Standard library only (ART-040).
"""

import argparse
import json
import pathlib
import re
import sys

DECLARATION = re.compile(
    r"^(?:(?:public|internal|private|fileprivate|open|final|indirect)\s+)*"
    r"(?:struct|class|enum|protocol|actor|typealias)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)"
)
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def strip_noise(line):
    """The line with string literals and a trailing line comment taken out.

    A mention inside either is not a reference: "Sight line" names nothing, and a
    comment naming a type is prose about it.
    """
    out = []
    in_string = False
    index = 0
    while index < len(line):
        character = line[index]
        if in_string:
            if character == "\\":
                index += 2
                continue
            if character == '"':
                in_string = False
            index += 1
            continue
        if character == '"':
            in_string = True
            index += 1
            continue
        if line.startswith("//", index):
            break
        out.append(character)
        index += 1
    return "".join(out)


def read(path):
    """Every line of a Swift file, stripped of literals, comments and block comments."""
    lines = []
    in_block = False
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw
        if in_block:
            end = line.find("*/")
            if end < 0:
                lines.append("")
                continue
            line = line[end + 2 :]
            in_block = False
        while True:
            start = line.find("/*")
            if start < 0:
                break
            end = line.find("*/", start + 2)
            if end < 0:
                line = line[:start]
                in_block = True
                break
            line = line[:start] + " " + line[end + 2 :]
        lines.append(strip_noise(line))
    return lines


def declarations(sources):
    """Name -> the file that declares it at the top level, for names declared once.

    A name two files declare belongs to neither as far as this rule goes: a mention of
    it cannot be attributed, so it is left out rather than guessed at.
    """
    owners = {}
    contested = set()
    for path, lines in sources.items():
        for line in lines:
            if line[:1].isspace() or not line:
                continue
            found = DECLARATION.match(line)
            if not found:
                continue
            name = found.group(1)
            if name in owners and owners[name] != path:
                contested.add(name)
            owners[name] = path
    for name in contested:
        owners.pop(name, None)
    return owners


def carriers(elements_file):
    """The paths each element in force carries, longest claim first.

    The record of a part that is `proposed`, `superseded` or `withdrawn` claims nothing:
    a proposed part owns none of its files until it is built (`srs-dd/arch.md`).
    """
    text = elements_file.read_text(encoding="utf-8")
    claims = []
    for record in re.finditer(
        r"^### (E-\d+) — .+?\n\n```yaml\n(.*?)```", text, re.S | re.M
    ):
        key, body = record.group(1), record.group(2)
        status = re.search(r"^status:\s*(\w+)", body, re.M)
        if not status or status.group(1) != "built":
            continue
        listed = re.search(r"^carries:\s*\[(.*?)\]", body, re.S | re.M)
        if not listed:
            continue
        for path in listed.group(1).split(","):
            path = path.strip()
            if path:
                claims.append((path, key))
    claims.sort(key=lambda claim: len(claim[0]), reverse=True)
    return claims


def owner(path, claims):
    """The element with the most specific claim on a path, or None.

    The same resolution the checker makes: the part carrying the path itself, failing
    that the one carrying the nearest directory above it.
    """
    for claim, key in claims:
        if path == claim or path.startswith(claim.rstrip("/") + "/"):
            return key
    return None


def declared_anywhere(lines):
    """Every name a file declares, nested ones included.

    A file naming a type of its own is not referring to another part, however deep that
    type sits: `Birds` has a nested `Flight` and the squads have a `Flight` of their
    own, and the rule excludes "a type that file declares itself" (ADR-0071) without
    asking at what indentation it was written.
    """
    names = set()
    for line in lines:
        found = DECLARATION.match(line.lstrip())
        if found:
            names.add(found.group(1))
    return names


def references(sources, owners):
    """Every reference between two files, as (from, to, name, line number)."""
    found = []
    for path, lines in sources.items():
        mine = declared_anywhere(lines)
        for number, line in enumerate(lines, start=1):
            for match in WORD.finditer(line):
                name = match.group(0)
                home = owners.get(name)
                if home is None or home == path or name in mine:
                    continue
                # A name written after a dot is a member or a nested type, and the
                # container before the dot is what the line refers to: `Birds.Flight`
                # names `Birds`, not the squads' `Flight`. Nested types are excluded
                # for exactly this reason (ADR-0071).
                if match.start() and line[match.start() - 1] == ".":
                    continue
                found.append((path, home, name, number))
    return found


def edges(root):
    """The edges of the current tree, one witness per pair of parts."""
    sources = {}
    for path in sorted((root / "Sources").rglob("*.swift")):
        sources[path.relative_to(root).as_posix()] = read(path)
    owners = {
        name: home for name, home in declarations(sources).items()
    }
    claims = carriers(root / "arch" / "00-elements.md")
    pairs = {}
    for source, target, name, number in references(sources, owners):
        here, there = owner(source, claims), owner(target, claims)
        if here is None or there is None or here == there:
            continue
        pair = pairs.setdefault(
            (here, there), {"count": 0, "files": set(), "witness": None}
        )
        pair["count"] += 1
        pair["files"].add(source)
        if pair["witness"] is None:
            pair["witness"] = (source, target, name, number)
    written = []
    for (here, there), pair in sorted(pairs.items()):
        source, target, name, number = pair["witness"]
        written.append(
            {
                "from": source,
                "to": target,
                "via": "%s:%d — one witness of %d reference(s) from %d file(s)"
                % (name, number, pair["count"], len(pair["files"])),
            }
        )
    written.sort(key=lambda edge: (edge["from"], edge["to"]))
    return written


def main(argv):
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument(
        "--root",
        default=pathlib.Path(__file__).resolve().parent.parent,
        type=pathlib.Path,
        help="the repository to read, for the self-test",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="say whether the file on disk is what this command would write, and write nothing",
    )
    arguments = parser.parse_args(argv)
    root = arguments.root
    destination = root / "arch" / "edges.json"
    produced = json.dumps(edges(root), indent=2, ensure_ascii=False) + "\n"
    if arguments.check:
        held = destination.read_text(encoding="utf-8") if destination.exists() else ""
        if held == produced:
            sys.stdout.write("arch/edges.json is what the code says (%d edges).\n" % len(json.loads(produced)))
            return 0
        sys.stderr.write(
            "arch/edges.json is not what the code says — run `python3 scripts/arch-edges.py` and stage it.\n"
        )
        return 1
    destination.write_text(produced, encoding="utf-8")
    sys.stdout.write("arch/edges.json written: %d edges.\n" % len(json.loads(produced)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
