# Crawl Call: Chomp Company
<!-- SRS-DD-0.20.1 — installed by the framework; --force overwrites local edits -->

`AGENTS.md` is the shared agent guide for this SRS-DD project, and it is imported here so that every session starts with it in front of you rather than behind a pointer:

@AGENTS.md

Claude-specific additions:

- **Invoke the `srs` skill** before any code change that alters behavior, when planning a task — it also covers multi-requirement plans — and when the question is how the system works rather than a change to it.
- To author a new requirement through a dialog, use the `srs-new` skill;
  to audit spec ↔ code drift, test adequacy and the links between requirements, use `srs-audit`.
- To check a finished change, use the `srs-check` skill — it reads what each touched requirement asks for and offers to run exactly that; to read the specification as a page, `srs-page`.
- To freeze the specification at a milestone, use the `srs-baseline` skill — it shows what changed, agrees the number with you, and writes the row; the commit stays yours.
- To pick up a new framework version, use the `srs-upgrade` skill — one command, no framework clone to keep around.
