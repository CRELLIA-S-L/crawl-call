# Crawl Call: Chomp Company

Working title. A predator snake in a shooter arena: the classic snake, moved into a three-dimensional multi-level arena where two squads of bots wage war on each other — and the snake hunts them both.

iOS 27+ / macOS 27+ on devices with Apple Intelligence (iPhone 15 Pro and later, Apple silicon Macs), iPhone first. Pre-production; the technical spike is not yet run.

| Where | What |
|---|---|
| `materials/concept/` | The concept document (v0.11) and concept renders |
| `specs/` | The requirements specification — SRS-DD, ISO/IEC/IEEE 29148 |
| `grounds/` | The hypotheses the requirements rest on |
| `arch/` | Architecture parts and what each carries |
| `tools/` | `srs_check.py` and the rest of the SRS-DD tooling (Python ≥ 3.9, stdlib only) |
| `AGENTS.md` | How a coding agent works in this repository |

Check the specification: `python3 srs-dd/tools/srs_check.py`. Read it as a page: `python3 srs-dd/tools/srs_view.py --html`.

License: MIT (`LICENSE`). Third-party assets keep their own licenses.
