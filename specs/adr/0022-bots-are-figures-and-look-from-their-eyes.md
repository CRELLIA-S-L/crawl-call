# ADR-0022 — Bots are figures of rounded primitives, and they look and fire from their eyes

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-VIEW-060, FR-VIEW-070, FR-VIEW-100, FR-VIEW-170, FR-BOT-050, FR-BOT-060

## Context and problem statement

Until this decision a bot was drawn as a round-cornered box in its squad's colour, 1.6 m tall.
FR-VIEW-070 asks for an archetype readable from its silhouette, by headgear and weapon, and a box has neither; FR-VIEW-060 waited on the same thing for the third of its channels.
The box also kept the bots' sight on the floor: FR-BOT-050's rationale measured a line of sight along the surface a bot stands on, deliberately, because a box has no head for an eye height to be measured from, and said it would be revisited when bots got models.

On 2026-09-24 the maintainer chose, of the ways put to them: figures assembled in code from primitives, static for now, and the bots' sight moved to the height of their heads. They approved an eye height of 1.25 m — brought down to 0.875 m the same day and moved into configuration, below — fire from the same height, the rewritten paragraph of FR-BOT-050, and the table of headgear and weapons below. The build given to playtesters for H-010 is not touched by this; the maintainer said so, and H-010 is not changed.

## Considered options

1. Figures assembled in code from RealityKit's generated primitives.
2. Figures modelled in Blender by script and exported as USDZ, as the concept allows for (FR-TOOL-130).
3. Characters from a CC0 pack such as Quaternius, under CON-PUB-030.

## Decision outcome

Option 1, the maintainer's choice. ADR-0002 already has the game assembled from rounded primitives, and the concept's line-up of the archetypes (`materials/concept/render-03.jpg`) was made that way; a figure in code needs no pipeline, no asset files and no licence, and what it is made of can be read by a test.

**The figure.** Each figure is described as data — its parts, where they stand, what they are painted with — and built from that, so that a test reads the description and the screen shows what was built from it. The figure is a model and knows only its own proportions: it is drawn as a figure 1.6 m tall with its eyes at 1.25 m, a big head and a short body as the concept draws them, and it is set down at the height the bot configuration gives it (`figureHeight`, IF-BOT-010). Its origin is between its feet, so that it stands on the floor where the bot stands and shrinks into the floor as it is swallowed. It faces +z, towards the camera, because a bot has no facing to turn it by. Its body and its headgear are in the squad's colour; legs, boots, skin and weapons are shared by both squads.

| Archetype | Headgear | Carried |
|---|---|---|
| Assault | a round helmet | a short automatic across the chest |
| Heavy | a wider helmet with goggles, on a broader body | a thick tube on the shoulder, pointing forward |
| Sapper | the helmet with a lamp on its brow | a sledgehammer held upright |
| Scout | a cap with a peak | a pistol at the side |
| Sniper | a knitted hat with a bobble | a long rifle held out in front |
| Medic | the helmet with a white band over it | a pistol, and a white satchel on the hip |

The scout and the medic carry the same pistol; the medic's satchel is what tells what they carry apart, and their headgear differs.
The medic wears no red cross, although the concept's render shows one: the red cross is an emblem protected by the Geneva Conventions and by national law, and games keep off it.

**Squad in the silhouette.** FR-VIEW-060 names the silhouette of the equipment as one of three channels for the side. Both squads share one set of six silhouettes (concept §8, FR-VIEW-070), so a silhouette cannot differ by squad; what it carries of the side is its colour. The headgear — the part that names the archetype — is drawn in the squad's colour, which is the colour of the body and of the tracers, taken from one place.

**The size and the eyes are configuration.** How tall a figure is drawn and how high a bot's eyes are, in metres, are two numbers of the bot configuration, `figureHeight` and `eyeHeight`. The figure does not read the eye height and the bots do not read the figure: the model is a model, and what it is set down at and where a bot looks from are settings. The shipped numbers keep them together — the eye height is the figure's height times the share of it the figure's eyes are painted at, 1.25 of 1.6 — and a test holds that; a configuration that set them apart would have bots looking from somewhere their figures have no eyes, which is its author's choice to make. The first build set the eyes at 1.25 m and the figure at 1.6 m, both fixed in code; on 2026-09-24 the maintainer, looking at it on the phone, had the figures 30% smaller — 1.12 m, eyes at 0.875 m — and then had both numbers moved out of the code, because a model's size is not the model's business.

**What looks from the eyes.** A bot's line of sight to the snake runs from its eyes to the ground under each part of the snake — the same points ADR-0019 asks about for the view. How far away the snake is, against the detection range, is still measured from where the bot stands. The line test is ADR-0019's own and needed nothing new: its height cut-off already keeps the floor the snake lies on out of the answer when the eye is above it.

**What fires from the eyes.** The line of fire is the line of sight: a bot checks it from its eyes before it fires and the shot leaves from there (FR-BOT-060), so that what a bot can see over it can shoot over. The shot as the model records it runs from the shooter's eyes to the point aimed at, and the view draws exactly that line, adding no height of its own (FR-VIEW-170).

**What does not change.** A bot choosing cover asks whether the snake can see the cell, and the snake looks from the ground, as before. The snake has no eyes in the model; that question is left as it was.

### Consequences

On the blockout, at eyes of 0.875 m, the change is small. Its lowest standing module is the fence, 0.8 m, and a line from the eyes of a bot standing against a fence comes down below the fence's top before it is past it unless the snake is more than about 7.7 m away — which only the sniper's detection range of 9 m reaches. Crates, a metre tall, stand above the eyes and hide the snake as they did. The bots are therefore about as hard to approach as in the build the playtesters have. At the first approved 1.25 m they would have seen over the crates and fences and been noticeably harder; that is what the eye height costs if the figures ever grow again, and what it buys a map with cover lower than the kit's. That makes the bots harder to approach than they were in the build the playtesters have.

The bulge and the boots of FR-VIEW-100 still wait on the snake: a figure has boots, and the snake has no mouth for them to stick out of.

A match carries about a dozen parts per bot instead of one box, with the materials made once per squad and shared. What that costs to draw is not measured, like the rest of NFR-PERF-010 (Q-250).
