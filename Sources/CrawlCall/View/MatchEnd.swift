// What the player sees when the match is over: one plate saying which of the ends it
// was, and one control that starts another (FR-VIEW-190).
//
// It stands where the stick and the eat button stood, and they are gone while it is
// up: a control that still answered after the snake was dead would say the match was
// not over.
//
// Drawn as the rest of the interface is (FR-VIEW-120): a rounded, light, translucent
// plate and a bold rounded typeface. Words rather than an icon here, because which
// end it was is the one thing no icon in this style says unambiguously.
//
// file implements: FR-VIEW-190, FR-VIEW-120, FR-VIEW-200
import SwiftUI

struct MatchEnd: View {
    let outcome: Game.Outcome
    /// What the one control asks for: another match in the same arena.
    let again: () -> Void

    /// The line on the plate. One per end, and they say different things: the snake
    /// was shot down, the snake ate everything there was, or a squad carried the
    /// treasure off (FR-SCORE-160). The words are in the string catalog, in the
    /// player's language (FR-VIEW-200).
    static func headline(for outcome: Game.Outcome) -> TextKey {
        switch outcome {
        case .snakeDied: return .matchEndSnakeDied
        case .arenaEmpty: return .matchEndArenaEmpty
        case .treasureTaken: return .matchEndTreasureTaken
        }
    }

    var body: some View {
        ChoicePlate(headline: MatchEnd.headline(for: outcome), control: .matchEndAgain, action: again)
    }
}
