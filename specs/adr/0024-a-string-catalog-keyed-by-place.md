# ADR-0024 — The player's text is in a String Catalog, keyed by where it appears

- **Status:** accepted
- **Date:** 2026-09-24
- **Related requirements:** FR-VIEW-200, IF-VIEW-030

## Context and problem statement

On 2026-09-24 the maintainer asked for the interface's text to be built for translation from the start, carrying English alone for now, and ART-070 moved text a player reads out of code.
The game had four such texts, all in SwiftUI views: the two headlines and the control at the end of a match, and the eat button's accessibility label.
The configuration files of ADR-0012 are one JSON file per interface, read by the game's own schema; none of them was made for text in several languages.

## Considered options

1. A String Catalog, `Localizable.xcstrings`, compiled by Xcode into one table per language, with keys that name where a text appears.
2. The same catalog keyed by the English text itself, which is what Xcode's automatic extraction produces from string literals in views.
3. A JSON file of our own under `config/`, one object per language, read through the schema of ADR-0012.

## Decision outcome

Option 1.
The catalog is the format Xcode 27 compiles and SwiftUI reads without any code of ours: `Text` given a `LocalizedStringKey` looks the key up in the main bundle's `Localizable` table in the language the environment asks for, and the system picks that language from the player's preferred ones and the languages the bundle carries — which is exactly the rule FR-VIEW-200 states.
Option 2 was rejected because its keys are the English words: editing the English orphans every translation of it, and the key would be a string literal in code, which ART-070 forbids.
Option 3 was rejected because it would rebuild what the system already does — the choice of language, plural rules, the fallback — in code of our own that tests would then have to prove.

### How it works

`TextKey` in `Config/TextKey.swift` has one case per text, its raw value the key, written `<place>.<meaning>` — `matchEnd.snakeDied`.
A view shows `Text(key.key)`, which hands SwiftUI a `LocalizedStringKey`; code that needs the words asks `key.text()`, which is `Bundle.localizedString(forKey:value:table:)`.
The catalog lives at `Sources/CrawlCall/View/Localizable.xcstrings`; its entries are written by hand, marked `"extractionState" : "manual"`, because a key held in a constant is not a literal Xcode can extract.
The build compiles it to `en.lproj/Localizable.strings` in the app, and the project's development region is `en`.
Invariants, held by `TextCatalogTests`: every `TextKey` has non-empty text, other than the key, in every language the app carries; the English table holds no key that `TextKey` lacks; the development language is English, and `Bundle.preferredLocalizations(from:forPreferences:)` answers English for a player whose languages the game does not carry.
It stops working where a view hands `Text` a plain `String` instead of the key — SwiftUI then shows the string verbatim, untranslated — and nothing but reading the view catches that.

### Consequences

A language is added by adding its translations to the catalog; the tests fail until every key has one.
What the fighters say is outside this catalog (Q-290).
Text shown only in the debug build is a named constant in `DebugText` and is not translated.
