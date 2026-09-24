// The free camera's controls, in debug mode only (FR-TOOL-070, ADR-0023): two fingers
// pinched zoom it, dragged pan it and twisted turn it, three fingers dragged up or down
// tilt it, and a button puts it back on the snake. Never one finger, which is the
// stick's.
//
// Debug mode is the Debug build configuration: in any other build the modifier passes
// the view through untouched, the gestures and the button are not compiled, and the
// camera never leaves the snake.
//
// The gestures are UIKit's recognizers, handed to SwiftUI through
// `UIGestureRecognizerRepresentable` (SwiftUI, iOS 18.0): SwiftUI's own drag cannot be
// told to wait for two fingers.
//
// implements: FR-TOOL-070
import SwiftUI
import UIKit

extension View {
    /// Debug mode's free camera over the arena, or nothing outside debug mode.
    func freeCamera(_ session: GameSession?) -> some View {
        modifier(FreeCameraControls(session: session))
    }
}

struct FreeCameraControls: ViewModifier {
    let session: GameSession?

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .gesture(PinchToZoom { session?.zoomCamera(by: $0) })
            .gesture(TwoFingerPan { session?.panCamera(by: $0, screenHeight: $1) })
            .gesture(TwistToTurn { session?.turnCamera(by: $0) })
            .gesture(ThreeFingerTilt { session?.tiltCamera(by: $0, screenHeight: $1) })
            .overlay(alignment: .topTrailing) {
                if session?.freeCamera != nil {
                    Button { session?.followSnake() } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Camera back on the snake")
                    .padding(28)
                }
            }
        #else
        content
        #endif
    }
}

#if DEBUG
/// Lets the gestures run together, so that one hand can pinch, drag and twist at once.
final class TogetherWithOthers: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

struct PinchToZoom: UIGestureRecognizerRepresentable {
    /// The pinch since the last call, as a factor: above one apart, below together.
    let zoom: (Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> TogetherWithOthers { TogetherWithOthers() }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let pinch = UIPinchGestureRecognizer()
        pinch.delegate = context.coordinator
        return pinch
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        guard recognizer.state == .changed else { return }
        zoom(Double(recognizer.scale))
        recognizer.scale = 1
    }
}

struct TwoFingerPan: UIGestureRecognizerRepresentable {
    /// The drag since the last call, in points, and how tall the view it was made on is.
    let pan: (SIMD2<Double>, Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> TogetherWithOthers { TogetherWithOthers() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let drag = UIPanGestureRecognizer()
        drag.minimumNumberOfTouches = 2
        drag.maximumNumberOfTouches = 2
        drag.delegate = context.coordinator
        return drag
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .changed, let view = recognizer.view else { return }
        let moved = recognizer.translation(in: view)
        pan(SIMD2(Double(moved.x), Double(moved.y)), Double(view.bounds.height))
        recognizer.setTranslation(.zero, in: view)
    }
}

struct TwistToTurn: UIGestureRecognizerRepresentable {
    /// The twist since the last call, in radians, clockwise on the screen positive.
    let turn: (Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> TogetherWithOthers { TogetherWithOthers() }

    func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        let twist = UIRotationGestureRecognizer()
        twist.delegate = context.coordinator
        return twist
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        guard recognizer.state == .changed else { return }
        turn(Double(recognizer.rotation))
        recognizer.rotation = 0
    }
}

struct ThreeFingerTilt: UIGestureRecognizerRepresentable {
    /// The drag up or down since the last call, in points, down positive, and how tall
    /// the view it was made on is.
    let tilt: (Double, Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> TogetherWithOthers { TogetherWithOthers() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let drag = UIPanGestureRecognizer()
        drag.minimumNumberOfTouches = 3
        drag.maximumNumberOfTouches = 3
        drag.delegate = context.coordinator
        return drag
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .changed, let view = recognizer.view else { return }
        let moved = recognizer.translation(in: view)
        tilt(Double(moved.y), Double(view.bounds.height))
        recognizer.setTranslation(.zero, in: view)
    }
}
#endif
