// The root of the window: SwiftUI's hosting controller, asking iPadOS to lock the
// interface orientation while the game fills the screen (FR-VIEW-220).
//
// The request is a property of a `UIViewController` (`prefersInterfaceOrientationLocked`,
// iOS 26), and the controller SwiftUI's own `App` creates cannot be told to make it,
// so the window is built by the scene delegate around this subclass (ADR-0027).
//
// file implements: FR-VIEW-220
import SwiftUI
import UIKit

final class GameHostingController<Content: View>: UIHostingController<Content> {
    /// Only on an iPad: an iPhone plays landscape and full screen already, and a lock
    /// there would only stop the game turning over when the phone does.
    override var prefersInterfaceOrientationLocked: Bool {
        traitCollection.userInterfaceIdiom == .pad
    }

    /// The whole screen is the arena's: the status bar is hidden while the game is up,
    /// as the Info.plist asks at launch and a root controller of UIKit's own does not
    /// carry on by itself.
    override var prefersStatusBarHidden: Bool { true }
}
