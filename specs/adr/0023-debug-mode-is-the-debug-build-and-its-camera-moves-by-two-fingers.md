# ADR-0023 — Debug mode is the Debug build, and its free camera moves under two and three fingers

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-TOOL-070, FR-VIEW-010, FR-VIEW-020, FR-VIEW-050, IF-VIEW-020

## Context and problem statement

On 2026-09-24 the maintainer asked to zoom and pan the scene themselves, to look at what is in it in detail. The specification already has that as FR-TOOL-070: where debug mode is enabled, the camera is detached from the snake and moved freely. Six requirements begin "where debug mode is enabled", and none says how it is enabled; nothing of debug mode existed in the code. The maintainer left the choices to the agent and asked that they be recorded.

## Considered options

For what debug mode is:

1. The Debug build configuration — what the scheme's Run action builds, and what every build put on the phone for this project has been; its Archive and Profile actions build Release, which carries none of it.
2. A switch inside the app, in a settings screen or behind a gesture.
3. A launch argument or an entry in a configuration file.

For how the camera is moved:

1. Two fingers: a pinch zooms, a drag pans, a twist turns; three fingers dragged up or down tilt.
2. A button that toggles the stick between steering the snake and moving the camera.

## Decision outcome

Debug mode is the Debug build configuration, option 1: it needs nothing built to switch it, and it cannot reach a player by accident, since what the App Store is given is an archive, which the scheme builds in Release, where the code is not compiled in. A build profiled in Instruments is Release too, and has no free camera. A switch inside the app would be a screen to build and a way for the mode to ship; a launch argument cannot be set from the phone's home screen.

The camera moves under two and three fingers, option 1. The stick steers with one finger in the bottom-left corner and the eat button is in the bottom-right (FR-VIEW-050), so two or three fingers anywhere on the arena are never taken for either, and the match can be played and looked at in the same moment. A toggle would stop the snake to look at it. Tilting has three fingers because a two-finger drag already pans, and the two cannot be told apart by their start.

**What moving it means.**

- The first pinch or two-finger drag takes the camera off the snake; from then on it stays where it was put, and the snake goes on without it. A button that appears in the top-right corner while the camera is free puts it back on the snake, where the match would have had it by then: the following goes on underneath while the camera is away.
- A pinch changes how far the camera is from the point it looks at, by the pinch's factor — apart is nearer — and no nearer or further than the two limits of the view configuration (IF-VIEW-020), 2 m and 20 m as shipped. At two metres the screen's height spans about 1.9 m of what is looked at, through the match's field of view of 50 degrees, so a figure of 1.12 m takes more than half of it; twenty is past the whole blockout, which the match frames from about thirteen.
- A drag moves the point looked at so that the ground under the fingers goes with them: as far across the ground as the drag is across the screen at the distance the camera is at, and further up and down the screen, where the pitch foreshortens the ground. The point looked at stays over the arena, as the following camera does (FR-VIEW-020).
- A twist of two fingers turns the camera round the point it looks at, as far as the fingers turn and without a limit, so that the ground turns with them. The recognizer reports the twist in radians (`UIRotationGestureRecognizer.h`, iOS 27.0 SDK) and does not say which direction is positive; clockwise on the screen is taken as positive, which is what the ground turning with the fingers needs, and it is checked on the phone rather than in the SDK.
- A drag of three fingers up the screen lowers the camera towards the horizon and down the screen raises it towards looking straight down, the whole height of the screen being the whole range between the two pitch limits of the view configuration, 10 and 90 degrees as shipped. Straight down is allowed: the camera is turned before it is tilted, so even looking straight down its turn says which way the screen's up is, and a test holds that it does not roll there.
- A drag after a turn still takes the ground with the fingers, along the screen's axes as they now lie on the ground.
- FR-VIEW-010 fixes the pitch and the yaw while a match runs; on 2026-09-24 the maintainer, having used the zoom and the pan, asked for tilt and turn as well, and FR-VIEW-010 now excepts a camera the user holds in debug mode. At first this decision kept the match's pitch and yaw, reading FR-TOOL-070's "freely" as anywhere over the arena and not any angle; it is the maintainer's request that settled the reading the other way. The button that gives the camera back to the snake gives back the match's pitch and yaw with it.
- What is cut open for the snake is judged from wherever the camera is (FR-VIEW-150, FR-VIEW-155), as it was: the see-through asks the camera where it stands.

### Consequences

The other five debug-mode requirements now have a mode to live in, and each is built into the same place when it is built.

The gestures are UIKit's recognizers given to SwiftUI through `UIGestureRecognizerRepresentable` (SwiftUI, iOS 18.0), because SwiftUI's own drag cannot be told to wait for two fingers. What they are turned into — the camera's distance and focus — is tested; the recognizers themselves are tried on the phone.

A Release build has no free camera and no button: the modifier that adds them is compiled there with a body that passes the view through untouched, and the gestures and the button are not compiled at all. The tests run in Debug and cannot see this; it was checked on 2026-09-24 by building both configurations and looking for the gesture types in each binary — present in the Debug build, absent from the Release one.
