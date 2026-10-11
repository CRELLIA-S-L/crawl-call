#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SRS-DD-0.24.0 — the framework release this file came from
# annotation removed on install
# Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License
# annotation removed on install
"""The specification as one page: the cards, the dashboard, the graph and the HTML around them.

Everything the self-contained site is made of, rendered from the model and returned as text —
`render_site` for the whole page and `graph_image` for the graph of a selection as an SVG.
Writes nothing and reads no specification of its own: both are the command's.

Standard library only, compatible with Python 3.9.
"""
# file annotation removed on install
import html
import json
import os
import re
import sys

from urllib.parse import quote

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import srs_check                                            # noqa: E402
import srs_parse                                            # noqa: E402

from srs_view_model import (                                # noqa: E402
    INCOMING_LABEL, LINK_FIELDS, ROOT, STATUSES, _format_value, by_id, logged_baselines,
)


# Beyond this the layered graph stops being readable; what is dropped is
# always stated on the page rather than silently cut.
GRAPH_NODE_LIMIT = 150

# annotation removed on install
# The published set, copied from the Published pages table of the standard; a suite holds this
# copy to it. OWN is this page's place in the set: a page is not linked to itself.
PAGES = (("index.html", "the specification"),
         ("arch.html", "the architecture document"),
         ("grounds.html", "the grounds dashboard"))
OWN = "index.html"


def nav(named):
    """The links to the other pages of the set, in the set's own order. Exactly what the caller
    named: nothing where it named nothing, and no page that is not in the set."""
    held = [(name, label) for name, label in PAGES if name in named]
    if not held:
        return ""
    parts = []
    for index, (name, label) in enumerate(held):
        if index:
            parts.append('<span class="sep">\u00b7</span>')
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


# --------------------------------------------------------------------
# HTML
# --------------------------------------------------------------------

# annotation removed on install
CSS = """
:root {
  --bg: #ffffff; --fg: #1a1d21; --muted: #6b7280; --line: #e2e5e9;
  --panel: #f7f8fa; --accent: #2c5fd0; --mark: #fff3b0;
  --draft: #b45309; --deferred: #6d28d9; --partial: #0e7490;
  --implemented: #15803d; --superseded: #6b7280; --withdrawn: #9f1239;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14171a; --fg: #e6e8ea; --muted: #9aa3ad; --line: #2a2f36;
    --panel: #1b1f24; --accent: #7aa2f7; --mark: #4a3f14;
    --draft: #f59e0b; --deferred: #a78bfa; --partial: #22d3ee;
    --implemented: #4ade80; --superseded: #9aa3ad; --withdrawn: #fb7185;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        Helvetica, Arial, sans-serif;
}
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo,
  Consolas, monospace; font-size: 0.9em; }
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
header {
  border-bottom: 1px solid var(--line); padding: 14px 20px;
  display: flex; flex-wrap: wrap; gap: 14px; align-items: baseline;
}
header h1 { font-size: 17px; margin: 0; }
nav.pages { font-size: 13px; margin: .2rem 0 .1rem; }
nav.pages a { color: var(--accent); }
nav.pages .sep { color: var(--muted); padding: 0 .35rem; }
header .counts { color: var(--muted); font-size: 13px; }
nav { margin-left: auto; display: flex; gap: 6px; }
nav button {
  font: inherit; font-size: 13px; padding: 4px 12px; cursor: pointer;
  background: var(--panel); color: var(--fg);
  border: 1px solid var(--line); border-radius: 6px;
}
nav button[aria-selected="true"] { background: var(--accent); color: #fff;
  border-color: var(--accent); }
.layout { display: flex; align-items: flex-start; }
aside {
  width: 250px; flex: none; padding: 16px; border-right: 1px solid var(--line);
  position: sticky; top: 0; max-height: 100vh; overflow-y: auto;
}
main { flex: 1; padding: 16px 20px; min-width: 0; }
#search {
  width: 100%; font: inherit; padding: 6px 8px; border-radius: 6px;
  border: 1px solid var(--line); background: var(--bg); color: var(--fg);
}
aside h2 {
  font-size: 11px; text-transform: uppercase; letter-spacing: .07em;
  color: var(--muted); margin: 18px 0 6px;
}
.chip {
  display: inline-block; font-size: 12px; padding: 2px 8px; margin: 2px 2px 2px 0;
  border: 1px solid var(--line); border-radius: 999px; cursor: pointer;
  background: var(--panel); color: var(--fg); user-select: none;
}
.chip[aria-pressed="true"] { background: var(--accent); color: #fff;
  border-color: var(--accent); }
.chip .n { color: var(--muted); }
.chip[aria-pressed="true"] .n { color: #dbe4f7; }
aside ul { list-style: none; margin: 0; padding: 0; }
aside li { font-size: 13px; margin: 3px 0; word-break: break-all; }
article {
  border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px;
  margin-bottom: 12px; background: var(--panel);
}
article.superseded { opacity: .6; }
article h3 { margin: 0 0 6px; font-size: 15px; }
article h3 .id { font-family: ui-monospace, monospace; }
.badge {
  font-size: 11px; padding: 1px 7px; border-radius: 999px; margin-left: 6px;
  border: 1px solid currentColor; white-space: nowrap;
}
.st-draft { color: var(--draft); }
.st-deferred { color: var(--deferred); }
.st-partial { color: var(--partial); }
.st-implemented { color: var(--implemented); }
.st-superseded { color: var(--superseded); }
.st-withdrawn { color: var(--withdrawn); }
.badge.new { background: var(--implemented); color: #fff; border-color: transparent; }
.badge.changed { background: var(--draft); color: #fff; border-color: transparent; }
.notation { color: var(--muted); font-size: 12px; margin: 0 0 14px; max-width: 70ch; }
.notation b { color: var(--fg); font-weight: 600; }
.where { color: var(--muted); font-size: 12px; }
.statement { margin: 8px 0; }
.statement .modal { background: var(--mark); padding: 0 3px; border-radius: 3px; }
.rationale { color: var(--muted); font-size: 14px; margin: 8px 0; }
.links { display: grid; grid-template-columns: auto auto 1fr; gap: 2px 10px;
  font-size: 13px; margin-top: 8px; }
.links .rel { color: var(--muted); }
.banner {
  border: 1px solid var(--draft); color: var(--draft); border-radius: 8px;
  padding: 10px 14px; margin-bottom: 14px; font-size: 14px;
}
table { border-collapse: collapse; font-size: 14px; }
th, td { text-align: left; padding: 4px 14px 4px 0; }
th { color: var(--muted); font-weight: 600; font-size: 12px;
  text-transform: uppercase; letter-spacing: .05em; }
section h2 { font-size: 15px; margin: 22px 0 8px; }
.scroll { overflow-x: auto; max-width: 100%; }
.graph text { font-family: ui-monospace, monospace; font-size: 11px;
  fill: var(--fg); }
/* The status is the node's colour. `currentColor` picks it up from
   the st-* class the node already carries; a stroke named here would
   win against it, which is how the class sat on every node for two
   releases without colouring anything. */
.graph .node rect { fill: currentColor; fill-opacity: .13;
  stroke: currentColor; }
.graph .node.dim { opacity: .2; }
/* The backdrop is decoration and must not take the click: catching it
   folded a whole area away when the reader clicked between two boxes. */
.graph .lane-band { fill: var(--fg); fill-opacity: .045;
  pointer-events: none; }
.graph .lane-name { fill: var(--muted); font-size: 12px;
  pointer-events: none; }
.graph .lane-head { fill: var(--fg); fill-opacity: .08; cursor: pointer; }
.graph .lane-head:hover { fill-opacity: .16; }
.graph .lane.collapsed .lane-band { fill-opacity: .13; }
.graph .node.folded, .graph .edge.folded { display: none; }
/* The rail is beside the drawing, not on top of it: floated over the
   canvas both legends covered the first column and the reader panned the
   graph out from under them to read it. Stacked rather than in a row,
   because a legend is a list. */
.stage { display: flex; gap: 10px; align-items: stretch; }
#graph-svg { display: block; flex: 1 1 auto; min-width: 0; height: 70vh; min-height: 320px; cursor: grab; touch-action: none; user-select: none; -webkit-user-select: none; }
#graph-rail { flex: 0 0 170px; display: flex; flex-direction: column;
  gap: 10px; font-size: 12px; max-height: 70vh; overflow-y: auto; }
#graph-rail > div { background: var(--panel); border: 1px solid var(--line);
  border-radius: 4px; padding: 6px 8px; }
#graph-controls { display: flex; flex-direction: column;
  align-items: stretch; gap: 6px; }
#graph-controls label { display: flex; flex-direction: column; gap: 2px;
  color: var(--muted); }
#graph-controls select { font: inherit; font-size: 12px; width: 100%; }
#graph-legend { display: flex; flex-direction: column; gap: 3px; }
#graph-legend .legend-title { margin: 0 0 1px; color: var(--muted);
  text-transform: uppercase; letter-spacing: .05em; font-size: 10px; }
#graph-legend .key { display: flex; align-items: center; gap: 6px;
  white-space: nowrap; }
/* The swatch takes the status colour from the key's own class, the same
   way a node's box does — one palette, named in one place. */
#graph-legend .key .dot { width: 10px; height: 10px; border-radius: 2px;
  flex: none; background: currentColor; opacity: .85; }
#graph-legend .swatch { flex: none; }
.graph .node.out, .graph .edge.out { display: none; }
#graph-reset { font: inherit; font-size: 12px; padding: 3px 8px; cursor: pointer; background: var(--panel); color: var(--fg); border: 1px solid var(--line); border-radius: 4px; }
@media (max-width: 720px) {
  .stage { flex-direction: column; }
  #graph-rail { flex: none; max-height: none; flex-direction: row;
    flex-wrap: wrap; }
}
#graph-svg:active { cursor: grabbing; }
#graph-svg.focused .node, #graph-svg.focused .edge { opacity: .25; }
#graph-svg.focused .node.sel, #graph-svg.focused .node.lit,
#graph-svg.focused .edge.lit { opacity: 1; }
.graph .node.sel rect { stroke-width: 2.5; }
.graph .edge.lit { stroke: var(--fg); stroke-width: 2; }
.graph .edge { stroke: var(--muted); fill: none; }
.graph .edge.refines { stroke-dasharray: 6 3; }
.graph .edge.depends_on { stroke-dasharray: 2 3; }
.graph .edge.conflicts_with { stroke-dasharray: 8 3 2 3; }
footer { border-top: 1px solid var(--line); margin-top: 24px; padding: 12px 20px;
  color: var(--muted); font-size: 12px; }
[hidden] { display: none !important; }
@media print {
  aside, nav, .banner { display: none; }
  body { font-size: 11pt; }
  article { break-inside: avoid; border-color: #ccc; background: none; }
  #view-dash, #view-graph { display: block !important; }
}
.key.kind { cursor: pointer; user-select: none; border-radius: 4px; }
.key.kind[aria-pressed="false"] { opacity: .35; }
"""
# annotation removed on install

# A class on the drawing rather than a style per edge, since the script rebuilds edges
# when an area folds; generated from LINK_FIELDS so no kind arrives unhideable.
EDGE_HIDE_CSS = "".join(
    "#graph-svg.hide-%s .edge.%s { display: none; }\n" % (field, field)
    for field in LINK_FIELDS)

JS = """
(function () {
  var cards = Array.prototype.slice.call(
    document.querySelectorAll('article[data-id]'));
  var gsvg = document.getElementById('graph-svg');
  if (gsvg) {
    var stage = document.getElementById('graph-stage');
    var NW = +gsvg.dataset.nw, NH = +gsvg.dataset.nh;
    var view = { x: 0, y: 0, k: 1 };
    var edges = Array.prototype.slice.call(gsvg.querySelectorAll('path.edge'));
    var nodes = {};
    Array.prototype.forEach.call(gsvg.querySelectorAll('g.node'), function (g) {
      nodes[g.dataset.id] = g;
    });

    // applyView, not apply: the filters declare an `apply` of their own
    // at the top level of this script, and a function declared inside a
    // block is also assigned to the enclosing function's binding of the
    // same name (Annex B). Two functions named `apply` meant every filter
    // click moved the graph instead of filtering, silently, for as long
    // as both existed.
    function applyView() {
      stage.setAttribute('transform', 'translate(' + view.x + ',' + view.y
        + ') scale(' + view.k + ')');
    }

    // Screen pixels per viewBox unit. The canvas fills its panel, so this
    // is whatever the browser chose when fitting the viewBox — without it
    // a drag of ten pixels would move a node by ten user units, which is
    // only the same thing by accident.
    function unit() {
      var m = gsvg.getScreenCTM();
      return m && m.a ? m.a : 1;
    }

    // A point needs the whole inverse, not just the scale: the drawing is
    // centred in the panel, so there is a margin between the element's
    // corner and the viewBox origin — and it is most of the panel when a
    // wide graph sits in a tall one.
    function toDrawing(clientX, clientY) {
      var m = gsvg.getScreenCTM();
      if (!m) { return { x: 0, y: 0 }; }
      var i = m.inverse();
      return { x: clientX * i.a + clientY * i.c + i.e,
               y: clientX * i.b + clientY * i.d + i.f };
    }

    // The same three rules as edge_path() in the generator: within a lane
    // the two boxes share an x, so the edge leaves the right-hand side and
    // bows out past what sits between them; across lanes it leaves the
    // side facing the other lane. Both copies have to agree — collapsing
    // an area recomputes an edge, and one that changed shape while the
    // reader was watching would read as a different link.
    var BOW_MAX = 34;
    function edgePath(a, b) {
      var ax = +a.dataset.x, ay = +a.dataset.y;
      var bx = +b.dataset.x, by = +b.dataset.y;
      var am = ay + NH / 2, bm = by + NH / 2;
      if (a.dataset.area === b.dataset.area) {
        var side = ax + NW;
        var out = side + Math.min(BOW_MAX,
          14 + Math.floor(Math.abs(ay - by) / 5));
        return 'M ' + side + ' ' + am + ' Q ' + out + ' ' + ((am + bm) / 2)
          + ' ' + side + ' ' + bm;
      }
      if (bx > ax) {
        return 'M ' + (ax + NW) + ' ' + am + ' L ' + bx + ' ' + bm;
      }
      return 'M ' + ax + ' ' + am + ' L ' + (bx + NW) + ' ' + bm;
    }

    function redraw(id) {
      edges.forEach(function (path) {
        if (path.dataset.from !== id && path.dataset.to !== id) { return; }
        var a = nodes[path.dataset.from], b = nodes[path.dataset.to];
        if (!a || !b) { return; }
        path.setAttribute('d', edgePath(a, b));
      });
    }

    gsvg.addEventListener('wheel', function (e) {
      e.preventDefault();
      var at = toDrawing(e.clientX, e.clientY);
      var k = Math.min(4, Math.max(0.2, view.k * (e.deltaY < 0 ? 1.1 : 1 / 1.1)));
      view.x = at.x - (at.x - view.x) * (k / view.k);
      view.y = at.y - (at.y - view.y) * (k / view.k);
      view.k = k;
      applyView();
    }, { passive: false });

    // Pointer events, not mouse ones: the same code then works for a
    // finger and a pen, and the CSS turns native scrolling off in
    // exchange — which would leave a touch device with no way to move
    // the graph at all if only mice were handled.
    //
    // A drag is a movement past a threshold, not any movement at all:
    // pressing a mouse button nudges the pointer a pixel or two, and
    // counting that as a drag swallows the click it belongs to.
    //
    // The capture is taken when that threshold is crossed and not before,
    // and this is the whole reason a click ever reaches a node or a lane
    // header. While an element holds the pointer capture the browser
    // dispatches the click to *that* element rather than to the descendant
    // under the cursor — so capturing on pointerdown sent every click to
    // the canvas, and the handlers on the nodes and the headers, being
    // below it, were never reached. Nothing reported it: the click still
    // fired, at the wrong element, and no suite here exercises a gesture
    // (see specs/91-open-issues.md). The capture is only needed to keep a
    // drag alive once the pointer leaves the canvas, which cannot happen
    // before the pointer has moved.
    var DRAG_SLOP = 4;
    var held = null, last = null, from = null, moved = false;
    gsvg.addEventListener('pointerdown', function (e) {
      held = 'stage';
      last = { x: e.clientX, y: e.clientY };
      from = { x: e.clientX, y: e.clientY };
      moved = false;
      // No preventDefault here: cancelling pointerdown suppresses the
      // compatibility mouse events, and with them the click that opens a
      // requirement. Scrolling is held off by touch-action in the CSS,
      // and selection by user-select.
    });
    gsvg.addEventListener('pointermove', function (e) {
      if (!held) { return; }
      var dx = e.clientX - last.x, dy = e.clientY - last.y;
      if (!moved && Math.abs(e.clientX - from.x)
          + Math.abs(e.clientY - from.y) > DRAG_SLOP) {
        moved = true;
        if (gsvg.setPointerCapture) { gsvg.setPointerCapture(e.pointerId); }
      }
      last = { x: e.clientX, y: e.clientY };
      var px = unit();
      view.x += dx / px; view.y += dy / px; applyView();
    });
    function release(e) {
      held = null;
      if (e && e.pointerId !== undefined
          && gsvg.hasPointerCapture(e.pointerId)) {
        gsvg.releasePointerCapture(e.pointerId);
      }
    }
    gsvg.addEventListener('pointerup', release);
    gsvg.addEventListener('pointercancel', release);

    // Collapsing an area is what pulling a node aside used to be: with a
    // lane for an area, what stands in front of the thing being read is a
    // whole column, and moving one box out of nineteen achieves
    // nothing. The members fold onto the lane's header and their edges
    // are recomputed from where they now sit, so an area keeps
    // showing what it is attached to while its contents are out of the
    // way. An edge with both ends inside a folded lane has nothing left
    // to say and goes with them.
    function foldEdges() {
      edges.forEach(function (path) {
        var a = nodes[path.dataset.from], b = nodes[path.dataset.to];
        path.classList.toggle('folded', !!(a && b
          && a.classList.contains('folded')
          && b.classList.contains('folded')));
      });
    }
    // The band shrinks with the column: a lane that hid its members but
    // kept its full height would leave an empty stripe where the reader
    // asked for the space back, and "a single block" is what the
    // requirement says.
    var LANE_FOLD_H = 44;
    var laneList = Array.prototype.slice.call(gsvg.querySelectorAll('g.lane'));
    function setLane(lane, folded) {
      lane.classList.toggle('collapsed', folded);
      var band = lane.querySelector('.lane-band');
      if (band) {
        band.setAttribute('height', folded ? LANE_FOLD_H : lane.dataset.h);
      }
      var name = lane.dataset.area;
      Object.keys(nodes).forEach(function (id) {
        var g = nodes[id];
        if (g.dataset.area !== name) { return; }
        g.classList.toggle('folded', folded);
        g.dataset.x = folded ? lane.dataset.x : g.dataset.x0;
        g.dataset.y = folded ? lane.dataset.y : g.dataset.y0;
        redraw(id);
      });
    }
    laneList.forEach(function (lane) {
      lane.addEventListener('click', function () {
        // Same guard the nodes carry: a pan that happens to end over a
        // header must not fold the column the reader was dragging past.
        if (moved) { moved = false; return; }
        setLane(lane, !lane.classList.contains('collapsed'));
        foldEdges();
      });
    });

    // Narrowing to a root and a radius. A drawing of everything is the
    // one view a specification of any size cannot use; the tools that
    // solve this converge on the same answer, a root and a distance
    // from it.
    var rootSel = document.getElementById('graph-root');
    var depthSel = document.getElementById('graph-depth');
    var neighbours = {};
    edges.forEach(function (p) {
      var a = p.dataset.from, b = p.dataset.to;
      (neighbours[a] = neighbours[a] || []).push(b);
      (neighbours[b] = neighbours[b] || []).push(a);
    });

    function narrow() {
      var root = rootSel ? rootSel.value : '';
      if (!root) {
        Object.keys(nodes).forEach(function (id) {
          nodes[id].classList.remove('out');
        });
        edges.forEach(function (p) { p.classList.remove('out'); });
        return;
      }
      var limit = depthSel ? +depthSel.value : 2;
      var seen = {}, frontier = [root], step = 0;
      seen[root] = true;
      while (step < limit) {
        var next = [];
        frontier.forEach(function (id) {
          (neighbours[id] || []).forEach(function (other) {
            if (!seen[other]) { seen[other] = true; next.push(other); }
          });
        });
        frontier = next;
        step += 1;
      }
      Object.keys(nodes).forEach(function (id) {
        nodes[id].classList.toggle('out', !seen[id]);
      });
      edges.forEach(function (p) {
        p.classList.toggle('out',
          !(seen[p.dataset.from] && seen[p.dataset.to]));
      });
    }
    if (rootSel) { rootSel.addEventListener('change', narrow); }
    if (depthSel) { depthSel.addEventListener('change', narrow); }

    var reset = document.getElementById('graph-reset');
    if (reset) {
      reset.addEventListener('click', function () {
        view = { x: 0, y: 0, k: 1 };
        applyView();
        // Where it started includes the columns that were folded away: a
        // reader who has hidden four areas and cannot find the button that
        // brings them back is worse off than before they folded anything.
        laneList.forEach(function (lane) { setLane(lane, false); });
        // And the kinds of link left out, for the same reason and with the
        // same trap: a dimmed swatch is easy to miss.
        Array.prototype.forEach.call(
          document.querySelectorAll('.key.kind'), function (key) {
            key.setAttribute('aria-pressed', 'true');
            gsvg.classList.remove('hide-' + key.dataset.kind);
          });
        foldEdges();
      });
    }

    // Hovering a node lights what it links to and what links to it; the
    // rest dims, which is the whole reason to point at one rather than
    // squint. The click is left to open the requirement itself.
    function light(node) {
      gsvg.classList.toggle('focused', !!node);
      Object.keys(nodes).forEach(function (id) {
        nodes[id].classList.remove('sel', 'lit');
      });
      edges.forEach(function (p) { p.classList.remove('lit'); });
      if (!node) { return; }
      var id = node.dataset.id;
      node.classList.add('sel');
      edges.forEach(function (p) {
        if (p.dataset.from !== id && p.dataset.to !== id) { return; }
        p.classList.add('lit');
        var other = p.dataset.from === id ? p.dataset.to : p.dataset.from;
        if (nodes[other]) { nodes[other].classList.add('lit'); }
      });
    }

    Object.keys(nodes).forEach(function (id) {
      var g = nodes[id];
      // Not while a drag is under way: the pointer sweeps over half the
      // graph on its way, and the highlight would strobe.
      g.addEventListener('pointerenter', function () {
        if (!held) { light(g); }
      });
      g.addEventListener('pointerleave', function () {
        if (!held) { light(null); }
      });
      g.addEventListener('click', function () {
        if (moved) { moved = false; return; }
        location.hash = id;
        jump();        // hashchange stays silent when the hash repeats
      });
    });
  }

  var baseNode = document.getElementById('baselines-data');
  var baselines = baseNode ? JSON.parse(baseNode.textContent || '[]') : [];
  var LIST_FIELDS = ['code', 'tests', 'derives_from', 'depends_on', 'refines',
                     'conflicts_with', 'exempt'];
  var FLAT_FIELDS = ['title', 'status', 'verification', 'statement',
                     'superseded_by'];

  function snapshotAt(index) {
    var state = {};
    for (var i = 0; i <= index; i++) {
      var step = baselines[i];
      if (step.full) { Object.keys(step.full).forEach(function (id) {
        state[id] = step.full[id]; }); continue; }
      (step.drop || []).forEach(function (id) { delete state[id]; });
      Object.keys(step.put || {}).forEach(function (id) {
        state[id] = step.put[id]; });
    }
    return state;
  }

  function compareBaselines(from, to) {
    var a = snapshotAt(from), b = snapshotAt(to);
    var added = [], removed = [], changed = [];
    Object.keys(b).sort().forEach(function (id) {
      if (!(id in a)) { added.push([id, b[id].title]); return; }
      var fields = [];
      FLAT_FIELDS.forEach(function (f) {
        if (a[id][f] !== b[id][f]) fields.push(f);
      });
      LIST_FIELDS.forEach(function (f) {
        // JSON rather than a joined separator. The separator used to
        // be a unicode escape for NUL, written for JavaScript and
        // eaten by the Python string that carries this script, so the
        // page shipped with real NUL bytes in it — enough for grep,
        // diff and every editor to call it binary.
        if (JSON.stringify(a[id][f]) !== JSON.stringify(b[id][f])) {
          fields.push(f);
        }
      });
      if (fields.length) changed.push([id, b[id].title, fields]);
    });
    Object.keys(a).sort().forEach(function (id) {
      if (!(id in b)) removed.push([id, a[id].title]);
    });
    return { added: added, removed: removed, changed: changed };
  }

  function renderBaselines() {
    var fromSel = document.getElementById('base-from');
    var toSel = document.getElementById('base-to');
    var out = document.getElementById('base-result');
    if (!fromSel || !toSel || !out) { return; }
    var from = parseInt(fromSel.value, 10), to = parseInt(toSel.value, 10);
    var d = compareBaselines(from, to);
    var html = '<p>' + baselines[from].version + ' → ' + baselines[to].version
      + ': ' + d.added.length + ' added, ' + d.removed.length + ' removed, '
      + d.changed.length + ' changed.</p>';
    function block(title, rows, render) {
      if (!rows.length) { return ''; }
      return '<h3>' + title + '</h3><ul>'
        + rows.map(render).join('') + '</ul>';
    }
    html += block('Added', d.added, function (r) {
      return '<li><a href="#' + r[0] + '"><code>' + r[0] + '</code></a> '
        + r[1] + '</li>';
    });
    html += block('Removed', d.removed, function (r) {
      return '<li><code>' + r[0] + '</code> ' + r[1] + '</li>';
    });
    html += block('Changed', d.changed, function (r) {
      return '<li><a href="#' + r[0] + '"><code>' + r[0] + '</code></a> '
        + r[1] + ' — ' + r[2].join(', ') + '</li>';
    });
    out.innerHTML = html;
  }

  if (baselines.length > 1) {
    var fromSel = document.getElementById('base-from');
    var toSel = document.getElementById('base-to');
    fromSel.value = String(baselines.length - 2);
    toSel.value = String(baselines.length - 1);
    fromSel.addEventListener('change', renderBaselines);
    toSel.addEventListener('change', renderBaselines);
    renderBaselines();
  }

  var search = document.getElementById('search');
  var chips = Array.prototype.slice.call(document.querySelectorAll('.chip'));
  var shown = document.getElementById('shown');
  var active = {};

  function passes(card) {
    for (var key in active) {
      if (!active[key].size) continue;
      if (!active[key].has(card.dataset[key])) return false;
    }
    var q = search.value.trim().toLowerCase();
    return !q || card.dataset.search.indexOf(q) !== -1;
  }

  function apply() {
    var visible = 0, live = {};
    cards.forEach(function (card) {
      var ok = passes(card);
      card.hidden = !ok;
      if (ok) { visible++; live[card.dataset.id] = true; }
    });
    if (shown) shown.textContent = visible;
    document.querySelectorAll('.graph .node').forEach(function (node) {
      node.classList.toggle('dim', !live[node.dataset.id]);
    });
  }

  chips.forEach(function (chip) {
    var key = chip.dataset.key;
    active[key] = active[key] || new Set();
    chip.addEventListener('click', function () {
      var on = chip.getAttribute('aria-pressed') === 'true';
      chip.setAttribute('aria-pressed', on ? 'false' : 'true');
      if (on) active[key].delete(chip.dataset.value);
      else active[key].add(chip.dataset.value);
      apply();
    });
    chip.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        chip.click();
      }
    });
  });

  // Leaving a kind of link out of the drawing. The class goes on the
  // svg, not on the edges: folding an area rebuilds them.
  Array.prototype.forEach.call(
    document.querySelectorAll('.key.kind'), function (key) {
      var kind = key.dataset.kind;
      key.addEventListener('click', function () {
        var drawn = key.getAttribute('aria-pressed') === 'true';
        key.setAttribute('aria-pressed', drawn ? 'false' : 'true');
        if (gsvg) gsvg.classList.toggle('hide-' + kind, drawn);
      });
      key.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          key.click();
        }
      });
    });

  search.addEventListener('input', apply);

  var tabs = Array.prototype.slice.call(document.querySelectorAll('nav button'));
  function showView(name) {
    tabs.forEach(function (tab) {
      var on = tab.dataset.view === name;
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
      document.getElementById(tab.dataset.view).hidden = !on;
    });
  }
  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () { showView(tab.dataset.view); });
  });

  // Following links in both directions is the point of this page, and a
  // link is followed from wherever the reader happens to be. The card it
  // names lives in one view and may be hidden by a filter; both are this
  // function's business, whichever view the reader came from.
  function jump() {
    var id = location.hash.replace(/^#/, '');
    if (!id) return;
    var card = cards.filter(function (c) { return c.dataset.id === id; })[0];
    if (!card) return;
    showView('view-reqs');
    if (card.hidden) {
      search.value = '';
      chips.forEach(function (chip) {
        chip.setAttribute('aria-pressed', 'false');
        active[chip.dataset.key].delete(chip.dataset.value);
      });
      apply();
    }
    if (card.scrollIntoView) card.scrollIntoView();
  }
  window.addEventListener('hashchange', jump);

  apply();
  jump();
})();
"""


def esc(text):
    return html.escape(text or "", quote=True)


def render_inline(text, modal_pattern):
    """A deliberately partial Markdown renderer — escaping, the modal verb, **strong**, *em*,
    `code`, paragraphs — anything else showing up literally.

    The modal verb goes first: its pattern matches the asterisks, so after **strong** became
    <strong> it would never match again.
    """
    text = esc(text)
    if modal_pattern is not None:
        text = modal_pattern.sub(
            lambda m: '<strong class="modal">%s</strong>'
                      % m.group(0).strip("*"), text)
    text = "".join(
        part if index % 2 == 0 else "<code>%s</code>" % part
        for index, part in enumerate(text.split("`")))
    text = _pair(text, "**", "strong")
    text = _pair(text, "*", "em")
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    return "".join("<p>%s</p>" % p.replace("\n", " ") for p in paragraphs)


def _pair(text, marker, tag):
    pieces = text.split(marker)
    if len(pieces) < 3:
        return text
    result = []
    for index, piece in enumerate(pieces):
        if index % 2 == 1 and index != len(pieces) - 1:
            result.append("<%s>%s</%s>" % (tag, piece, tag))
        else:
            result.append(piece)
    return "".join(result)


# annotation removed on install
class Links(object):
    """Paths become links twice over: relative, so the page works from file://, and
    repository ones where repo_url is set. A page written outside the repository gets
    absolute file:// URLs instead."""

    def __init__(self, model, out_dir):
        self.repo_url = model["repo_url"]
        # One resolved pair for both: mixing resolved and unresolved sides is how a symlinked
        # root produces links out of the repository.
        root, here = os.path.realpath(ROOT), os.path.realpath(out_dir)
        if os.path.relpath(here, root).startswith(".."):
            self.prefix = "file://" + quote(root)
        else:
            self.prefix = os.path.relpath(root, here).replace(os.sep, "/")

    def local(self, path):
        return "%s/%s" % (self.prefix, quote(path))

    def href(self, path, line=None):
        if self.repo_url:
            anchor = "#L%d" % line if line else ""
            return "%s/%s%s" % (self.repo_url, quote(path), anchor)
        return self.local(path)
# annotation removed on install


# annotation removed on install
# The verification letters in the standard's own words and order: a letter is not a
# word, and this page reaches a reader who has neither file to look it up in.
# annotation removed on install
METHODS = (("T", "test"), ("D", "demonstration"),
           ("I", "inspection"), ("A", "analysis"))
# annotation removed on install
# annotation removed on install
METHOD_WORD = dict(METHODS)


# annotation removed on install
def notation_legend():
    """What every mark on a requirement card stands for."""
    letters = "".join("<b>%s</b> %s, " % (key, word) for key, word in METHODS)
    return ('<p class="notation">Each requirement below carries its status, '
            'and how conformance is checked as a single letter — %s'
            '<b>?</b> where none is declared. Every other badge spells '
            'itself: a status says its own name, and a change badge says '
            'what changed.</p>' % letters)
# annotation removed on install


# annotation removed on install
def render_card(entry, model, known, links, diff_state):
    classes = ["superseded"] if entry["status"] == "superseded" else []
    badge = ""
    state = diff_state.get(entry["id"])
    if state:
        badge = '<span class="badge %s">%s</span>' % (state, state)
    rows = []
    for field in LINK_FIELDS:
        for target in entry[field]:
            rows.append((field, target, "→"))
    if entry["superseded_by"]:
        rows.append(("superseded_by", entry["superseded_by"], "→"))
    for field, source in model["incoming"].get(entry["id"], []):
        rows.append((INCOMING_LABEL.get(field, field), source, "←"))

    link_html = []
    for label, other, arrow in rows:
        target = known.get(other)
        status = target["status"] if target else "unknown"
        link_html.append(
            '<span class="rel">%s</span><span>%s</span>'
            '<span><a href="#%s">%s</a> <span class="rel">(%s)</span></span>'
            % (esc(label), arrow, esc(other), esc(other), esc(status)))
    for field in ("code", "tests"):
        for path in entry[field]:
            link_html.append(
                '<span class="rel">%s</span><span></span>'
                '<span><a href="%s"><code>%s</code></a></span>'
                % (field, esc(links.href(path)), esc(path)))
    # annotation removed on install
    # An exemption is a claim about this requirement, so it is shown beside
    # it: an excuse nobody can see is an excuse nobody revisits.
    for name in entry.get("exempt", []):
        link_html.append(
            '<span class="rel">exempt</span><span></span>'
            '<span><code>%s</code></span>' % esc(name))
    # annotation removed on install

    parts = ['<article id="%s" data-id="%s" data-status="%s" data-type="%s" '
             'data-area="%s" data-file="%s" data-search="%s"%s>'
             % (esc(entry["id"]), esc(entry["id"]), esc(entry["status"]),
                esc(entry["type"]), esc(entry["area"]),
                esc(file_key(entry["path"])),   # annotation removed on install
                esc(" ".join([entry["id"], entry["title"], entry["statement"],
                              entry["rationale"]]).lower()),
                ' class="%s"' % " ".join(classes) if classes else "")]
    parts.append('<h3><span class="id">%s</span> — %s'
                 '<span class="badge st-%s">%s</span>'
                 '<span class="badge" title="%s">%s</span>%s</h3>'
                 % (esc(entry["id"]), esc(entry["title"]),
                    esc(entry["status"] or "unknown"),
                    esc(entry["status"] or "unknown"),
                    esc(METHOD_WORD.get(entry["verification"],
                                        "no method declared")),
                    esc(entry["verification"] or "?"), badge))
    parts.append('<div class="where"><a href="%s">%s:%d</a></div>'
                 % (esc(links.href(entry["path"], entry["line"])),
                    esc(entry["path"]), entry["line"]))
    parts.append('<div class="statement">%s</div>'
                 % render_inline(entry["statement"], srs_check.RE_MODAL))
    if entry["rationale"]:
        parts.append('<div class="rationale">%s</div>'
                     % render_inline(entry["rationale"], None))
    if link_html:
        parts.append('<div class="links">%s</div>' % "".join(link_html))
    parts.append("</article>")
    return "".join(parts)
# annotation removed on install


# annotation removed on install
def file_key(path):
    """The name a requirements file goes by in the filter: its path under specs/, since two
    areas' `000-999.md` would otherwise merge into one choice."""
    prefix = "specs/"
    return path[len(prefix):] if path.startswith(prefix) else path
# annotation removed on install


def render_chips(key, values, counts):
    chips = []
    for value in values:
        if not counts.get(value):
            continue
        chips.append('<span class="chip" role="button" tabindex="0" '
                     'aria-pressed="false" data-key="%s" data-value="%s">%s '
                     '<span class="n">%d</span></span>'
                     % (key, esc(value), esc(value), counts[value]))
    return "".join(chips)


# annotation removed on install
def render_dashboard(model, links):
    known = by_id(model)
    counts = {}
    for entry in model["requirements"]:
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
    rows = "".join("<tr><td><span class=\"badge st-%s\">%s</span></td>"
                   "<td>%d</td></tr>" % (esc(status), esc(status),
                                         counts.get(status, 0))
                   for status in STATUSES)

    def listing(entries, note):
        if not entries:
            return "<p>None.</p>"
        items = "".join('<li><a href="#%s">%s</a> %s</li>'
                        % (esc(e["id"]), esc(e["id"]), esc(e["title"]))
                        for e in entries)
        return "<p>%s</p><ul>%s</ul>" % (esc(note), items)

    untested = [e for e in model["requirements"]
                if e["status"] in ("implemented", "partial") and not e["tests"]]
    ahead = [e for e in model["requirements"]
             if e["status"] == "draft" and e["code"]]
    resting, seen_resting = [], set()
    for entry in model["requirements"]:
        if entry["status"] not in ("implemented", "partial"):
            continue
        for field in ("derives_from", "depends_on", "refines"):
            for target in entry[field]:
                other = known.get(target)
                if (other and other["status"] == "draft"
                        and entry["id"] not in seen_resting):
                    seen_resting.add(entry["id"])
                    resting.append(entry)
    orphans = "".join('<li><a href="%s"><code>%s</code></a></li>'
                      % (esc(links.href(path)), esc(path))
                      for path in model["orphan_code"])

    # annotation removed on install
    # Identifiers go out as `href="#<id>"`, so following one reaches its card like every
    # other view. `left` rather than `outlived`, which names the function that computes it.
    left = model["outlived"]
    parts = []
    for item in left["links"]:
        parts.append('<li><a href="#%s">%s</a> %s — <code>%s</code> '
                     '<a href="#%s">%s</a></li>'
                     % (esc(item["id"]), esc(item["id"]), esc(item["title"]),
                        esc(item["field"]), esc(item["target"]),
                        esc(item["target"])))
    for path in left["files"]:
        parts.append('<li><a href="%s"><code>%s</code></a> — left by a '
                     'cancelled requirement, claimed by nothing live</li>'
                     % (esc(links.href(path)), esc(path)))
    for item in left["annotations"]:
        parts.append('<li><a href="%s"><code>%s</code></a> — annotated '
                     '<a href="#%s">%s</a></li>'
                     % (esc(links.href(item["path"])), esc(item["path"]),
                        esc(item["target"]), esc(item["target"])))
    outlived_html = ("<p>Cancelling is the one edit whose consequences "
                     "outlive it.</p><ul>%s</ul>" % "".join(parts)
                     if parts else "<p>None.</p>")
    # annotation removed on install

    return ("<h2>Status</h2><table><tr><th>Status</th><th>Requirements</th>"
            "</tr>%s</table>"
            "<h2>Realized without listed tests</h2>%s"
            "<h2>Draft with code — implementation ahead of approval</h2>%s"
            "<h2>Realized but resting on a draft</h2>%s"
            "<h2>Still pointing at a cancelled requirement</h2>%s"
            "<h2>Code files no requirement references (%d of %d)</h2>"
            "<ul>%s</ul>"
            % (rows,
               listing(untested, "Verified by other means, or not yet set up."),
               listing(ahead, "Code exists before approval (SRS-DD-ART-020)."),
               listing(resting, "Approve the parent or revisit the child."),
               outlived_html,
               len(model["orphan_code"]), model["code_total"],
               orphans or "<li>None.</li>"))
# annotation removed on install


def render_diff_section(diff):
    def block(title, entries, sign):
        if not entries:
            return "<h2>%s (0)</h2><p>None.</p>" % title
        items = "".join('<li>%s <a href="#%s">%s</a> %s</li>'
                        % (sign, esc(e["id"]), esc(e["id"]), esc(e["title"]))
                        for e in entries)
        return "<h2>%s (%d)</h2><ul>%s</ul>" % (title, len(entries), items)

    changed = []
    for item in diff["changed"]:
        rows = "".join("<li><code>%s</code>: %s → %s</li>"
                       % (esc(field), esc(_format_value(before)),
                          esc(_format_value(after)))
                       for field, before, after in item["fields"])
        statement = ""
        if item["statement"]:
            statement = "<pre class=\"scroll\">%s</pre>" % esc(
                "\n".join(item["statement"]))
        changed.append('<li><a href="#%s">%s</a> %s<ul>%s</ul>%s</li>'
                       % (esc(item["entry"]["id"]), esc(item["entry"]["id"]),
                          esc(item["entry"]["title"]), rows, statement))
    return ("<h2>Changes since %s</h2>"
            "<p>The working tree against the revision.</p>%s%s"
            "<h2>Changed (%d)</h2>%s"
            % (esc(diff["rev"]),
               block("Added", diff["added"], "+"),
               block("Removed", diff["removed"], "−"),
               len(diff["changed"]),
               ("<ul>%s</ul>" % "".join(changed)) if changed
               else "<p>None.</p>"))


# --------------------------------------------------------------------
# Graph
# --------------------------------------------------------------------

NODE_W, NODE_H, GAP_X, GAP_Y = 118, 28, 18, 22
# Room above the first row for the lane's name, which is also the control that folds the
# column — a click target, and 26 measured too small in a panel — and the stride that holds
# the widest bow.
HEADER_H, BOW_MAX = 34, 34
# What a collapsed lane shrinks to, and where folded edges land: at the bottom of that
# block, clear of the name. The page's script carries the height too.
LANE_FOLD_H = 44
LANE_FOLD_Y = LANE_FOLD_H - NODE_H
LANE_STRIDE = NODE_W + GAP_X + BOW_MAX
# The band is drawn wider than its column, so the first one needs room to
# its left or the canvas clips its edge.
LANE_PAD = 8


def svg_escape(text):
    """SVG is XML: an unescaped & in a title breaks the whole document,
    and the HTML text escaper is not the same thing."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace('"', "&quot;"))


def _area_of(node):
    """The middle segment of `<TYPE>-<AREA>-<NNN>`; the graph is drawn from a model and must
    not lose a node to a surprise."""
    parts = node.split("-")
    return parts[1] if len(parts) > 2 else ""


def _row_key(node):
    """Within a lane: by number, then by identifier — the whole string would sort by type
    first and interleave the numbering."""
    parts = node.split("-")
    try:
        return (int(parts[-1]), node)
    except ValueError:
        return (0, node)


def _bow(y_from, y_to):
    """How far an intra-lane edge swings out to clear the boxes between its ends; the page's
    script carries this expression too, and an edge changing shape when an area folds
    would read as a different link."""
    return min(BOW_MAX, 14 + int(abs(y_from - y_to) / 5))


def edge_path(ax, ay, bx, by, same_lane):
    """The `d` of one edge, from the child's box to the parent's: within a lane it bows out
    to clear what lies between, across lanes it runs straight. Both rules live in the
    page's script as well."""
    a_mid, b_mid = ay + NODE_H / 2, by + NODE_H / 2
    if same_lane:
        side = ax + NODE_W
        out = side + _bow(ay, by)
        return ("M %d %d Q %d %d %d %d"
                % (side, a_mid, out, (a_mid + b_mid) / 2, side, b_mid))
    if bx > ax:
        return "M %d %d L %d %d" % (ax + NODE_W, a_mid, bx, b_mid)
    return "M %d %d L %d %d" % (ax, a_mid, bx + NODE_W, b_mid)


# annotation removed on install
# annotation removed on install
def build_graph(model):
    """Every link drawn; a lane per area, a row per requirement. Position is arithmetic, so
    the drawing comes out identical on every run."""
    known = by_id(model)
    edges = []
    for entry in model["requirements"]:
        for field in LINK_FIELDS:
            for target in entry[field]:
                if target in known:
                    edges.append((entry["id"], target, field))
    # annotation removed on install
    nodes = sorted({rid for edge in edges for rid in edge[:2]}, key=srs_parse.id_key)
    # annotation removed on install
    # The identifiers, not their count: in sorted order the cut falls at one place in the
    # alphabet, so whole families go at once.
    dropped = []
    if len(nodes) > GRAPH_NODE_LIMIT:
        dropped = nodes[GRAPH_NODE_LIMIT:]
        nodes = nodes[:GRAPH_NODE_LIMIT]
        keep = set(nodes)
        edges = [e for e in edges if e[0] in keep and e[1] in keep]
    if not nodes:
        return "", []

    area = dict((node, _area_of(node)) for node in nodes)
    present = set(area.values())
    # The configured order first, then what it does not name, so no node falls out of the
    # drawing by being in an unexpected area.
    lanes = ([a for a in model["areas"] if a in present]
             + sorted(present - set(model["areas"])))

    position, members = {}, {}
    for index, lane in enumerate(lanes):
        rows = sorted([n for n in nodes if area[n] == lane], key=_row_key)
        members[lane] = rows
        x = LANE_PAD + index * LANE_STRIDE
        for row, node in enumerate(rows):
            position[node] = (x, HEADER_H + row * (NODE_H + GAP_Y))
    width = max(x for x, _y in position.values()) + NODE_W + BOW_MAX + 2
    height = max(y for _x, y in position.values()) + NODE_H + 2

    parts = ['<div class="stage"><svg id="graph-svg" class="graph" '
             'viewBox="0 0 %d %d" preserveAspectRatio="xMidYMid meet" '
             'data-nw="%d" data-nh="%d" '
             'xmlns="http://www.w3.org/2000/svg">'
             % (width, height, NODE_W, NODE_H)]
    parts.append('<g id="graph-stage">')
    parts.append('<defs><marker id="a" viewBox="0 0 8 8" refX="7" refY="4" '
                 'markerWidth="6" markerHeight="6" orient="auto-start-reverse">'
                 '<path d="M0 0 L8 4 L0 8 z" fill="currentColor"/>'
                 '</marker></defs>')
    # Lanes first so the band sits behind everything; the header is the
    # control that folds the column away.
    for index, lane in enumerate(lanes):
        x = LANE_PAD + index * LANE_STRIDE
        # Two rectangles: the band is the backdrop and takes no clicks, the head is the control
        # — catching clicks on the band folded an area from the gap between two boxes.
        parts.append('<g class="lane" data-area="%s" data-x="%d" data-y="%d" '
                     'data-h="%d">'
                     '<rect class="lane-band" x="%d" y="0" width="%d" '
                     'height="%d" rx="7"/>'
                     '<rect class="lane-head" x="%d" y="0" width="%d" '
                     'height="%d" rx="7"><title>%s</title></rect>'
                     '<text class="lane-name" x="%d" y="%d" '
                     'text-anchor="middle">%s · %d</text></g>'
                     % (svg_escape(lane), x, LANE_FOLD_Y, height,
                        x - 7, NODE_W + 14, height,
                        x - 7, NODE_W + 14, HEADER_H,
                        svg_escape("%s — click to fold this column away"
                                   % lane),
                        x + NODE_W / 2, HEADER_H / 2 + 4,
                        svg_escape(lane), len(members[lane])))
    for child, parent, field in edges:
        if child not in position or parent not in position:
            continue
        cx, cy = position[child]
        px, py = position[parent]
        # The kind is always on the edge; nothing marks one as running backwards, since with a
        # lane per area and a row per number no direction is forward.
        parts.append('<path class="edge %s" data-from="%s" data-to="%s" '
                     'd="%s" marker-end="url(#a)"/>'
                     % (field, svg_escape(child), svg_escape(parent),
                        edge_path(cx, cy, px, py,
                                  area[child] == area[parent])))
    for node in nodes:
        x, y = position[node]
        entry = known.get(node, {})
        # x0/y0 is where the node belongs: collapsing an area moves it onto
        # the lane's header and it has to find its way back.
        parts.append('<g class="node st-%s" data-id="%s" data-area="%s" '
                     'data-x="%d" data-y="%d" data-x0="%d" data-y0="%d">'
                     '<title>%s</title>'
                     '<rect x="%d" y="%d" width="%d" height="%d" rx="5"/>'
                     '<text x="%d" y="%d" text-anchor="middle">%s</text></g>'
                     % (svg_escape(entry.get("status", "")), svg_escape(node),
                        svg_escape(area[node]), x, y, x, y,
                        svg_escape("%s — %s (%s)"
                                   % (node, entry.get("title", ""),
                                      entry.get("status", ""))),
                        x, y, NODE_W, NODE_H,
                        x + NODE_W / 2, y + NODE_H / 2 + 4, svg_escape(node)))
    options = "".join('<option value="%s">%s</option>'
                      % (svg_escape(node), svg_escape(node)) for node in nodes)
    # Each swatch carries the very class the drawing uses, so dash and colour cannot drift;
    # colour is not the only channel, every key being named. Pressed means drawn: every
    # kind starts on and a click subtracts it.
    link_keys = "".join(
        '<span class="key kind" role="button" tabindex="0" '
        'aria-pressed="true" data-kind="%s">'
        '<svg class="graph swatch" width="26" height="9" '
        'aria-hidden="true"><line class="edge %s" x1="1" y1="4.5" x2="25" '
        'y2="4.5"/></svg>%s</span>' % (esc(field), esc(field), esc(field))
        for field in LINK_FIELDS)
    status_keys = "".join(
        '<span class="key st-%s"><span class="dot"></span>%s</span>'
        % (esc(status), esc(status)) for status in STATUSES)
    parts.append(
        '</g></svg><div id="graph-rail"><div id="graph-controls">'
        '<label>around <select id="graph-root">'
        '<option value="">everything</option>%s</select></label>'
        '<label>within <select id="graph-depth">'
        '<option value="1">1 link</option>'
        '<option value="2" selected>2 links</option>'
        '<option value="3">3 links</option></select></label>'
        '<button id="graph-reset" type="button">reset view</button>'
        '</div><div id="graph-legend">'
        '<p class="legend-title">link</p>%s'
        '<p class="legend-title">status</p>%s'
        '</div></div></div>' % (options, link_keys, status_keys))
    return "".join(parts), dropped
# annotation removed on install


# --------------------------------------------------------------------
# Page
# --------------------------------------------------------------------

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>__CSS__</style>
</head>
<body>
<header>
  <h1>__TITLE__</h1>
  <div class="counts"><span id="shown">__COUNT__</span> of __COUNT__ \
requirements · __VERSIONS__</div>
  __PAGES__
  <nav>
    <button data-view="view-reqs" aria-selected="true">Requirements</button>
    <button data-view="view-dash" aria-selected="false">Dashboard</button>
    <button data-view="view-graph" aria-selected="false">Graph</button>
    <button data-view="view-base" aria-selected="false">Baselines</button>
  </nav>
</header>
<div class="layout">
<aside>
  <input id="search" type="search" placeholder="search" autocomplete="off">
  __FILTERS__
  <h2>Documents</h2>
  <ul>__DOCUMENTS__</ul>
</aside>
<main>
  __BANNER__
  <section id="view-reqs">__NOTATION____DIFF____CARDS__</section>
  <section id="view-dash" hidden>__DASHBOARD__</section>
  <section id="view-graph" hidden>__GRAPH__</section>
  <section id="view-base" hidden>__BASELINES__</section>
</main>
</div>
<footer>__FOOTER__</footer>
<script id="baselines-data" type="application/json">__BASEDATA__</script>
<script>__JS__</script>
</body>
</html>
"""


RE_CSS_RULE = re.compile(r"([^{}]+)\{([^{}]*)\}")


# annotation removed on install
def graph_stylesheet():
    """The rules the drawing needs, taken from the page's own stylesheet rather than kept as
    a second copy.

    Light and only light, on an opaque background: an SVG shown as an image is not told
    what theme surrounds it.
    """
    # Comments out first: a rule written after one would otherwise carry
    # the comment inside its selector and match nothing.
    rules = RE_CSS_RULE.findall(re.sub(r"/\*.*?\*/", "", CSS, flags=re.S))
    root = next(body for selector, body in rules if selector.strip() == ":root")
    values = dict(re.findall(r"(--[\w-]+):\s*([^;]+);", root))
    # Literal colours: a renderer that does not resolve a custom property draws a node
    # black on black.
    def resolve(body):
        return re.sub(r"var\((--[\w-]+)\)",
                      lambda m: values.get(m.group(1), m.group(0)), body)
    kept = []
    for selector, body in rules:
        selector = selector.strip()
        if selector.startswith(".graph") or selector.startswith(".st-"):
            kept.append("%s {%s}" % (selector, resolve(body.strip())))
    return "\n".join(kept), values["--bg"]
# annotation removed on install


# annotation removed on install
def neighbourhood(model, chosen):
    """The selection and every requirement one link away, either direction — one step,
    because two steps from anything is most of the specification."""
    known = by_id(model)
    core = set(entry["id"] for entry in chosen)
    wanted = set(core)
    for entry in model["requirements"]:
        targets = set(t for field in LINK_FIELDS for t in entry[field])
        if entry["id"] in core:
            wanted.update(t for t in targets if t in known)
        elif targets & core:
            wanted.add(entry["id"])
    return [entry for entry in model["requirements"] if entry["id"] in wanted]
# annotation removed on install


# annotation removed on install
def graph_image(model):
    """The graph of `model` as one self-contained SVG, or "" where the selection has no edges:
    the page's own drawing, lifted out of its stage and given the styles to stand alone."""
    stage, _dropped = build_graph(model)
    if not stage:
        return ""
    start = stage.index("<svg ")
    end = stage.index("</svg>", start) + len("</svg>")
    drawing = stage[start:end]
    # A backdrop the page gives the drawing through CSS and an image has
    # to carry itself; inserted first so that everything draws over it.
    head_end = drawing.index(">") + 1
    stylesheet, background = graph_stylesheet()
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            + drawing[:head_end]
            + "<style>" + stylesheet + "</style>"
            + '<rect width="100%%" height="100%%" fill="%s"/>' % background
            + drawing[head_end:] + "\n")
# annotation removed on install


# annotation removed on install
def render_baselines(snapshots, logged=()):
    """The picker and the legend; the comparison itself happens in the
    page, from the snapshots embedded beside it."""
    if not snapshots:
        if logged:
            # The log reads anywhere; the states it names live in commits a shallow checkout lacks,
            # and silence here would claim the specification has never been frozen.
            return ("<p><strong>%d baselines are recorded</strong> in "
                    "<code>92-baselines.md</code>, and none of them could be "
                    "read here: comparing them needs the repository's "
                    "history, and this page was rendered without it. Check "
                    "out the full history — <code>fetch-depth: 0</code> on "
                    "GitHub Actions, <code>GIT_DEPTH: 0</code> on GitLab "
                    "CI.</p>" % len(logged))
        return ("<p>No baselines yet. A baseline is a row in "
                "<code>92-baselines.md</code> and the commit that adds it; "
                "see the Baselines section of the standard.</p>")
    missing = len(logged) - len(snapshots)
    short = ("<p class=\"hint\">%d of the %d baselines in the log could not "
             "be read from this checkout's history.</p>"
             % (missing, len(logged)) if missing > 0 else "")
    options = "".join('<option value="%d">%s</option>' % (index, esc(snap["version"]))
                      for index, snap in enumerate(snapshots))
    if len(snapshots) < 2:
        return ("<p>One baseline so far (<strong>%s</strong>) — nothing to "
                "compare it against yet.</p>%s"
                % (esc(snapshots[-1]["version"]), short))
    return (short + '<div class="pickers">'
            '<label>from <select id="base-from">%s</select></label> '
            '<label>to <select id="base-to">%s</select></label>'
            '</div>'
            '<div id="base-result"></div>'
            '<p class="hint">Statements are compared by fingerprint: a '
            'reworded statement shows as a change, its text is not carried '
            'into the page.</p>' % (options, options))
# annotation removed on install


# annotation removed on install
def render_page(model, links, diff=None, baselines=None, named=()):
    # From the log, not the snapshots: which baselines exist is a question the log answers
    # in a checkout too shallow to hold them.
    logged = logged_baselines()
    entries = model["requirements"]
    known = by_id(model)
    diff_state = {}
    if diff:
        for entry in diff["added"]:
            diff_state[entry["id"]] = "new"
        for item in diff["changed"]:
            diff_state[item["entry"]["id"]] = "changed"

    counts = {"status": {}, "type": {}, "area": {}, "file": {}}
    for entry in entries:
        counts["status"][entry["status"]] = \
            counts["status"].get(entry["status"], 0) + 1
        counts["type"][entry["type"]] = counts["type"].get(entry["type"], 0) + 1
        counts["area"][entry["area"]] = counts["area"].get(entry["area"], 0) + 1
        name = file_key(entry["path"])   # annotation removed on install
        counts["file"][name] = counts["file"].get(name, 0) + 1

    filters = []
    for key, values in (("status", list(STATUSES)),
                        ("type", list(model["types"])),
                        ("area", list(model["areas"])),
                        ("file", sorted(counts["file"]))):
        extra = [v for v in sorted(counts[key]) if v not in values]
        chips = render_chips(key, values + extra, counts[key])
        if chips:
            filters.append("<h2>%s</h2>%s" % (key, chips))

    banner = ""
    if model["problems"]:
        items = "".join("<li>%s</li>" % esc(text)
                        for text in model["problems"][:10])
        banner = ('<div class="banner"><strong>%d problem(s) in the '
                  'specification.</strong> Run <code>srs-dd/tools/srs_check.py</code> '
                  'for the full report.<ul>%s</ul></div>'
                  % (len(model["problems"]), items))

    graph_svg, dropped = build_graph(model)
    if not graph_svg:
        graph = "<p>No links between requirements yet.</p>"
    else:
        note = ""
        if dropped:
            families = {}
            for node in dropped:
                # Everything before the number: the family the reader
                # would go looking for, not the bare type.
                families.setdefault(node.rsplit("-", 1)[0], []).append(node)
            counted = ", ".join("%s %d" % (name, len(families[name]))
                                for name in sorted(families))
            note = ("<p>%d node(s) beyond the first %d are not drawn — %s — "
                    "the layout stops being readable past that.</p>"
                    % (len(dropped), GRAPH_NODE_LIMIT, esc(counted)))
        graph = ("<p>A column is an area and a row is a requirement’s "
                 "number, so a line crossing columns is a link that "
                 "leaves its area. A column folds away when its name "
                 "is clicked, and the reset button brings them all "
                 "back. Filters dim the nodes; the layout itself is "
                 "fixed. The rail names the kinds of link and the "
                 "statuses.</p>"
                 "%s%s" % (note, graph_svg))

    # annotation removed on install
    documents = "".join('<li><a href="%s">%s</a></li>'
                        % (esc(links.href(path)),
                           esc(path[len("specs/"):]))
                        for path in model["documents"])
    # annotation removed on install

    # One pass over the template: a requirement whose text contains __GRAPH__ — this tool's
    # own specification — must not have it substituted after the cards are in place.
    filled = dict((
            ("__TITLE__", esc(project_title())),
            ("__CSS__", CSS + EDGE_HIDE_CSS),
            ("__JS__", JS),
            ("__COUNT__", str(len(entries))),
            ("__NOTATION__", notation_legend()),
            ("__FILTERS__", "".join(filters)),
            ("__DOCUMENTS__", documents),
            ("__PAGES__", nav(named)),
            ("__BANNER__", banner),
            ("__DIFF__", render_diff_section(diff) if diff else ""),
            ("__CARDS__", "".join(render_card(e, model, known, links,
                                              diff_state)
                                  for e in entries)),
            ("__DASHBOARD__", render_dashboard(model, links)),
            ("__GRAPH__", graph),
            ("__BASELINES__", render_baselines(baselines or [], logged)),
            ("__BASEDATA__", json.dumps(baselines or [], sort_keys=True,
                                        separators=(",", ":"))
             .replace("</", "<\\/")),
            ("__VERSIONS__", esc(
                ("baseline %s" % logged[-1]) if logged else "no baseline")
             + esc(" · srs_check %s" % model["checker_version"])),
            # No wall-clock stamp on purpose: two runs of the generator
            # must produce byte-identical output.
            ("__FOOTER__", "Generated by srs-dd/tools/srs_view.py from srs_check %s. "
                           "Requirements are rendered; the glossary, the "
                           "constitution and the ADRs are linked, not "
                           "rendered." % esc(model["checker_version"]))))
    pattern = re.compile("|".join(re.escape(token) for token in filled))
    return pattern.sub(lambda match: filled[match.group(0)], PAGE)
# annotation removed on install


def render_site(model, out_dir, diff=None, baselines=None, named=()):
    """The whole page as text, with its links resolved against `out_dir`: how a link is made
    is the page's business, so the caller hands over a directory and gets the text back.
    `named` are the published pages beside this one, which the caller is the only one to know."""
    return render_page(model, Links(model, out_dir), diff, baselines, named)


def project_title():
    """The project's name, borrowed from the agent guide's heading, since §1 would only ever
    say "Introduction" and the directory name is the last fallback."""
    for name in ("AGENTS.md", "CLAUDE.md"):
        try:
            with open(os.path.join(ROOT, name), "r",
                      encoding="utf-8") as handle:
                for line in handle:
                    if not line.startswith("# "):
                        continue
                    title = line[2:].strip()
                    for dash in (" — ", " – ", " - "):
                        title = title.split(dash)[0]
                    if title and not title.startswith("<"):
                        return "%s — specification" % title
                    break
        except OSError:
            continue
    return "%s — specification" % os.path.basename(ROOT)
