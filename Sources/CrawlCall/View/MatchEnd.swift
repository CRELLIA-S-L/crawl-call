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
// implements: FR-VIEW-190, FR-VIEW-120, FR-VIEW-200
import SwiftUI

struct MatchEnd: View {
    let outcome: Game.Outcome
    /// What the one control asks for: another match in the same arena.
    let again: () -> Void

    private let plate = Color.white.opacity(Interface.plateOpacity)
    private let mark = Color.white.opacity(Interface.markOpacity)

    /// The line on the plate. One per end, and they say opposite things: the snake
    /// was shot down, or the snake ate everything there was. The words are in the
    /// string catalog, in the player's language (FR-VIEW-200).
    static func headline(for outcome: Game.Outcome) -> TextKey {
        switch outcome {
        case .snakeDied: return .matchEndSnakeDied
        case .arenaEmpty: return .matchEndArenaEmpty
        }
    }

    var body: some View {
        VStack(spacing: MatchEndPlate.spacing) {
            Text(MatchEnd.headline(for: outcome).key)
                .font(.system(size: MatchEndPlate.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(mark)
                .multilineTextAlignment(.center)
            Button(action: again) {
                Text(TextKey.matchEndAgain.key)
                    .font(.system(size: MatchEndPlate.controlTextSize, weight: .bold, design: .rounded))
                    .foregroundStyle(mark)
                    .padding(.horizontal, MatchEndPlate.controlHorizontalPadding)
                    .padding(.vertical, MatchEndPlate.controlVerticalPadding)
                    .background(Capsule().fill(plate.opacity(Interface.litPlateOpacity)))
                    .overlay(Capsule().strokeBorder(mark, lineWidth: Interface.ringWidth))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(TextKey.matchEndAgain.key))
        }
        .padding(.horizontal, MatchEndPlate.horizontalPadding)
        .padding(.vertical, MatchEndPlate.verticalPadding)
        .background(RoundedRectangle(cornerRadius: MatchEndPlate.cornerRadius, style: .continuous).fill(plate))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
