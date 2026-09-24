// The game's entry point. Starting the app is the moment the interface requirements
// name for reading the configurations, and the moment a match begins.
//
// The app is a UIKit scene hosting SwiftUI rather than a SwiftUI `App`: on an iPad the
// window's root controller asks iPadOS to lock the orientation (FR-VIEW-220), keeps
// the window no smaller than the controls (FR-VIEW-210) and hears when the lock comes
// or goes (FR-VIEW-230), and SwiftUI's own `App` offers none of the three (ADR-0027).
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, FR-TOOL-070, FR-VIEW-050, FR-VIEW-060, FR-VIEW-160, FR-VIEW-190, FR-VIEW-210, FR-VIEW-220, FR-VIEW-230, FR-TOOL-230, FR-TOOL-240
import RealityKit
import SwiftUI
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// A scene the system brings back from before the game had a scene delegate of its
    /// own comes back with the delegate it was made with — SwiftUI's, from the build
    /// whose entry point was a SwiftUI `App` — which draws nothing. iOS restores it on
    /// every launch, closing the app from the switcher does not discard it on iOS 27,
    /// and an iPhone may not close it from inside. So such a scene is taken over as it
    /// connects: given the game's delegate, which builds the window (ADR-0027).
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification,
                                               object: nil, queue: nil) { notification in
            guard let scene = notification.object as? UIWindowScene else { return }
            MainActor.assumeIsolated { Self.takeOver(scene) }
        }
        return true
    }

    /// Gives a scene the game's delegate where it has another, and builds its window.
    @MainActor
    static func takeOver(_ scene: UIWindowScene) {
        guard !(scene.delegate is SceneDelegate) else { return }
        let delegate = SceneDelegate()
        scene.delegate = delegate
        delegate.connect(scene)
    }

    /// Every scene is the game's, and its delegate builds the window.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    /// Read once, at start, because that is the moment the interface requirements name.
    /// Not private: a test constructs the delegate to check that starting reads them.
    let world = Launch.world()

    /// Where the window's news reaches the match: a change of the orientation lock
    /// pauses it (FR-VIEW-230). It carries the frame record where the launch switched
    /// it on (FR-TOOL-230).
    @MainActor let host = MatchHost(recorder: FrameRecorder.isSwitchedOn(ProcessInfo.processInfo.environment)
                                        ? FrameRecorder() : nil)
    /// Kept while the record is on, so that a SIGTERM writes it before the app ends
    /// (FR-TOOL-240).
    private var termination: DispatchSourceSignal?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        connect(windowScene)
    }

    /// Builds the window in a scene: the root controller around the match, and the
    /// smallest size the controls fit in.
    func connect(_ windowScene: UIWindowScene) {
        // Nil where the platform does not resize scenes: an iPhone's is the screen.
        windowScene.sizeRestrictions?.minimumSize = GameWindow.minimumSize
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameHostingController(rootView: GameRoot(world: world, host: host))
        self.window = window
        window.makeKeyAndVisible()
        if let recorder = host.recorder, termination == nil {
            termination = TerminationRecord.install(writing: recorder)
        }
    }

    /// FR-TOOL-240: leaving the foreground is one of the moments the record is written,
    /// and written here before returning — the app may be suspended straight after.
    func sceneDidEnterBackground(_ scene: UIScene) {
        try? host.recorder?.writeNow()
    }

    /// The scene's geometry changed: resized, moved to the whole screen or off it, or
    /// turned. Only a change of the orientation lock is news to the match.
    func windowScene(_ windowScene: UIWindowScene,
                     didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        host.orientationLock(was: previousEffectiveGeometry.isInterfaceOrientationLocked,
                             is: windowScene.effectiveGeometry.isInterfaceOrientationLocked)
    }
}

/// What the window shows: the match, or why there is none.
struct GameRoot: View {
    let world: Result<World, Error>
    let host: MatchHost

    var body: some View {
        switch world {
        case .success(let world):
            MatchView(world: world, host: host)
        case .failure(let error):
            // A launch that cannot read its tuning or its map says so instead of
            // running on numbers nobody chose.
            Text(String(describing: error))
                .font(.system(.body, design: .monospaced))
                .padding()
        }
    }
}

/// A match on screen: the arena, the snake in it, and a finger steering.
struct MatchView: View {
    let world: World
    let host: MatchHost
    @State private var session: GameSession?
    /// The frame's width over its height, kept here because the session is made after
    /// the view is first laid out (FR-VIEW-210).
    @State private var aspect = Fraction.whole

    var body: some View {
        RealityView { content in
            let (scene, seeThrough) = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
            content.add(scene)

            guard let start = Game.start(in: world),
                  let camera = scene.children.first(where: { $0.name == EntityName.camera }),
                  let map = scene.children.first(where: { $0.name == EntityName.map }),
                  let ambient = scene.children.first(where: { $0.name == EntityName.ambient }) else { return }

            let game = Game(world: world, start: start)
            let snake = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                         segments: game.snake.segments)
            for part in snake.children {
                part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
            map.addChild(snake)

            let squads = BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight)
            BotEntity.light(squads, by: ambient)
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
                                      distance: SceneView.distance(framing: world.plan,
                                                                   view: world.configurations.view),
                                      fieldOfView: world.configurations.view.cameraFieldOfView)
            session.aspect = aspect
            session.recorder = host.recorder
            self.session = session
            host.session = session
            // One step per frame, from the frame's own delta.
            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                session.step(seconds: event.deltaTime)
            }
        }
        .ignoresSafeArea()
        .onGeometryChange(for: Double.self) { geometry in
            geometry.size.height > .zero ? geometry.size.width / geometry.size.height : Fraction.whole
        } action: { newAspect in
            aspect = newAspect
            session?.aspect = newAspect
        }
        // Debug mode's free camera (FR-TOOL-070): pinch and two-finger drag on the
        // arena, and a button back to the snake; nothing at all in a Release build.
        .freeCamera(session)
        // One or the other, never both (FR-VIEW-190): while the match is on, the
        // controls; once it is over, the plate that says how it ended and starts
        // another.
        .overlay {
            if let outcome = session?.game.outcome {
                MatchEnd(outcome: outcome, again: { session?.restart() })
            } else if session?.isPaused == true {
                // FR-VIEW-230: a paused match says so, and one press resumes it.
                ChoicePlate(headline: .pauseHeadline, control: .pauseResume, action: { session?.resume() })
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
