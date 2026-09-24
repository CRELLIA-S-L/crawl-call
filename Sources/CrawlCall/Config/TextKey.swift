// The keys of the text the player reads (IF-VIEW-030). Each names where its text
// appears — `matchEnd.snakeDied` — and the words themselves are in the string catalog,
// `Localizable.xcstrings`, one entry per key and language (ADR-0024). The key is the
// name ART-070 asks every string in code to have; the catalog is where the text is.
//
// Text shown only in the debug build is not here: the player never reads it, so it is
// a named constant in `DebugText` and is not translated.
//
// implements: IF-VIEW-030, FR-VIEW-200
import SwiftUI

enum TextKey: String, CaseIterable {
    case matchEndSnakeDied = "matchEnd.snakeDied"
    case matchEndArenaEmpty = "matchEnd.arenaEmpty"
    case matchEndAgain = "matchEnd.again"
    case controlsEat = "controls.eat"

    /// For a view: SwiftUI looks the key up in the catalog, in the language the
    /// environment asks for (FR-VIEW-200).
    var key: LocalizedStringKey { LocalizedStringKey(rawValue) }

    /// For code that needs the words themselves, in the language the app runs in.
    func text(in bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: rawValue, value: nil, table: nil)
    }
}
