// What the player sees when the match is over: one plate saying which of the two ends
// it was, and one control that starts another (FR-VIEW-190).
//
// It stands where the stick and the eat button stood, and they are gone while it is
// up: a control that still answered after the snake was dead would say the match was
// not over.
//
// Drawn as the rest of the interface is (FR-VIEW-120): a rounded, light, translucent
// plate and a bold rounded typeface. Words rather than an icon here, because which
// end it was is the one thing no icon in this style says unambiguously.
//
// implements: FR-VIEW-190, FR-VIEW-120
import SwiftUI

struct MatchEnd: View {
    let outcome: Game.Outcome
    /// What the one control asks for: another match in the same arena.
    let again: () -> Void

    private let plate = Color.white.opacity(0.28)
    private let mark = Color.white.opacity(0.85)

    /// The line on the plate. One per end, and they say opposite things: the snake
    /// was shot down, or the snake ate everything there was.
    static func headline(for outcome: Game.Outcome) -> String {
        switch outcome {
        case .snakeDied: return "Shot to pieces"
        case .arenaEmpty: return "Nothing left to eat"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(MatchEnd.headline(for: outcome))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(mark)
                .multilineTextAlignment(.center)
            Button(action: again) {
                Text("Again")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(mark)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(plate.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(mark, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Again")
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(plate))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
