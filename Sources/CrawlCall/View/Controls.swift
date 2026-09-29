// The controls the player's thumbs land on: the left half of the screen steers and
// the right half eats (FR-VIEW-050). Gestures over the whole screen were tried first
// and collided — a thumb that pauses before it drags asks for a meal instead of a
// step — so each thumb has a half of its own and cannot be mistaken for the other.
// Within its half a thumb need not find anything: the stick appears where it lands
// and is gone when it lifts, and a touch anywhere on the right is a meal (ADR-0051).
//
// Drawn as the rest of the interface will be: rounded, light, an icon rather than a
// word (FR-VIEW-120). What it is *not* is as much the requirement as what it is —
// nothing slanted, bevelled or military.
//
// A control that does nothing looks broken, so the eat button still says whether a
// touch would do anything (FR-VIEW-160): lit when somebody is within the snake's lunge,
// dim when nobody is (FR-SNAKE-270). It is where the right thumb rests, and only a
// sign: the whole half is what answers.
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
    /// Where the stick stands while a thumb is on it; nil while none is, and it is not
    /// drawn.
    @State private var centre: CGPoint?
    /// Whether a thumb is down on the right half: one touch is one meal asked for.
    @State private var eating = false

    private let plate = Color.white.opacity(Interface.plateOpacity)
    private let mark = Color.white.opacity(Interface.markOpacity)

    var body: some View {
        HStack(spacing: .zero) {
            GeometryReader { half in
                stickSide(half.size)
            }
            eatSide
        }
    }

    /// The left half: the stick stands where the thumb lands, and the thumb's travel
    /// from there is the direction, held while it stays down wherever it slides.
    private func stickSide(_ size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            // Hidden while no thumb is on it, as Apple advises for a thumbstick
            // (ADR-0051).
            .overlay(alignment: .topLeading) {
                if let centre { stick.position(centre) }
            }
            .gesture(
                DragGesture(minimumDistance: .zero)
                    .onChanged { value in
                        if centre == nil { centre = TouchScheme.stickCentre(at: value.startLocation, in: size) }
                        let reading = TouchScheme.stick(value.translation)
                        knob = reading.knob
                        steer(reading.direction)
                    }
                    .onEnded { _ in
                        centre = nil
                        knob = .zero
                        release()
                    }
            )
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
        .allowsHitTesting(false)
    }

    /// The right half: a touch anywhere on it asks for a meal as it lands, once.
    private var eatSide: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(alignment: .bottomTrailing) {
                button
                    .padding(.trailing, Interface.screenMargin)
                    .padding(.bottom, Interface.screenMargin)
            }
            .gesture(
                DragGesture(minimumDistance: .zero)
                    .onChanged { _ in
                        guard !eating else { return }
                        eating = true
                        eat()
                    }
                    .onEnded { _ in eating = false }
            )
    }

    private var button: some View {
        Image(systemName: SymbolName.eat)
            .font(.system(size: EatButton.symbolSize, weight: .bold, design: .rounded))
            .foregroundStyle(canEat ? mark : mark.opacity(Interface.dimMarkOpacity))
            .frame(width: EatButton.size, height: EatButton.size)
            .background(Circle().fill(canEat ? plate.opacity(Interface.litPlateOpacity)
                                             : plate.opacity(Interface.dimPlateOpacity)))
            // Lit means reachable, and the ring is what makes it read as a
            // button that is on rather than one that is merely brighter.
            .overlay(Circle().strokeBorder(mark, lineWidth: canEat ? Interface.ringWidth : .zero))
            .animation(.easeOut(duration: Interface.changeDuration), value: canEat)
            .allowsHitTesting(false)
            // For VoiceOver it is still the button it looks like.
            .accessibilityElement()
            .accessibilityLabel(Text(TextKey.controlsEat.key))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if canEat { eat() } }
    }
}
