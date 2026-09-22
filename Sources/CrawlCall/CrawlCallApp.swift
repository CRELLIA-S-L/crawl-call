// The game's entry point. It holds no behaviour yet: the camera arrives with
// FR-VIEW-010 and FR-VIEW-020, the arena with the map pipeline (FR-TOOL-020),
// and the snake with FR-SNAKE-010. What this file is for is the vessel — a
// target that builds, signs and launches on the device the slice is measured on.
// Starting the app is the moment the interface requirements name for reading them.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010
import RealityKit
import SwiftUI

@main
struct CrawlCallApp: App {
    /// Read once, at start, because that is the moment the interface requirements name.
    /// Not private: a test constructs the app to check that starting it reads them.
    let configurations = Launch.load()

    // `Scene` is qualified: SwiftUI and RealityKit both export that name, and
    // App.Body is constrained to SwiftUI's (App, SwiftUI documentation).
    var body: some SwiftUI.Scene {
        WindowGroup {
            switch configurations {
            case .success:
                RealityView { _ in
                    // Empty on purpose: nothing is placed in the scene until the
                    // requirement that puts it there is built.
                }
                .ignoresSafeArea()
            case .failure(let error):
                // A launch that cannot read its tuning says so instead of running on
                // numbers nobody chose.
                Text(error.description)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }
}
