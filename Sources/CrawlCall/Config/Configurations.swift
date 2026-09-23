// The configuration files the game reads at start, one per interface requirement
// (ADR-0012). Keys are the noun phrases those requirements use, in lower camel case;
// a file with an unknown key is rejected at load rather than silently defaulted,
// which is what `Schema` is for.
//
// implements: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010
import Foundation

// MARK: - Snake (IF-SNAKE-010)

struct SnakeConfiguration: Decodable, Equatable {
    struct Abilities: Decodable, Equatable {
        struct Assault: Decodable, Equatable { let dashSpeed: Double; let dashDuration: Double }
        struct Scout: Decodable, Equatable { let duration: Double }
        struct Sniper: Decodable, Equatable { let timeFactor: Double; let duration: Double }
        struct Heavy: Decodable, Equatable {
            let armourFactor: Double
            let armourDuration: Double
            let destructionFactor: Double
        }
        let assault: Assault
        let scout: Scout
        let sniper: Sniper
        let heavy: Heavy
    }

    let baseSpeed: Double
    let startingSegmentCount: Int
    let segmentsPerArchetype: [String: Int]
    let medicRegrownSegments: Int
    let damagePerSegment: Double
    let bodyEatingDuration: Double
    /// How fast the snake chews through a living bot: its health, taken out at this
    /// rate, is what a live meal lasts (FR-SNAKE-100).
    let eatingDamagePerSecond: Double
    let abilities: Abilities

    // The sapper ability takes no parameter — FR-SNAKE-140 sets a partition to its
    // debris state and names no number — so it has no entry here.
    static let schema = Schema.object([
        "baseSpeed": .value,
        "startingSegmentCount": .value,
        "segmentsPerArchetype": .named(of: .value),
        "medicRegrownSegments": .value,
        "damagePerSegment": .value,
        "bodyEatingDuration": .value,
        "eatingDamagePerSecond": .value,
        "abilities": .object([
            "assault": .object(["dashSpeed": .value, "dashDuration": .value]),
            "scout": .object(["duration": .value]),
            "sniper": .object(["timeFactor": .value, "duration": .value]),
            "heavy": .object(["armourFactor": .value, "armourDuration": .value, "destructionFactor": .value]),
        ]),
    ])
}

// MARK: - Tuning (IF-MAP-020)

struct TuningConfiguration: Decodable, Equatable {
    /// The accumulated damage at which a module enters each state after `intact`;
    /// FR-MAP-030 moves it one state at a time, intact → damaged → debris.
    struct ModuleThresholds: Decodable, Equatable { let damagedAt: Double; let debrisAt: Double }
    struct Weapon: Decodable, Equatable { let destructionDamage: Double; let destructionAmmunition: Int }

    let moduleDamageThresholds: [String: ModuleThresholds]
    let weapons: [String: Weapon]
    let snakeBodyDestructionDamagePerSegment: Double
    let trapWidth: Double
    let trapLength: Double
    let tailGapTolerance: Double
    let maximumDropHeight: Double
    let navigationGraphCellSize: Double
    let stepHeight: Double
    let slopeAngle: Double
    let bodyRadius: Double

    static let schema = Schema.object([
        "moduleDamageThresholds": .named(of: .object(["damagedAt": .value, "debrisAt": .value])),
        "weapons": .named(of: .object(["destructionDamage": .value, "destructionAmmunition": .value])),
        "snakeBodyDestructionDamagePerSegment": .value,
        "trapWidth": .value,
        "trapLength": .value,
        "tailGapTolerance": .value,
        "maximumDropHeight": .value,
        "navigationGraphCellSize": .value,
        "stepHeight": .value,
        "slopeAngle": .value,
        "bodyRadius": .value,
    ])
}

// MARK: - View (IF-VIEW-020)

struct ViewConfiguration: Decodable, Equatable {
    struct CentralRegion: Decodable, Equatable { let width: Double; let height: Double }

    let cameraPitch: Double
    let centralRegion: CentralRegion
    /// Metres beyond the body itself at which a module stops hiding the snake and
    /// starts being drawn through (FR-VIEW-150).
    let seeThroughMargin: Double
    /// Metres around the head whose own floor the player is kept able to see: a
    /// module hiding any of it is drawn through, whether or not it hides the snake
    /// itself (FR-VIEW-155).
    let visibilityRadius: Double
    let stragglerDistance: Double
    let visiblePanicThreshold: Double

    static let schema = Schema.object([
        "cameraPitch": .value,
        "centralRegion": .object(["width": .value, "height": .value]),
        "seeThroughMargin": .value,
        "visibilityRadius": .value,
        "stragglerDistance": .value,
        "visiblePanicThreshold": .value,
    ])
}

// MARK: - Bot (IF-BOT-010)

struct BotConfiguration: Decodable, Equatable {
    struct Weights: Decodable, Equatable {
        let panic: Double; let discipline: Double; let aggression: Double; let selfSacrifice: Double
    }
    struct Range: Decodable, Equatable { let lowest: Double; let highest: Double }
    struct Archetype: Decodable, Equatable {
        let basePersonalityWeights: Weights
        let allowedRanges: [String: Range]
        let runSpeed: Double
        let weaponDamage: Double
        /// What a bot of this kind starts with and what it can spend before it has to
        /// reload — both named as utility inputs by FR-BOT-080.
        let health: Double
        let magazine: Int
        let detectionRange: Double
    }

    let archetypes: [String: Archetype]
    let overrideDistance: Double
    let interruptDistance: Double
    let groupingDistance: Double
    let hysteresisMargin: Double
    let deliberationPeriod: Double
    let perFrameSlotMaximum: Int
    let collapsePanicIncrement: Double
    /// How much a bot that has not been touched still wants to be somewhere else
    /// when the snake is near (FR-BOT-210). Multiplied by the bot's panic, so this
    /// number is where the line runs between an archetype that holds and one that
    /// bolts.
    let fearWhenUnhurt: Double

    private static let weights = Schema.object([
        "panic": .value, "discipline": .value, "aggression": .value, "selfSacrifice": .value,
    ])

    static let schema = Schema.object([
        "archetypes": .named(of: .object([
            "basePersonalityWeights": weights,
            "allowedRanges": .named(of: .object(["lowest": .value, "highest": .value])),
            "runSpeed": .value,
            "health": .value,
            "magazine": .value,
            "weaponDamage": .value,
            "detectionRange": .value,
        ])),
        "overrideDistance": .value,
        "interruptDistance": .value,
        "groupingDistance": .value,
        "hysteresisMargin": .value,
        "deliberationPeriod": .value,
        "perFrameSlotMaximum": .value,
        "collapsePanicIncrement": .value,
        "fearWhenUnhurt": .value,
    ])
}

// MARK: - Match (IF-BOT-010, second half)

struct MatchConfiguration: Decodable, Equatable {
    let squadSize: Int
    let commanderEligibleArchetypes: [String]
    let commanderInterval: Double
    let truceSwitch: Bool
    let truceBreakThreshold: Double
    let stateTokenBudget: Int
    let maximumResponseTokens: Int
    let thermalDegradationThreshold: String
    let thermalDegradationFactor: Double

    static let schema = Schema.object([
        "squadSize": .value,
        "commanderEligibleArchetypes": .array(of: .value),
        "commanderInterval": .value,
        "truceSwitch": .value,
        "truceBreakThreshold": .value,
        "stateTokenBudget": .value,
        "maximumResponseTokens": .value,
        "thermalDegradationThreshold": .value,
        "thermalDegradationFactor": .value,
    ])
}
