// The game's entry point. It holds no behaviour yet: the camera arrives with
// FR-VIEW-010 and FR-VIEW-020, the arena with the map pipeline (FR-TOOL-020),
// and the snake with FR-SNAKE-010. What this file is for is the vessel — a
// target that builds, signs and launches on the device the slice is measured on.
import RealityKit
import SwiftUI

@main
struct CrawlCallApp: App {
    // `Scene` is qualified: SwiftUI and RealityKit both export that name, and
    // App.Body is constrained to SwiftUI's (App, SwiftUI documentation).
    var body: some SwiftUI.Scene {
        WindowGroup {
            RealityView { _ in
                // Empty on purpose: nothing is placed in the scene until the
                // requirement that puts it there is built.
            }
            .ignoresSafeArea()
        }
    }
}
