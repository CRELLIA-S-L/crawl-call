# §1. Introduction

## 1.1 Purpose

Crawl Call: Chomp Company is a single-player game: the classic snake transplanted into a three-dimensional, multi-level military-shooter arena.
The player steers a snake that crawls over the map geometry and hunts two warring squads of bots.
The bots are not scenery — they fight each other, see the snake, react to it, retreat, coordinate and deal damage.

This specification records what the game does, so that every behavior in the code can be traced to a numbered requirement, and every requirement to the hypothesis it rests on.
The design intent behind it lives in the concept document, `materials/concept/concept-v0.11.md`; the specification is derived from it and, per ART-010 of `constitution.md`, stands above it wherever the two disagree.

## 1.2 Scope

Inside the boundary:

- the snake — steered movement over the map's surfaces, the tail spline, growth, eating, abilities gained from prey;
- the bots — six archetypes, utility-AI deliberation, per-frame execution;
- the commanders — one LLM-driven commander per squad, issuing threat priority, orders, roles and personality weights; bot speech;
- scoring — three multiplying axes (stealth, balance of power, target value), witnessing, bodies, the squad awareness scale;
- maps — multi-level layouts with a navigation graph from the map grid, pre-destructed cover, a text map specification and its tooling;
- view and input — a fixed-angle chase camera; separate input schemes for iOS (touch) and macOS (keyboard and mouse);
- performance and thermal budget on iPhone;
- licensing, identifiers and publication.

Explicitly outside the vertical slice: art, sound, menus, progression, first-person view, a second map, multiplayer, monetization.

## 1.3 Audience

- **The maintainer** — decides what the game is; approves requirements, records playtest observations against hypotheses.
- **Coding agents** — implement against approved requirements and close the loop in the same commit (`AGENTS.md`).
- **Contributors and readers of the public repository** — the project is also a showcase of SRS-DD; the specification and the grounds register are meant to be read, including the bets that were refuted.
