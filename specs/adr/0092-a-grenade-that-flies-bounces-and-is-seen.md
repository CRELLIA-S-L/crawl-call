# ADR-0092 — A grenade that flies, bounces and is seen

- **Status:** accepted
- **Date:** 2026-10-13
- **Related requirements:** FR-BOT-580, FR-BOT-590, FR-VIEW-350, FR-VIEW-360, FR-BOT-470, FR-BOT-500, FR-BOT-405, IF-BOT-010, IF-VIEW-020, IF-MAP-020, NFR-PERF-020

## Context and problem statement

The fourth pass of `materials/plans/the-reload-and-the-rush.md` carries out the maintainer's last two asks of 2026-10-13: a grenade must be drawn and must have the physics of a thrown thing, bouncing off surfaces, and the blast must be drawn too. Until this pass a grenade was a point that appeared where it was aimed, lay there for its fuse and took four bots with it, with nothing on screen either before or after.

## Decisions

**The arc is a velocity and not a path.** A throw leaves the hand at forty-five degrees and at the speed that lands it at the aim point under the tuning's gravity — for a flat distance `d` and a launch angle θ, `√(g·d ÷ sin 2θ)`, which at 45° is `√(g·d)`. The gravity is the one a falling thing already has (IF-MAP-020, FR-SNAKE-220): a second gravity in one arena would be two answers to one question. A throw aimed further than the grenade's range leaves at the speed its range allows and falls short, which is what makes the range a limit rather than a number.

**The bounce turns one component and damps the whole.** What a step meets is read the way a round's is (`Sight.firstStop`, FR-BOT-405); the arena is a grid of modules square with the axes, so the face is an axis, and the axis is found by feeling five centimetres ahead along each of the three and taking the one that is blocked. That component turns round and **the whole velocity is scaled by the restitution**. Scaling only the reflected component was built first and measured: with nothing taking the horizontal speed away, a grenade slid along the floor at its throwing speed for the whole fuse and went off some six metres past what it was thrown at, which `GrenadeTests` caught at once. Below a tenth of a metre a second the grenade is at rest and only burns its fuse.

**A corner stops the grenade.** Where none of the three axes is blocked, or more than one is, the face cannot be told and the grenade stops where it is rather than guessing. That is a lie about a bounce and never a grenade inside a wall.

**FR-BOT-500 refuses the aim and not the landing.** This was the maintainer's question before the pass, and the plan recommended the answer taken: a bot refuses to throw where it *aims* at a squadmate. To refuse the landing, every throw a bot scores would have to be flown before it is thrown — about a hundred and twenty steps of a sixtieth of a second, each asking the scene what it meets, against a deliberation budget of half a millisecond for everything (NFR-PERF-020). So a grenade can bounce back onto a squadmate, which is what every other weapon in this game already does to whoever is in the way (ADR-0075).

**A blast is a value in the match with a life the frame counts down.** The view draws what the match holds and keeps no clock of its own, so a blast that is over in an instant is kept as a `Flash` — where it went off, how wide, and how much of its moment is left — and the match ages it each frame. How long that moment is belongs with the view's numbers (IF-VIEW-020, shipped at 0.45 s).

**Two pools of balls, made once.** A grenade is a small dark ball drawn where it is; a blast is a pale see-through ball grown from nothing to the blast radius over its moment. Both are pools made once and moved, for the reason the tracers' pool exists (FR-VIEW-170): a thing that comes and goes several times a second would otherwise build and throw away a mesh as often. The grenade pool holds every bot's whole pouch and one over.

## Consequences

**A grenade is answerable in a way it was not.** It is on screen for the two seconds of its fuse, where it is rather than where it was aimed, so a player can see one coming and take the snake away from it.

**Where a grenade goes off is no longer exactly where it was aimed.** Measured on the open strip: thrown six metres, it comes down and settles within the blast radius of the aim point, which is what `FlightOfAGrenadeTests` asserts. A grenade thrown at a wall comes back off it and can go off nearer the thrower than the aim.

**The blast reaches a squad's own, and will be seen doing it.** It always could (FR-BOT-480, ADR-0075); with a bounce it can now happen without the thrower ever aiming near its own, and the first time it is seen on the phone it will look like a bug.

**A grenade thrown off a ledge is answered by what the scene holds and nothing else.** The flight asks the scene what the step meets, and the floors are pieces of the scene like everything else, so a grenade that leaves one floor falls to the next. Nothing special is done about floors, and nothing in the shipped arena has two.
