---
name: srs-page
description: Render the specification as one self-contained HTML page and open it — for reading rather than grepping, and for handing to somebody who will never clone the repository. Invoke when the user asks to see, show, open, render or share the specification, the requirements or the documentation as a page.
---

# Reading the specification as a page

One command renders it and opens it:

```
python3 tools/srs_view.py --open
```

It writes `.srs-site/index.html` — the directory ignores itself, so nothing lands in the project's history — and opens it in the reader's browser.
Give a path to put it elsewhere:
`--html docs/spec.html --open`.

## What the command does not say

**The file is self-contained.** No network, no CDN, no server: it opens from `file://` and it can simply be sent to somebody.
That is what makes it the answer for a reviewer, a new joiner, or anyone outside the repository.

**Links to code work only if the page knows where the code lives.** Pass the forge address once:

```
python3 tools/srs_view.py --html public/index.html \
    --repo-url https://github.com/<owner>/<repo>/blob/<sha>
```

Without it the paths are still shown, they just do not lead anywhere.

**CI may already publish it.** The templates in `ci/` render the same page from the default branch, so a link may exist that is always current — check before mailing a copy that will be stale next week.

**Baselines need history.** The page compares frozen states by reading the commits behind them; a shallow checkout has none, and the page says so instead of pretending there are none.

## When it is the wrong tool

For a question about one requirement — what it links to, what breaks if it changes — the terminal answers faster:
`python3 tools/srs_view.py <ID>`, or `--code <path>` from the other end.
The page is for reading a specification, not for interrogating it.
