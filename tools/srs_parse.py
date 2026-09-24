#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.20.1 — the framework release this file came from
"""Reads the physical shape of a record, and nothing about its meaning.

A record is a level-three heading carrying an identifier, a fenced
`yaml` block of flat keys, and prose until the next heading. More than
one format uses that shape on purpose, so that a reader who knows one
recognises the other without learning a second syntax (ADR-0015).

This module finds the boundaries of a record and splits every field it
carries **without knowing their names or how many there are**. It
returns the identifier as written — junk included — the title, the
fields, the body and the line. What a field means, which are required,
which are retired, and whether an identifier is well-formed belong to
whoever calls it (ADR-0019).

What an identifier *looks* like is theirs too, and arrives as the
`heading` pattern: the two formats number their entries differently,
one in three parts and one in two, and neither grammar is a property
of the shape. That pattern is meant to be a broad net — anything
ID-shaped captured, junk included, judged loudly afterwards — because
a malformed identifier must never be skipped silently.

The errors it reports are the ones no caller can recover from: a
metadata line with no colon, a duplicate key, a fence that never
closes, a record with no metadata block at all.

Standard library only, compatible with Python 3.9.
"""

# annotation removed on install

import re

# The framework's version, and not this module's: one number, stamped
# by the installer into every file it writes and bumped by
# tools/srs_release.py. It lives here because this is the one file both
# checkers must have beside them — each exits 2 without it — and
# ADR-0019 refuses to let the grounds checker import srs_check, which is
# where the number used to live. Both re-export it, so everything that
# read it from there reads it still (ADR-0021).
__version__ = "0.20.1"

# annotation removed on install
# The one thing every identifier grammar shares is its tail: a number of
# three digits or more, written without a leading zero beyond the third,
# so that `0100` is not a number and `100` and `1000` are. It lives here
# because the three checkers and the viewer all read it, and a number
# that widens in one grammar and not another would part them at the
# thousandth (ADR-0028). The same is true of the order: a wider number
# sorts wrongly as a string, so every tool orders by id_key and not by
# the identifier itself.
NUMBER = r"(?:\d{3}|[1-9]\d{3,})"
RE_NUMBER_TAIL = re.compile(r"-(\d+)$")


def id_key(rid):
    """The order of identifiers: the prefix as a string, then the number
    as a number, so that FR-CORE-1000 follows FR-CORE-990 rather than
    FR-CORE-100. An identifier with no number tail sorts by itself, after
    nothing in particular."""
    match = RE_NUMBER_TAIL.search(rid)
    if not match:
        return (rid, -1)
    return (rid[:match.start()], int(match.group(1)))


RE_ANY_HEADING = re.compile(r"^#{1,6}\s")
RE_FENCE = re.compile(r"^\s*(`{3,})")
RE_FENCE_OPEN = re.compile(r"^\s*```+\s*yaml\s*$")
RE_FENCE_CLOSE = re.compile(r"^\s*```+\s*$")
RE_FENCE_BARE = re.compile(r"^\s*(`{3,})\s*$")


def fence_len(line):
    match = RE_FENCE.match(line)
    return len(match.group(1)) if match else 0


def closer_len(line):
    """Length of a bare closing fence; 0 for anything else. Per
    CommonMark a closer carries no info string, so ```python can open a
    block but never close one."""
    match = RE_FENCE_BARE.match(line)
    return len(match.group(1)) if match else 0


def skip_fence(lines, index):
    """`index` points at a fence opener; returns the index just past the
    matching closing fence (or EOF). Per CommonMark, the closer is a
    backtick run at least as long as the opener."""
    opener = fence_len(lines[index])
    index += 1
    total = len(lines)
    while index < total and closer_len(lines[index]) < opener:
        index += 1
    return index + 1


def split_fields(lines, path, line_no, errors):
    """Parses a restricted YAML subset: flat keys, scalars, bracketed lists."""
    fields = {}
    for offset, raw in enumerate(lines):
        text = raw.strip()
        if not text or text.startswith("#"):
            continue
        if ":" not in text:
            errors.append("%s:%d — metadata line without a colon: %r"
                          % (path, line_no + offset, text))
            continue
        key, _, value = text.partition(":")
        key = key.strip()
        value = value.strip()
        if key in fields:
            errors.append("%s:%d — duplicate key %r" % (path, line_no + offset, key))
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            fields[key] = [v.strip() for v in inner.split(",") if v.strip()] if inner else []
        else:
            fields[key] = value
    return fields


class Entry(object):
    """One record as the text presents it, before anything judges it."""

    def __init__(self, identifier, title, path, line):
        self.id = identifier      # exactly as written
        self.title = title
        self.path = path          # path relative to the repository root
        self.line = line          # 1-based line number of the heading
        self.fields = {}
        # Every line from the end of the metadata block to the next
        # heading, fenced blocks kept whole.
        self.body = []
        self.has_metadata = False

    @property
    def where(self):
        return "%s:%d" % (self.path, self.line)


def parse_entries(text, path, errors, heading):
    """Every record in one file already held in memory.

    `heading` is a compiled pattern matching a record's opening line,
    capturing two groups: the identifier and the title.

    Works on text rather than a path so that a caller holding a past
    revision — one read through `git show` — goes through the same
    reading as a caller holding a file.
    """
    lines = text.split("\n")

    entries = []
    index = 0
    total = len(lines)

    while index < total:
        # Fenced code blocks may contain example headings and example
        # statements; they never contribute records.
        if RE_FENCE.match(lines[index]):
            index = skip_fence(lines, index)
            continue

        match = heading.match(lines[index])
        if not match:
            index += 1
            continue

        entry = Entry(match.group(1), match.group(2).strip(), path, index + 1)
        index += 1

        # Metadata block: the first ```yaml fence before the next heading.
        meta_lines = []
        while index < total:
            if RE_ANY_HEADING.match(lines[index]):
                break
            if RE_FENCE_OPEN.match(lines[index]):
                entry.has_metadata = True
                opener = fence_len(lines[index])
                index += 1
                start = index + 1
                while index < total \
                        and not (RE_FENCE_CLOSE.match(lines[index])
                                 and fence_len(lines[index]) >= opener) \
                        and not heading.match(lines[index]):
                    meta_lines.append(lines[index])
                    index += 1
                if index < total and RE_FENCE_CLOSE.match(lines[index]) \
                        and fence_len(lines[index]) >= opener:
                    index += 1  # closing fence
                else:
                    errors.append("%s — unterminated metadata fence"
                                  % entry.where)
                entry.fields = split_fields(meta_lines, path, start, errors)
                break
            if RE_FENCE.match(lines[index]):
                # Some other fenced block before the metadata — skip it.
                index = skip_fence(lines, index)
                continue
            index += 1

        if not entry.has_metadata:
            errors.append("%s — no metadata block" % entry.where)
            entries.append(entry)
            continue

        # Body: everything to the next heading. Fenced blocks are kept
        # whole and their contents are never read — a `###` line inside
        # an example block must not end the record, or the outer loop
        # would resume on it and mint a phantom one. Where the body
        # divides, and by what marker, is the caller's business.
        body = []
        while index < total:
            if RE_FENCE.match(lines[index]):
                opener = index
                index = skip_fence(lines, index)
                body.extend(lines[opener:index])
                continue
            if RE_ANY_HEADING.match(lines[index]):
                break
            body.append(lines[index])
            index += 1
        entry.body = body

        entries.append(entry)

    return entries
