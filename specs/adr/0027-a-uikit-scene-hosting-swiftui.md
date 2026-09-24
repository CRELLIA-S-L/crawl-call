# ADR-0027 — The app is a UIKit scene hosting SwiftUI, so that its window can speak to iPadOS

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-VIEW-210, FR-VIEW-220, FR-VIEW-230, CON-PUB-010

## Context and problem statement

On 2026-09-24 the game gained the iPad (CON-PUB-010), and with it iPadOS 26's windows: an app can no longer opt out of multitasking and resizing ("Because `UIRequiresFullScreen` is deprecated, you can no longer opt out of iPad multitasking and dynamic resizing", *Managing your Metal app window in iPadOS*).
What Apple leaves a game is three things, and each is reached through UIKit: a root `UIViewController` overriding `prefersInterfaceOrientationLocked` (iOS 26), a `UIWindowScene`'s `sizeRestrictions.minimumSize`, and a `UIWindowSceneDelegate` told `windowScene(_:didUpdateEffectiveGeometry:)`.
The entry point was a SwiftUI `App` with a `WindowGroup`, whose window and root controller SwiftUI creates and keeps; the SwiftUI interface of the installed SDK has no modifier for any of the three on iOS — `windowFullScreenBehavior` and `windowResizeBehavior` are `@available(iOS, unavailable)`.

## Considered options

1. Keep the SwiftUI `App`, add a scene delegate through `UIApplicationDelegateAdaptor`, and reach the window scene from it.
2. A UIKit `@main` app delegate and scene delegate that build the window around a subclass of `UIHostingController` holding the same SwiftUI views.

## Decision outcome

Option 2.
Option 1 reaches the scene but not its root controller: SwiftUI's own hosting controller answers `prefersInterfaceOrientationLocked` with its default, and there is no public way to subclass or configure it.
`UIHostingController` is declared `open` in the installed SDK, so a subclass is the documented way to put SwiftUI in a UIKit window and still answer as a view controller.

### How it works

`AppDelegate` (`@main`) answers `application(_:configurationForConnecting:options:)` with a configuration whose `delegateClass` is `SceneDelegate`.
`SceneDelegate` reads the world once, at connection — the moment the interface requirements name — sets `sizeRestrictions.minimumSize` to `GameWindow.minimumSize` where the platform resizes scenes, and makes a window whose root is `GameHostingController(rootView: GameRoot(…))`.
`GameHostingController` answers `prefersInterfaceOrientationLocked` with whether the idiom is the iPad, and `prefersStatusBarHidden` with true — a root controller of UIKit's own does not carry the Info.plist's hidden status bar past launch.
`SceneDelegate.windowScene(_:didUpdateEffectiveGeometry:)` hands the lock before and after to `MatchHost`, which pauses the match only when the lock changed and the player has steered it (FR-VIEW-230): iPadOS grants the lock in the same millisecond the scene becomes active, and pausing on that would open every launch on a paused match.
`MatchView` reports its frame's aspect to the session, and the camera narrows the span it keeps the head in across a frame taller than it is wide (FR-VIEW-020, FR-VIEW-210).
Invariants: the window's root is a `GameHostingController`; the scene's minimum size is the controls' — `WindowTests` checks both on the scene the suite itself runs in.

It stops working on a device that ran the build whose entry point was the SwiftUI `App`: iOS restores a scene session with the configuration it was made with, `SwiftUI.AppSceneDelegate`, without asking the app delegate again, and that delegate draws nothing — a black screen, seen on the iPad and iPhone simulators on 2026-09-24.
Closing such sessions from the app was tried and works on the iPad, but on the iPhone UIKit refuses both halves ("Invalid attempt to call -[UIApplication requestSceneSessionDestruction:] from an unsupported device"; "Cannot request scene session activation because it is not supported on the current device").
The game has not been released, so the only devices affected are the maintainer's and the simulators: on each, the app is closed once from the app switcher — which discards its scene session — or reinstalled.

### Consequences

The entry point is a UIKit scene, and the SwiftUI views under it are unchanged.
A device that ran the SwiftUI build is closed from the app switcher once after the update.
The scene manifest stays generated; the configuration comes from code, so a scene the system restores carries the configuration it was made with.
