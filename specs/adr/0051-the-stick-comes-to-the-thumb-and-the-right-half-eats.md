# ADR-0051 — The stick comes to the thumb, and the right half of the screen eats

- **Status:** accepted
- **Date:** 2026-09-29
- **Related requirements:** FR-VIEW-050, FR-VIEW-160, FR-VIEW-190, FR-TOOL-070, FR-TOOL-260

## Context and problem statement

On 2026-09-29 the maintainer asked for the stick to appear wherever a finger lands on the left of the screen, as most games on a phone do it, and for a meal to begin on a touch anywhere on the right.
Until then the stick and the eat button each sat in a lower corner, and a thumb had to find them on glass it cannot feel.

Apple's advice for the iOS 27 generation is the same for a thumbstick: its area is the whole half of the screen, and it is hidden while nobody touches it (WWDC26, "Make your game great with touch"). Its Touch Controller framework (iOS 26) gives a control a collider of either half, `TCColliderShape.leftSide` and `.rightSide`, and hides a thumbstick not pressed with `hidesWhenNotPressed`.
Each needed a way chosen: what draws the controls, where the stick is while no thumb is on it, when a meal is asked for, and what a control drawn over the arena does with a touch that lands on another one.

## Considered options

1. Touch Controller.
2. SwiftUI, as the controls were: each half a view of its own with its own gesture.

For the stick with no thumb on it:

1. Resting in the lower corner, where it was, and coming to the thumb when one lands.
2. Hidden, as Apple advises and Touch Controller does.

For the meal:

1. Asked for as the thumb lands.
2. Asked for as it lifts, as a button does.

## Decision outcome

SwiftUI. Touch Controller draws its controls with Metal into a render pass it is handed (`TCTouchControllerDescriptor(mtkView:)`, `render(using:)`), and the game is drawn by RealityKit's `RealityView`, which hands out no render pass to draw into. The rule it would have brought is kept: each thumb's area is a whole half.

The stick is hidden while no thumb is on it, as Apple advises: the maintainer's call on 2026-09-29, over a stick resting in its corner as a sign that the left half steers. When a thumb lands the stick appears under it, moved in only as far as it takes for the whole plate to be on the half; the direction is the thumb's travel from where it landed, so that a thumb landing by an edge does not steer by the distance the plate was moved in. When the thumb lifts the stick is gone.

The meal is asked for as the thumb lands, once a touch: in a game a press acts when it lands, and the snake reaching a bot is a moment the player is waiting for. A touch with nothing in reach asks for a meal that begins nowhere, which the match already ignores.

The eat button stays where it was and says whether a touch would begin a meal (FR-VIEW-160), but it takes no touch of its own: the whole half answers. For VoiceOver it is still a button, with the same action.

The controls are drawn under everything else over the arena. The debug switches of FR-TOOL-260 and the button that puts the free camera back on the snake (FR-TOOL-070) sit in the top corners of the halves, and a control over them would take their touches; the plate at the end of a match and the pause plate (FR-VIEW-190, FR-VIEW-230) are drawn only when the controls are not.

### Consequences

Nothing on the screen is out of a thumb's reach any more, and a touch on the right half in the middle of the arena is a meal asked for: a later control on the right, an ability button, has to be drawn over the half, as the debug switches are.
The free camera's two- and three-finger gestures are carried by the view the controls now lie inside, and they reached it through the halves too readily: a thumb on the stick and one on the right half are two fingers, and every meal panned, zoomed and turned the camera away from the snake, which the maintainer found on the phone on 2026-09-29. A camera gesture now does not begin on touches that lie on both halves; two or three fingers of one hand on one half still move the camera.
Apple's advice to take a control that cannot act off the screen is not followed: the eat button stays, dim, because FR-VIEW-160 asks it to say that there is nothing to eat.
