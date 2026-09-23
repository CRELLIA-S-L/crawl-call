// The game's entry point. Starting the app is the moment the interface requirements
// name for reading the configurations, and the moment a match begins.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-VIEW-050, FR-VIEW-060
import RealityKit
import SwiftUI

@main
struct CrawlCallApp: App {
    /// Read once, at start, because that is the moment the interface requirements name.
    /// Not private: a test constructs the app to check that starting it reads them.
    let world = Launch.world()

    // `Scene` is qualified: SwiftUI and RealityKit both export that name, and
    // App.Body is constrained to SwiftUI's (App, SwiftUI documentation).
    var body: some SwiftUI.Scene {
        WindowGroup {
            switch world {
            case .success(let world):
                MatchView(world: world)
            case .failure(let error):
                // A launch that cannot read its tuning or its map says so instead of
                // running on numbers nobody chose.
                Text(String(describing: error))
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }
}

/// A match on screen: the arena, the snake in it, and a finger steering.
struct MatchView: View {
    let world: World
    @State private var session: GameSession?

    var body: some View {
        RealityView { content in
            let (scene, seeThrough) = SceneBuilder.scene(for: world.plan,
                                                         pitchDegrees: world.configurations.view.cameraPitch)
            content.add(scene)

            guard let start = Game.start(in: world),
                  let camera = scene.children.first(where: { $0.name == "camera" }),
                  let map = scene.children.first(where: { $0.name == "map" }),
                  let ambient = scene.children.first(where: { $0.name == "ambient" }) else { return }

            let game = Game(world: world, start: start)
            let snake = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                         segments: game.snake.segments)
            for part in snake.children {
                part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
            map.addChild(snake)

            let squads = BotEntity.make(for: game.bots)
            for body in squads.children {
                body.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
            map.addChild(squads)

            let session = GameSession(game: game, snakeEntity: snake, botEntities: squads,
                                      camera: camera, seeThrough: seeThrough,
                                      distance: max(world.plan.bounds.extent.x, world.plan.bounds.extent.z) * 1.1,
                                      fieldOfView: 50)
            self.session = session
            // One step per frame, from the frame's own delta.
            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                session.step(seconds: event.deltaTime)
            }
        }
        .ignoresSafeArea()
        // FR-VIEW-050: the direction comes from a swipe and is held while the finger
        // stays down; letting go stops the snake.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in session?.apply(TouchScheme.intent(fromDrag: value.translation)) }
                .onEnded { _ in session?.apply(TouchScheme.release) }
        )
    }
}
