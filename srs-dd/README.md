# SRS-DD — the framework's directory

<!-- SRS-DD-0.24.0 — the framework release this directory came from -->
<!-- Copyright (c) 2026 CRELLIA S.L. — part of SRS-DD, distributed under the MIT License -->

Everything in this directory belongs to the framework and is rewritten by every upgrade: the tools under `tools/`, the standard of the specification (`standard.md`) and of each layer the project keeps (`grounds.md`, `arch.md`), the articles of the method (`method.md`), the source of the framework's guide (`guide.md`) and the licence.
Nothing of the project's goes here, and nothing here is edited by hand — a change to the method is made in the framework, and a project that wants to depart from it does so in its own files.
An upgrade rewrites what the framework owns and names every other path it finds here; it deletes nothing it did not write, so a file of yours that ends up here is reported and left for you to move.
The procedures under `.claude/skills/srs-*` and the region of `AGENTS.md` between `<!-- srs-dd -->` and `<!-- /srs-dd -->` are the framework's too; they live outside only because the client looks for them there.
