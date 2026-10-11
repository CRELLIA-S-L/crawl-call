// The text the player reads comes from the string catalog, complete in every language
// the game carries (IF-VIEW-030), and the player reads it in the first of their
// languages the game carries, or in English (FR-VIEW-200).
//
// The language choice itself is the system's: a bundle's text is shown in the first
// of `Bundle.preferredLocalizations(from:forPreferences:)`, given the languages the
// bundle carries. What the game controls is which languages it carries and which one
// it was developed in — so that is what these tests hold, through the same call.
//
// file verifies: IF-VIEW-030, FR-VIEW-200
import XCTest
@testable import CrawlCall

final class TextCatalogTests: XCTestCase {
    /// What `localizedString(forKey:value:table:)` returns when the key is not in the
    /// table (NSBundle.h): a fresh identifier, which no text in the catalog can be, and
    /// printable, so that a failure's log stays text.
    private let absent = UUID().uuidString

    private var carried: [String] { Bundle.main.localizations.filter { $0 != "Base" } }

    private func bundle(for language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"),
                                 "no \(language).lproj in the app")
        return try XCTUnwrap(Bundle(path: path))
    }

    func testTheGameCarriesEnglishAndWasDevelopedInIt() {
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
        XCTAssertTrue(carried.contains("en"), "carried: \(carried)")
    }

    func testEveryKeyHasTextInEveryLanguageTheGameCarries() throws {
        for language in carried {
            let table = try bundle(for: language)
            for key in TextKey.allCases {
                let text = table.localizedString(forKey: key.rawValue, value: absent, table: nil)
                XCTAssertNotEqual(text, absent, "\(key.rawValue) has no \(language) text")
                XCTAssertFalse(text.isEmpty, "\(key.rawValue) is empty in \(language)")
                XCTAssertNotEqual(text, key.rawValue, "\(key.rawValue) shows its key in \(language)")
            }
        }
    }

    func testTheCatalogHoldsNoTextThatNoKeyShows() throws {
        // A key in the catalog that the code does not name is text nobody will see and
        // somebody will translate.
        let table = try bundle(for: "en")
        let path = try XCTUnwrap(table.path(forResource: "Localizable", ofType: "strings"))
        let entries = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        XCTAssertEqual(Set(entries.keys), Set(TextKey.allCases.map(\.rawValue)))
    }

    func testTheWordsAreTheOnesTheCatalogHolds() {
        // The code reads the catalog and not a copy of it: the English on the plate is
        // what the catalog says.
        XCTAssertEqual(TextKey.matchEndSnakeDied.text(), "Shot to pieces")
        XCTAssertEqual(TextKey.matchEndAgain.text(), "Again")
    }

    func testAPlayerWhoseLanguagesTheGameDoesNotCarryReadsEnglish() {
        let chosen = Bundle.preferredLocalizations(from: Bundle.main.localizations,
                                                   forPreferences: ["ja-JP", "de-DE"])
        XCTAssertEqual(chosen.first, "en")
    }

    func testAPlayerWhoReadsEnglishReadsEnglishWhateverElseTheyRead() {
        let chosen = Bundle.preferredLocalizations(from: Bundle.main.localizations,
                                                   forPreferences: ["fr-FR", "en-GB"])
        XCTAssertEqual(chosen.first, "en")
    }
}
