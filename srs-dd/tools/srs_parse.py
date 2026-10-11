#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""Reads the physical shape of a record — heading, fenced `yaml` block, body —
and nothing about its meaning: field names, required keys and well-formed
identifiers belong to the caller. It reports only what no
caller can recover from: a metadata line without a colon, a duplicate key, an
unterminated fence, a record with no metadata block.

Standard library only, compatible with Python 3.9.
"""

# file annotation removed on install

import re

# The framework's version, not this module's, kept in the one file every checker
# must have beside it; each re-exports it.
__version__ = "0.24.0"

# annotation removed on install
# What every identifier grammar shares: a tail of three digits or more, no
# leading zero beyond the third, so `0100` is not a number.
NUMBER = r"(?:\d{3}|[1-9]\d{3,})"
# annotation removed on install
# annotation removed on install
# An area's name: uppercase words joined by single underscores, never by the
# hyphen that separates an identifier's segments.
AREA = r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*"
# annotation removed on install
RE_NUMBER_TAIL = re.compile(r"-(\d+)$")


def id_key(rid):
    """Prefix as a string, number as a number, so FR-CORE-1000 follows FR-CORE-990
    rather than FR-CORE-100."""
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
    """Length of a bare closing fence; 0 for anything else — per CommonMark a closer
    carries no info string."""
    match = RE_FENCE_BARE.match(line)
    return len(match.group(1)) if match else 0


def skip_fence(lines, index):
    """From a fence opener to just past its closer, which per CommonMark is a backtick
    run at least as long."""
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
    """Every record in one file already held in memory; text rather than a path, so a
    past revision is read the same way.

    `heading` captures the identifier and the title, and is meant to be a broad net:
    anything ID-shaped is captured for the caller to judge loudly.
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

        # Body: everything to the next heading, fenced blocks kept whole and unread —
        # a `###` inside an example would otherwise mint a phantom record.
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
