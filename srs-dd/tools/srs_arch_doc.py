#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""The architecture document: what the layer holds, written for a person to read.

    python3 srs-dd/tools/srs_arch_doc.py              print the document
    python3 srs-dd/tools/srs_arch_doc.py > ARCH.md    put it where you want it
    python3 srs-dd/tools/srs_arch_doc.py --html       the same document as one page
    python3 srs-dd/tools/srs_arch_doc.py --html --link index.html,grounds.html
                                                     and the pages beside it

A projection of `arch/` and of what the specification says about it — the parts with their
responsibilities and obligations, the dependencies they declare as a Mermaid drawing, the
dependencies the code has and they do not, and what the layer leaves unsaid. It writes
nothing: where the document lands is the caller's.

Not a gate: the checker says what is wrong with the layer, this says what the layer holds.
Standard library only, compatible with Python 3.9.
"""
# file annotation removed on install
# file annotation removed on install
import os
import re
import sys

sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import srs_arch
except ImportError:
    sys.stderr.write("srs-dd/tools/srs_arch.py is not beside this file; the document is a "
                     "projection of what it reads\n")
    sys.exit(2)

__version__ = srs_arch.__version__


def in_force(elements):
    """The elements a reader is being told about: well-formed, and not dissolved."""
    return [r for r in elements if srs_arch.RE_ID.match(r.id)
            and r.fields.get("status") not in srs_arch.CANCELLED]


def responsibility(record):
    """The record's own sentence about what the part is for: its body down to the rationale."""
    out = []
    for line in record.body:
        if line.strip().startswith("**Rationale."):
            break
        out.append(line.strip())
    return " ".join(part for part in out if part)


# annotation removed on install
def parts_section(elements, moves, model, cfg):
    """Every element in force: what it is, what it carries, what it answers for, what moves."""
    titles = {r["id"]: r.get("title", "") for r in model["requirements"]}
    written, computed = srs_arch.carried_by(elements, model, cfg)
    order = srs_arch.spec_order(model)
    inside = srs_arch.sits_inside(elements)
    responsibility_of = {r.id: r.title for r in elements}
    out = ["## What the system is made of", ""]
    # annotation removed on install
    if not in_force(elements):
        return out + ["_No part is written down yet: the layer is installed and empty._", ""]
    # annotation removed on install
    for record in sorted(elements, key=lambda r: srs_arch.srs_parse.id_key(r.id)):
        if record.fields.get("status") in srs_arch.CANCELLED:
            continue
        out += ["### %s — %s" % (record.id, record.title), "",
                "%s" % (responsibility(record) or "_Not determined: the record says nothing._"), "",
                "- **Status:** `%s`" % (record.fields.get("status") or "?")]
        carries = srs_arch.as_list(record.fields.get("carries"))
        out.append("- **Carries:** %s" % (", ".join("`%s`" % p for p in carries) or "_nothing_"))
        interface = record.fields.get("interface")
        out.append("- **Interface:** %s" % (interface or "_Not determined._"))
        # annotation removed on install
        for other in inside.get(record.id, ()):
            out.append("- **Inside:** %s — %s" % (other, responsibility_of.get(other, "")))
        # annotation removed on install
        # annotation removed on install
        # The two or three a part was cut to keep, before the forty it merely carries: this is
        # the answer to what breaks if the boundary moves. Absent where the record names none.
        protects = srs_arch.as_list(record.fields.get("protects"))
        if protects:
            out.append("- **Exists to protect:**")
            for rid in sorted(protects, key=order):
                out.append("  - %s — %s" % (rid, titles.get(rid, "_unknown to the specification_")))
        # annotation removed on install
        held = sorted(written[record.id] | computed[record.id], key=order)
        out.append("- **Answers for %d requirement(s):**" % len(held))
        for rid in held:
            out.append("  - %s — %s" % (rid, titles.get(rid, "_unknown to the specification_")))
        touching = [m for m in moves
                    if record.id in srs_arch.as_list(m.fields.get("from"))
                    + srs_arch.as_list(m.fields.get("to"))]
        for move in touching:
            out.append("- **Moving:** %s — %s (`%s`)"
                       % (move.id, move.title, move.fields.get("status") or "?"))
        out.append("")
    return out
# annotation removed on install


# annotation removed on install
def units_section(elements):
    """The units the parts ship in, each with what it holds, and where the facts came from.

    The units exist only as names scattered across the records, so the one view in which the
    pieces of the running system are visible has to be computed. The provenance stands beside
    them because a reader judging a disagreement needs to know what the model was compared
    against, and a finding cannot say that on its own.
    """
    held = srs_arch.units_of(in_force(elements))
    if not held:
        return []
    out = ["## The units", "",
           "What this system is deployed or run as, by the names the project uses; what each "
           "unit holds is computed from the parts that name it.", ""]
    for name in sorted(held):
        out.append("- **%s** — %s" % (name, ", ".join(held[name])))
    out.append("")
    facts, problem, stale = srs_arch.load_units_file()
    if problem:
        out += ["The facts about these units could not be read: %s" % problem, ""]
    elif stale:
        out += ["%s." % stale[0].upper() + stale[1:], ""]
    elif facts:
        life = ("their producer says they stay true for %d day(s)" % facts["life"]
                if facts["life"] is not None
                else "their producer says nothing about how long they stay true")
        out += ["Facts taken %s from %s; %s." % (facts["taken"], facts["source"], life), ""]
    else:
        out += ["No facts about these units were supplied, so nothing here was compared with "
                "what runs.", ""]
    return out
# annotation removed on install


# annotation removed on install
def order_section(elements, cfg):
    """The order of the parts, where the project declared one: the groups in their own sequence,
    what each holds, and the parts the order does not place.

    Absent where no order is declared, as every optional section here is. A part outside the order
    is said out loud: it is unconstrained, which is either deliberate or an adoption half done.
    """
    if not cfg["layers"]:
        return []
    titles = {r.id: r.title for r in in_force(elements)}
    out = ["## The order of the parts", "",
           "Read top down: a part may lean on its own group and on any group below it. "
           "A dependency running upward is what the checker reports.", ""]
    for index, group in enumerate(cfg["layers"]):
        held = [eid for eid in group if eid in titles]
        out.append("%d. %s" % (index, ", ".join("**%s** %s" % (eid, titles[eid]) for eid in held)
                               or "_no part in force_"))
    placed = {eid for group in cfg["layers"] for eid in group}
    loose = sorted((eid for eid in titles if eid not in placed),
                   key=srs_arch.srs_parse.id_key)
    out += [""]
    if loose:
        out += ["Outside the order, and so unconstrained by it: "
                + ", ".join("**%s** %s" % (eid, titles[eid]) for eid in loose) + ".", ""]
    return out
# annotation removed on install


# annotation removed on install
def drawing_section(elements):
    """The declared dependencies as Mermaid: text a forge, an editor or a wiki renders itself."""
    live = in_force(elements)
    declared = srs_arch.declared_dependencies(elements)
    out = ["## How the parts depend on each other", ""]
    # annotation removed on install
    # No block at all rather than one holding its own declaration: a forge renders that as an
    # error, which reads as a broken generator.
    if not live:
        return out + ["_Nothing to draw: no part is written down yet._", ""]
    # annotation removed on install
    out += ["What the elements declare, not what the code does — the two are compared below.", "",
            "```mermaid", "flowchart TD"]
    for record in sorted(live, key=lambda r: srs_arch.srs_parse.id_key(r.id)):
        out.append('    %s["%s %s"]' % (record.id.replace("-", "_"), record.id, record.title))
    edges = 0
    for record in sorted(live, key=lambda r: srs_arch.srs_parse.id_key(r.id)):
        for target in sorted(declared.get(record.id, ()), key=srs_arch.srs_parse.id_key):
            out.append("    %s --> %s" % (record.id.replace("-", "_"), target.replace("-", "_")))
            edges += 1
    out += ["```", "",
            "%d part(s), %d declared dependency(ies)." % (len(live), edges), ""]
    return out
# annotation removed on install


# annotation removed on install
def divergence_section(elements, edges, cfg):
    """Where the code disagrees with the model, from the checker's own computation."""
    warnings, reports = [], []
    quiet = dict(cfg)
    quiet["rules"] = dict(cfg["rules"])
    quiet["rules"]["dependency-undeclared"] = "warn"
    srs_arch.check_conformance(elements, edges, warnings, reports, quiet)
    out = ["## Where the code disagrees with the model", ""]
    # annotation removed on install
    # The absence of a verdict is not a verdict: with no part written down there is nothing to
    # compare the code against, and saying "everything is declared" would read as one.
    if not in_force(elements):
        return out + ["_Nothing to compare: no part is written down yet._", ""]
    # annotation removed on install
    if warnings or reports:
        out.append("A dependency the code has and no element declares:")
        out.append("")
        for text in warnings + reports:
            out.append("- %s" % text)
    else:
        out.append("Nothing: every dependency the checker can read is declared.")
    out.append("")
    return out
# annotation removed on install


# annotation removed on install
def grounds_section(elements, model, cfg, rests):
    """What the parts stand on: the hypotheses behind each part's obligations and the state of
    each. Absent, not empty, where the project keeps no register — there is no question to
    answer rather than nothing to say."""
    if rests is None:
        return []
    out = ["## What the parts stand on", "",
           "What the register says about the ground under each part's obligations. A part resting "
           "on something `refuted` or `expired` is reported by the checker as well.", ""]
    rows = []
    for record in sorted(in_force(elements), key=lambda r: srs_arch.srs_parse.id_key(r.id)):
        standing = srs_arch.stands_on(record, model, cfg, rests)
        if not standing:
            continue
        held = {}
        for rid, hid, status in standing:
            held.setdefault((hid, status), []).append(rid)
        named = ", ".join(
            "%s (`%s`) under %d obligation(s)" % (hid, status, len(held[(hid, status)]))
            for hid, status in sorted(held, key=lambda pair: srs_arch.srs_parse.id_key(pair[0])))
        rows.append("- **%s** %s — %s" % (record.id, record.title, named))
    if not rows:
        return out + ["_No obligation of any part rests on a hypothesis the register holds._", ""]
    return out + rows + [""]
# annotation removed on install


# annotation removed on install
def silences_section(elements, model, cfg):
    """What the layer leaves unsaid, named rather than left to read as absence of a problem."""
    written, computed = srs_arch.carried_by(elements, model, cfg)
    claimed = set()
    carried = set()
    for record in elements:
        if not srs_arch.RE_ID.match(record.id):
            continue
        if record.fields.get("status") in srs_arch.CANCELLED:
            continue
        claimed |= written[record.id] | computed[record.id]
        if record.fields.get("status") not in srs_arch.DESIGNED:
            for path in srs_arch.as_list(record.fields.get("carries")):
                carried.add(path.rstrip("/"))
    out = ["## What nobody has said", ""]
    silent = [r.id for r in sorted(elements, key=lambda r: srs_arch.srs_parse.id_key(r.id))
              if srs_arch.RE_ID.match(r.id)
              and r.fields.get("status") not in srs_arch.CANCELLED
              and not r.fields.get("interface")]
    out.append("- **Parts that declare no interface:** %s"
               % (", ".join(silent) if silent else "_none_"))
    unassigned = [r["id"] for r in model["requirements"]
                  if r.get("status") in srs_arch.APPROVED and r["id"] not in claimed]
    out.append("- **Approved requirements no part answers for:** %s"
               % (", ".join(unassigned) if unassigned else "_none_"))
    unowned = []
    for requirement in model["requirements"]:
        if requirement.get("status") not in srs_arch.REALIZED:
            continue
        for path in (requirement.get("code") or []):
            if srs_arch.owner_of(path, carried) is None and path not in unowned:
                unowned.append(path)
    out.append("- **Files of a realized requirement no part carries:** %s"
               % (", ".join("`%s`" % p for p in unowned) if unowned else "_none_"))
    out.append("")
    return out
# annotation removed on install


# annotation removed on install
# The drawing the page carries. The markdown form hands the reader's renderer a diagram as text;
# a browser needs no help beyond SVG, and a script fetched from somewhere is what a self-contained
# page may not have.
NODE_W, NODE_H, GAP_X, GAP_Y, PAD = 176, 40, 20, 54, 12
TITLE_CHARS = 28


def ranks_of(live, declared):
    """How deep each part sits: one more than the deepest thing it depends on. A circle — which
    the checker reports and nothing here forbids — stops the walk instead of looping."""
    ids = set(live)
    depth = {}

    def walk(rid, seen):
        if rid in depth:
            return depth[rid]
        if rid in seen:
            return 0
        targets = [t for t in sorted(declared.get(rid, ())) if t in ids]
        value = 1 + max([walk(t, seen | {rid}) for t in targets] or [-1])
        depth[rid] = value
        return value

    for rid in live:
        walk(rid, set())
    return depth


def graph_svg(elements, cfg=None):
    """The declared dependencies as one drawing: a node per part in force, an edge per declared
    dependency, the parts that depend on most at the top. Empty where there is nothing to draw.

    Where the project declared an order, that is the height instead of the computed depth: the
    shape the project says it has, rather than this drawing's guess at it.
    """
    live = [r.id for r in sorted(in_force(elements),
                                 key=lambda r: srs_arch.srs_parse.id_key(r.id))]
    if not live:
        return ""
    titles = {r.id: r.title for r in elements}
    declared = srs_arch.declared_dependencies(elements)
    # annotation removed on install
    # The declared order wins over the computed depth, and a part the order does not place goes
    # below the last group: putting it at a level would say something nobody declared.
    place = srs_arch.placed_in_order(cfg) if cfg else {}
    if place:
        loose = max(place.values()) + 1
        depth = {rid: -place.get(rid, loose) for rid in live}
    else:
        depth = ranks_of(live, declared)
    # annotation removed on install
    rows = {}
    for rid in live:
        rows.setdefault(depth[rid], []).append(rid)
    order = sorted(rows, reverse=True)
    width = PAD * 2 + max(len(row) * NODE_W + (len(row) - 1) * GAP_X for row in rows.values())
    height = PAD * 2 + len(order) * NODE_H + (len(order) - 1) * GAP_Y

    at = {}
    for row_index, rank in enumerate(order):
        row = rows[rank]
        span = len(row) * NODE_W + (len(row) - 1) * GAP_X
        left = (width - span) / 2
        for column, rid in enumerate(row):
            at[rid] = (left + column * (NODE_W + GAP_X),
                       PAD + row_index * (NODE_H + GAP_Y))

    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" '
           'width="%d" height="%d" role="img">' % (width, height, width, height),
           '<defs><marker id="arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" '
           'markerHeight="7" orient="auto"><path d="M 0 0 L 8 4 L 0 8 z"/></marker></defs>']
    for source in live:
        sx, sy = at[source]
        for target in sorted(declared.get(source, ()), key=srs_arch.srs_parse.id_key):
            if target not in at:
                continue
            tx, ty = at[target]
            if sy == ty:
                # Side by side: a bow clear of whatever stands between them.
                bow = sy + NODE_H / 2
                out.append('<path class="edge" d="M %d %d Q %d %d %d %d" marker-end="url(#arrow)"/>'
                           % (sx + NODE_W, bow, (sx + tx + NODE_W) / 2, bow - NODE_H,
                              tx, bow))
            else:
                out.append('<line class="edge" x1="%d" y1="%d" x2="%d" y2="%d" '
                           'marker-end="url(#arrow)"/>'
                           % (sx + NODE_W / 2, sy + NODE_H, tx + NODE_W / 2, ty))
    for rid in live:
        x, y = at[rid]
        title = titles.get(rid, "")
        if len(title) > TITLE_CHARS:
            title = title[:TITLE_CHARS - 1].rstrip() + "\u2026"
        out.append('<g class="node"><rect x="%d" y="%d" width="%d" height="%d" rx="4"/>'
                   '<text x="%d" y="%d" class="node-id">%s</text>'
                   '<text x="%d" y="%d" class="node-title">%s</text></g>'
                   % (x, y, NODE_W, NODE_H, x + NODE_W / 2, y + 17, esc(rid),
                      x + NODE_W / 2, y + 31, esc(title)))
    out.append("</svg>")
    return "".join(out)
# annotation removed on install


# annotation removed on install
def render(elements, moves, model, edges, cfg, rests=None):
    """The whole document, in the order a reader's questions arise."""
    live_moves = [m for m in moves if srs_arch.RE_MOVE.match(m.id)
                  and m.fields.get("status") not in srs_arch.MOVE_CLOSED]
    out = ["# Architecture", "",
           "What this project is made of, projected from `arch/` and from what `specs/` says "
           "about it by `srs-dd/tools/srs_arch_doc.py` (srs-dd %s). Generated: do not edit — "
           "edit the records and print it again." % __version__, ""]
    out += parts_section(elements, live_moves, model, cfg)
    out += order_section(elements, cfg)
    out += units_section(elements)
    out += drawing_section(elements)
    out += divergence_section(elements, edges, cfg)
    out += grounds_section(elements, model, cfg, rests)
    out += silences_section(elements, model, cfg)
    out += ["## Where this comes from", "",
            "- The parts, their responsibilities and the moves: the records in `arch/`",
            "- The requirements and their titles: the specification, through "
            "`srs-dd/tools/srs_view.py --json`",
            "- The disagreement with the code: the architecture checker's own reading"]
    if rests is not None:
        out.append("- What the parts stand on: the bets and hypotheses in `grounds/`")
    out.append("")
    return "\n".join(out)
# annotation removed on install


# annotation removed on install
# The published set, copied from the Published pages table of the specification's standard; a
# suite holds this copy to it. OWN is this document's place in the set: a page is not linked to
# itself, and a caller that names it has made a mistake worth hearing about.
PAGES = (("index.html", "the specification"),
         ("arch.html", "the architecture document"),
         ("grounds.html", "the grounds dashboard"))
OWN = "arch.html"
# annotation removed on install

# annotation removed on install
# A stylesheet of its own: sharing the specification page's would make that page a dependency
# of this layer, and what is shareable is mostly the palette.
STYLE = """
:root { --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --line: #e2e5e9; --panel: #f7f8fa;
        --accent: #2c5fd0; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #15171a; --fg: #e8eaed; --muted: #9aa0a6; --line: #2b2f34; --panel: #1c1f23;
          --accent: #7aa2f7; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 -apple-system,
       BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
main { max-width: 52rem; margin: 0 auto; padding: 2rem 1rem 4rem; }
nav.pages { font-size: .9rem; margin-bottom: 1.4rem; }
nav.pages a { color: var(--accent); }
nav.pages span { color: var(--muted); padding: 0 .4rem; }
h1 { font-size: 1.9rem; margin: 0 0 .4rem; }
h2 { font-size: 1.3rem; margin: 2.2rem 0 .6rem; padding-bottom: .3rem;
     border-bottom: 1px solid var(--line); }
h3 { font-size: 1.05rem; margin: 1.6rem 0 .4rem; }
p { margin: .5rem 0; }
ul { margin: .4rem 0; padding-left: 1.2rem; }
li { margin: .15rem 0; }
code { font: 13px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
       background: var(--panel); border: 1px solid var(--line); border-radius: 3px;
       padding: 0 .25rem; }
em { color: var(--muted); font-style: normal; }
.drawing { background: var(--panel); border: 1px solid var(--line); border-radius: 4px;
           padding: .8rem; overflow-x: auto; }
.drawing svg { display: block; max-width: 100%; height: auto; }
.drawing .node rect { fill: var(--bg); stroke: var(--line); }
.drawing .node-id { fill: var(--fg); font: 600 12px ui-monospace, SFMono-Regular, Menlo,
                    Consolas, monospace; text-anchor: middle; }
.drawing .node-title { fill: var(--muted); font: 11px -apple-system, BlinkMacSystemFont,
                       "Segoe UI", Roboto, sans-serif; text-anchor: middle; }
.drawing .edge { stroke: var(--accent); stroke-width: 1.4; fill: none; }
.drawing marker path { fill: var(--accent); }
.source { font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
          white-space: pre; color: var(--muted); margin: 0; }
"""

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Architecture</title>
<style>%s</style>
</head>
<body>
<main>
%s
</main>
</body>
</html>
"""

# The three spans the document's own markdown uses. Underscores only at a word boundary, so a
# path like srs_arch_doc.py outside backticks is not read as emphasis.
RE_SPAN = re.compile(r"\*\*(.+?)\*\*|`(.+?)`|(?<![\w])_(.+?)_(?![\w])")


def esc(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def spans(text):
    """Inline markup to HTML, over the closed grammar this file emits."""
    out, last = [], 0
    for match in RE_SPAN.finditer(text):
        out.append(esc(text[last:match.start()]))
        bold, code, emphasis = match.groups()
        if bold is not None:
            out.append("<strong>%s</strong>" % esc(bold))
        elif code is not None:
            out.append("<code>%s</code>" % esc(code))
        else:
            out.append("<em>%s</em>" % esc(emphasis))
        last = match.end()
    out.append(esc(text[last:]))
    return "".join(out)


# annotation removed on install
def nav(named):
    """The links to the other pages of the set, in the set's own order. Exactly what the caller
    named: nothing where it named nothing, and no page that is not in the set."""
    held = [(name, label) for name, label in PAGES if name in named]
    if not held:
        return ""
    parts = []
    for index, (name, label) in enumerate(held):
        if index:
            parts.append("<span>·</span>")
        parts.append('<a href="%s">%s</a>' % (esc(name), esc(label)))
    return '<nav class="pages">%s</nav>' % "".join(parts)


def read_links(value):
    """The names a caller gave, or a sentence saying what is wrong with them."""
    named, known = [], dict(PAGES)
    for name in (part.strip() for part in value.split(",")):
        if not name:
            continue
        if name == OWN:
            return None, ("%s is this page itself; name the pages beside it" % name)
        if name not in known:
            return None, ("%s is not one of the published pages: %s"
                          % (name, ", ".join(n for n, _l in PAGES if n != OWN)))
        if name not in named:
            named.append(name)
    return named, ""
# annotation removed on install


def to_html(document, drawing="", named=()):
    """The document as one page. The markdown is this file's own output, so the grammar is
    closed — headings, two levels of list, paragraphs and the one fenced block, which carries
    the drawing where there is one and its source where there is not."""
    body, paragraph, fence = [], [], None
    # One entry per open <ul>, saying whether its last <li> is still open: a nested list belongs
    # inside the item above it, not beside it.
    levels = []

    def flush():
        if paragraph:
            body.append("<p>%s</p>" % spans(" ".join(paragraph)))
            del paragraph[:]

    def close_to(want):
        while len(levels) > want:
            if levels[-1]:
                body.append("</li>")
            body.append("</ul>")
            levels.pop()

    def item(indent, text):
        want = 1 + len(indent) // 2
        if want > len(levels):
            while len(levels) < want:
                body.append("<ul>")
                levels.append(False)
        else:
            close_to(want)
            if levels[-1]:
                body.append("</li>")
        body.append("<li>%s" % spans(text))
        levels[-1] = True

    for line in document.split("\n"):
        if fence is not None:
            if line.startswith("```"):
                body.append('<div class="drawing">%s</div>'
                            % (drawing or '<pre class="source">%s</pre>'
                               % esc("\n".join(fence))))
                fence = None
            else:
                fence.append(line)
            continue
        if line.startswith("```"):
            flush()
            close_to(0)
            fence = []
            continue
        if not line.strip():
            flush()
            close_to(0)
            continue
        heading = re.match(r"^(#{1,3}) (.+)$", line)
        if heading:
            flush()
            close_to(0)
            level = len(heading.group(1))
            body.append("<h%d>%s</h%d>" % (level, spans(heading.group(2)), level))
            continue
        bullet = re.match(r"^( *)- (.+)$", line)
        if bullet:
            flush()
            item(bullet.group(1), bullet.group(2))
            continue
        paragraph.append(line.strip())
    flush()
    close_to(0)
    return PAGE % (STYLE, nav(named) + "\n" + "\n".join(body))
# annotation removed on install


# annotation removed on install
def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    # annotation removed on install
    as_page = False
    if args and args[0] == "--html":
        as_page = True
        args = args[1:]
    # annotation removed on install
    # annotation removed on install
    named = []
    if args and args[0] == "--link":
        if len(args) < 2:
            sys.stderr.write("--link needs the page(s) to link: %s\n"
                             % ", ".join(n for n, _l in PAGES if n != OWN))
            return 2
        named, problem = read_links(args[1])
        if problem:
            sys.stderr.write("%s\n" % problem)
            return 2
        args = args[2:]
    # annotation removed on install
    if args:
        sys.stderr.write("unknown flag(s): %s\nusage: srs_arch_doc.py [--html] "
                         "[--link PAGE,…]   (the document goes to stdout)\n" % " ".join(args))
        return 2
    if named and not as_page:
        sys.stderr.write("--link belongs to --html: the markdown form links nothing\n")
        return 2
    if not os.path.isdir(srs_arch.ARCH):
        sys.stderr.write("arch/ directory not found: %s\nThe architecture layer is optional; "
                         "install it with tools/srs_init.py --arch yes.\n" % srs_arch.ARCH)
        return 2
    cfg, problem = srs_arch.load_config()
    if problem:
        sys.stderr.write("%s\n" % problem)
        return 2
    model, problem = srs_arch.read_model()
    if problem:
        sys.stderr.write("%s\n" % problem)
        return 2
    edges, problem = srs_arch.load_edges()
    if problem:
        sys.stderr.write("%s\n" % problem)
        return 2
    unread = []
    elements, moves = srs_arch.partition(srs_arch.read_records(unread), unread)
    if unread:
        sys.stderr.write("%d record(s) could not be read and are not in this document; the "
                         "checker names them.\n" % len(unread))
    document = render(elements, moves, model, edges, cfg, srs_arch.read_grounds())
    sys.stdout.write(to_html(document, graph_svg(elements, cfg), named) if as_page
                     else document + "\n")
    return 0
# annotation removed on install


if __name__ == "__main__":
    sys.exit(main())
