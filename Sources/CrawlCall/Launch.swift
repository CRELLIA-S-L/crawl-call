// What happens when the game starts: the configurations are read, once, before
// anything else. Four interface requirements are written as "when the game starts,
// the system shall read…", so this is the moment they name.
//
// A configuration that cannot be read stops the launch visibly rather than leaving
// the game running on numbers nobody chose. What the game should *show* in that case
// is not something the specification settles yet; what it must not do — carry on with
// defaults — it does settle, by ADR-0012's rule that a typo is an error.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010
import Foundation

enum Launch {
    /// Reads every configuration the game needs, in the order a reader would expect
    /// to hear about a failure: the first file that is wrong is the one reported.
    static func load(from bundle: Bundle = .main) -> Result<Configurations, ConfigurationError> {
        do {
            return .success(try Configurations.load(from: bundle))
        } catch let error as ConfigurationError {
            return .failure(error)
        } catch {
            // Configurations.load throws nothing else; this keeps that a fact rather
            // than an assumption, and says so if it ever stops being true.
            return .failure(.undecodable(name: "unknown", underlying: error))
        }
    }
}
