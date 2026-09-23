// The controls the player's thumbs land on: a stick on the left, a button on the
// right (FR-VIEW-050). Gestures over the whole screen were tried first and collided
// — a thumb that pauses before it drags asks for a meal instead of a step — so each
// control has a corner of its own and cannot be mistaken for the other.
//
// Drawn as the rest of the interface will be: rounded, light, an icon rather than a
// word (FR-VIEW-120). What it is *not* is as much the requirement as what it is —
// nothing slanted, bevelled or military.
//
// A control that does nothing looks broken, so the button says whether it would do
// anything (FR-VIEW-160): lit when the head has reached somebody, dim when it has
// not.
//
// implements: FR-VIEW-050, FR-VIEW-120, FR-VIEW-160
import SwiftUI

struct Controls: View {
    /// Where the steering goes.
    let steer: (SIMD2<Double>) -> Void
    /// What the thumb lifting off asks for: the snake stops (`TouchScheme.release`).
    let release: () -> Void
    /// What the button asks for.
    let eat: () -> Void
    /// Whether pressing it would begin a meal (FR-VIEW-160).
    let canEat: Bool

    @State private var knob: CGSize = .zero

    private let plate = Color.white.opacity(0.28)
    private let mark = Color.white.opacity(0.85)

    var body: some View {
        HStack {
            stick
            Spacer()
            button
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity, alignment: .bottom)
        // The controls sit over the arena; the arena is what is being steered, so
        // nothing here takes a touch that is not on a control.
        .allowsHitTesting(true)
    }

    private var stick: some View {
        let radius = TouchScheme.stickRadius
        return ZStack {
            Circle()
                .fill(plate)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(mark)
                .frame(width: radius * 0.8, height: radius * 0.8)
                .offset(knob)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let reading = TouchScheme.stick(value.translation)
                    knob = reading.knob
                    steer(reading.direction)
                }
                .onEnded { _ in
                    knob = .zero
                    release()
                }
        )
    }

    private var button: some View {
        Button(action: eat) {
            Image(systemName: "fork.knife")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(canEat ? mark : mark.opacity(0.35))
                .frame(width: 96, height: 96)
                .background(Circle().fill(canEat ? plate.opacity(0.9) : plate.opacity(0.4)))
                // Lit means reachable, and the ring is what makes it read as a
                // button that is on rather than one that is merely brighter.
                .overlay(Circle().strokeBorder(mark, lineWidth: canEat ? 3 : 0))
        }
        .buttonStyle(.plain)
        .disabled(!canEat)
        .animation(.easeOut(duration: 0.12), value: canEat)
        .accessibilityLabel("Eat")
    }
}
