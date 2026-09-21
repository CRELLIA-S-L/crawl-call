# ADR-0007 — MIT for code and assets; a paid build in the App Store

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** CON-PUB-020, CON-PUB-030, CON-PUB-090

## Context and problem statement

The source is open and a paid build is sold in the App Store by the company.
The licence has to allow that, allow contributions into the paid build without a contributor agreement, and match the company's existing policy.

## Considered options

1. MIT — App Store compatible; contributions unrestricted; closed clones permitted.
2. Apache-2.0 — the same plus patent protection.
3. MPL-2.0 — the same; modified files must stay open (Firefox for iOS ships under it).
4. GPL — conflicts with the App Store by the FSF's position; contributions ship only with the author's consent or a CLA.

## Decision outcome

Option 1: the same licence as SRS-DD, one policy for the company.
GPL is out because contributors' GPL code cannot ship in the App Store without their consent — what took VLC down — and a CLA is bureaucracy that scares contributors off.
Assets fall under the same MIT: they are assembled by scripts from the repository, and a separate licence would add nothing; third-party kits keep their own (CON-PUB-030).

### Consequences

Closed clones under another name cannot be prevented, and that is accepted knowingly.
What protects sales is not the code but the trademark on name and logo — registered by the company, before the public announcement — and Apple's rule 4.1 against copycats; and on iOS a self-built copy is a real barrier (Mac, Xcode, a developer account, a seven-day build).
This is the project's reading of the licences for its own decisions and not legal advice; the terms are checked with a lawyer before publication.
