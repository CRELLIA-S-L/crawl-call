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
// implements: FR-VIEW-050, FR-VIEW-120, FR-VIEW-160, FR-VIEW-200
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

    private let plate = Color.white.opacity(Interface.plateOpacity)
    private let mark = Color.white.opacity(Interface.markOpacity)

    var body: some View {
        HStack {
            stick
            Spacer()
            button
        }
        .padding(.horizontal, Interface.screenMargin)
        .padding(.bottom, Interface.screenMargin)
        .frame(maxHeight: .infinity, alignment: .bottom)
        // The controls sit over the arena; the arena is what is being steered, so
        // nothing here takes a touch that is not on a control.
        .allowsHitTesting(true)
    }

    private var stick: some View {
        let radius = Stick.radius
        return ZStack {
            Circle()
                .fill(plate)
                .frame(width: radius * Stick.plateInRadii, height: radius * Stick.plateInRadii)
            Circle()
                .fill(mark)
                .frame(width: radius * Stick.knobInRadii, height: radius * Stick.knobInRadii)
                .offset(knob)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: .zero)
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
            Image(systemName: SymbolName.eat)
                .font(.system(size: EatButton.symbolSize, weight: .bold, design: .rounded))
                .foregroundStyle(canEat ? mark : mark.opacity(Interface.dimMarkOpacity))
                .frame(width: EatButton.size, height: EatButton.size)
                .background(Circle().fill(canEat ? plate.opacity(Interface.litPlateOpacity)
                                                 : plate.opacity(Interface.dimPlateOpacity)))
                // Lit means reachable, and the ring is what makes it read as a
                // button that is on rather than one that is merely brighter.
                .overlay(Circle().strokeBorder(mark, lineWidth: canEat ? Interface.ringWidth : .zero))
        }
        .buttonStyle(.plain)
        .disabled(!canEat)
        .animation(.easeOut(duration: Interface.changeDuration), value: canEat)
        .accessibilityLabel(Text(TextKey.controlsEat.key))
    }
}
