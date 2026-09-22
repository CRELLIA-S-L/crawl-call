# ADR-0015 — The baseline device is the iPhone 15 Pro, because the language model sets the floor

- **Status:** accepted
- **Date:** 2026-09-21
- **Related requirements:** CON-PUB-010, NFR-PERF-010, NFR-PERF-050, NFR-PERF-080

## Context and problem statement

Every performance number is measured on "the baseline device", which `30-nfr.md` defined as the oldest iPhone that runs iOS 27, without naming it (Q-150).
Apple's iOS 27 compatibility list, read on 2026-09-21, starts at the iPhone 11.
Apple's Apple Intelligence support page, read the same day, says the system language model the game is built on (ADR-0008) is available on the iPhone 15 Pro, 15 Pro Max, iPhone 16 models and later, and iPhone Air — not on the iPhone 11 to 15.

## Considered options

1. Baseline iPhone 11: the game must run without commanders and generated speech on devices that cannot run the model.
2. Baseline iPhone 15 Pro: the game requires a device with Apple Intelligence; older iPhones are out.
3. Two baselines: rendering on the iPhone 11, the model on the 15 Pro.

## Decision outcome

Option 2.
The commanders and the voices are the product (I-010, H-040, H-050); a build of the game that cannot run them is a different game, and option 1 would have the project maintain that other game for the four device generations that cannot run this one.
Option 3 measures a frame budget on a device the game will never ship on.
The concept already accepted that "devices older than iOS 27 are out"; this moves the line four years forward, knowingly, to where the model is.

### Consequences

CON-PUB-010 requires an Apple Intelligence-capable device: iPhone 15 Pro or later, and on the Mac, Apple silicon.
The baseline device for every `A` measurement is the iPhone 15 Pro; the thermal budget (NFR-PERF-050) is measured on it.
Until one is at hand, measurements are taken on the maintainer's iPhone 16 Pro and pass only with a 20 % margin (`50-verification.md`); a result inside the margin is not a pass, it is a reason to borrow a 15 Pro.
The App Store listing declares the device requirement, and the store's compatibility filter keeps the game off devices that cannot run it.
If Apple widens the model's availability, the baseline can move back; nothing in the specification names a chip.
