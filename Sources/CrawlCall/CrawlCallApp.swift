// The game's entry point. Starting the app is the moment the interface requirements
// name for reading the configurations, and the moment a match begins.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-VIEW-050, FR-VIEW-060, FR-VIEW-160, FR-VIEW-190
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

            // The shots go on the map beside the bodies that fire them (FR-VIEW-170),
            // lit by the same light: a tracer darker than the body that fired it is
            // not the same colour any more (FR-VIEW-060).
            let shots = ShotEntity.make(for: game.bots)
            for bar in shots.children {
                bar.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
            map.addChild(shots)

            let session = GameSession(game: game, snakeEntity: snake, botEntities: squads,
                                      shotEntities: shots,
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
        // One or the other, never both (FR-VIEW-190): while the match is on, the
        // controls; once it is over, the plate that says how it ended and starts
        // another.
        .overlay {
            if let outcome = session?.game.outcome {
                MatchEnd(outcome: outcome, again: { session?.restart() })
            } else {
                // FR-VIEW-050: a stick on the left steers and a button on the right
                // eats, each in a corner of its own so that one cannot be taken for
                // the other.
                Controls(steer: { session?.apply(.move(direction: $0)) },
                         release: { session?.apply(TouchScheme.release) },
                         eat: { session?.apply(TouchScheme.eat) },
                         canEat: session?.canEat ?? false)
            }
        }
    }
}
