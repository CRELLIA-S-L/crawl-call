// The see-through's switches, in debug mode only (FR-TOOL-260, FR-TOOL-270): tint what
// is cut open by what cut it — the line of sight to the snake, the window around the
// head, or both — and turn either cut off, to see which of them opens what (Q-260).
//
// Debug mode is the Debug build configuration (ADR-0023): in any other build the
// modifier passes the view through untouched and the switches are not compiled.
//
// implements: FR-TOOL-260, FR-TOOL-270
import SwiftUI

extension View {
    /// Debug mode's see-through switches over the arena, or nothing outside debug mode.
    func seeThroughSwitches(_ session: GameSession?) -> some View {
        modifier(SeeThroughSwitchControls(session: session))
    }
}

struct SeeThroughSwitchControls: ViewModifier {
    let session: GameSession?

    func body(content: Content) -> some View {
        #if DEBUG
        content.overlay(alignment: .topLeading) {
            if let session {
                VStack(alignment: .leading, spacing: SeeThroughTint.switchSpacing) {
                    toggle(DebugText.seeThroughTint, colour: .white, on: session.seeThroughSwitches.tint) {
                        session.seeThroughSwitches.tint.toggle()
                    }
                    toggle(DebugText.seeThroughLine, colour: Self.colour(SeeThroughTint.line),
                           on: session.seeThroughSwitches.line) { session.seeThroughSwitches.line.toggle() }
                    toggle(DebugText.seeThroughWindow, colour: Self.colour(SeeThroughTint.window),
                           on: session.seeThroughSwitches.window) { session.seeThroughSwitches.window.toggle() }
                }
                .padding(Interface.screenMargin)
            }
        }
        #else
        content
        #endif
    }

    #if DEBUG
    private func toggle(_ title: String, colour: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(colour.opacity(on ? DebugControls.markOpacity : SeeThroughTint.switchOffOpacity))
                .padding(SeeThroughTint.switchPadding)
                .background(Capsule().fill(Color.black.opacity(DebugControls.plateOpacity)))
        }
    }

    private static func colour(_ rgb: SIMD3<Double>) -> Color {
        Color(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
    #endif
}
