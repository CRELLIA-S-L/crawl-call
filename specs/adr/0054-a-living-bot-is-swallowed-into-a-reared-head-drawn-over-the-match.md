# ADR-0054 — A living bot is swallowed by a reared head, drawn over the match, coming down over it

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-VIEW-320, FR-VIEW-100, FR-VIEW-280, FR-SNAKE-090, FR-SNAKE-280

## Context and problem statement

On 2026-09-29 the maintainer asked for the snake, once coiled round a living bot (FR-SNAKE-280), to swallow it from the top down; a body is eaten as before. The head is held where the coil left it for the whole meal (FR-SNAKE-090), and the snake's head, 1.3 times the body's width (FR-VIEW-260) and so about 0.8 m across, is smaller than a bot's standing figure, 1.12 m tall.
Each needed a way chosen: whether the head rears in the match or only on screen, how a figure taller than the head goes into it, and how the head gets up and down.

## Considered options

For where the rearing happens:

1. On screen only: the head drawn over the bot, the body drawn from it down to where the match has the head.
2. In the match: the head moved up.

For how the figure goes in:

1. The head comes down over the bot, which stays where it stands, as big as it is, cut away above the mouth by its material: its boots are the last of it to show.
2. The head comes down over the bot, which is squashed down to the height still outside the mouth.
3. The bot goes up into the head, smaller as it goes, its top kept at the mouth.
4. Lifted whole into the head.

## Decision outcome

On screen only, and the head coming down over a bot cut away at the mouth.
The match has nothing to gain from a head in the air: the snake is hit, seen and cut open for where its body is (FR-VIEW-150), and a head that moved would move all of that with it for a picture. Drawn, the head is eased from where it lies to where its line comes 0.05 m under the cut over 0.25 s at the meal's start, and back down to where it lies over 0.25 s after it, turned as it rises to face away from its neck, over the bot, and tipped forward mouth-down by 70°, short of straight down so that its eyes still show. The head seen is the rounded end of the body, which points the way the body's line comes into it, so it is the line that is tipped: the neck bends over 0.35 m behind the head at the tip's angle, and the body runs from the head up over that bend and down to where the match has the head — two points more on its line, for which the body's mesh keeps room from the start so that a meal does not make it again. The eyes hang on the head's own centre at the body's end, turned and tipped as it is.
Both were found on the phone the same day: tipped the way it last moved, which after the coil can be back towards the neck, the head put its eyes on its back; and with the eyes tipped round a point on the ground while the body's end still pointed up along a straight neck, they came away from the head altogether.
Option 3 was built first, and the maintainer corrected it on the phone the same day: it is the head that comes down on the bot, not the bot that goes up. Option 2 came next, and read on the phone as the bot pressed into the ground rather than into the snake: squashed, its boots and body flattened with the rest of it. A figure lifted whole would stand through the top of the head for most of the meal.
What is inside the head is not drawn, since a figure taller than the head cannot fit in it. RealityKit clips no model to a plane, so the cut is the figure's material: while the bot is eaten each part of it is drawn with a copy of its own material through a surface shader that clears what lies above the cut's height, and an opacity threshold throws out what is cleared (RealityKitSurfaceShader.h, iOS 27.0 SDK), so that the rest stays opaque. The cut is at the share of the bot's height still outside the mouth, and never below 0.15 of it, so that the boots do not vanish before the match removes the bot (FR-VIEW-100). The part's own materials are kept on it and put back as soon as it is no longer the one being eaten, a new match included.

### Consequences

What the player sees of a meal and where the snake is in the match part by the neck's length for the meal's time: a shot aimed at the reared head in the picture meets the body where the match has it.
