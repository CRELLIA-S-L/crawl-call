// The configuration files the game reads at start, one per interface requirement
// (ADR-0012). Keys are the noun phrases those requirements use, in lower camel case;
// a file with an unknown key is rejected at load rather than silently defaulted,
// which is what `Schema` is for.
//
// file implements: FR-BOT-440, FR-BOT-450, IF-CMD-040, IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, IF-SCORE-010, FR-SNAKE-220, FR-BOT-280, FR-BOT-050, FR-BOT-290, FR-BOT-260, FR-BOT-310, FR-SNAKE-270, FR-SNAKE-280, FR-SNAKE-290, FR-VIEW-330, FR-BOT-405, FR-BOT-430, FR-SNAKE-055, FR-SNAKE-016
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
    /// The snake's lunge at what it would eat (FR-SNAKE-270): how far from the head a
    /// bot may be, in metres; how long the head is held back first, in seconds; and how
    /// fast it then goes, in metres a second.
    struct Lunge: Decodable, Equatable {
        let reach: Double; let windUp: Double; let speed: Double
        /// Degrees to either side of the way the head is going within which a bot can
        /// be lunged at, and must stay for the lunge to go on (FR-SNAKE-270).
        let angle: Double
    }
    let lunge: Lunge
    /// The coil round a living bot the lunge has reached (FR-SNAKE-280): how long the
    /// head takes to go once round it, in seconds; how far from where it stands the bot
    /// may be shoved to make room for the coil, in metres; and how fast, in metres a
    /// second.
    struct Coil: Decodable, Equatable { let seconds: Double; let shoveReach: Double; let shoveSpeed: Double }
    let coil: Coil
    /// The tightest arc, in metres at the body's centre line, the head turns on while
    /// the player steers it (FR-SNAKE-290).
    let turningRadius: Double
    /// How many segments behind the head are its neck, which the head does not climb as
    /// it turns; past them, it crawls over its own body (FR-SNAKE-055).
    let neckSegments: Int
    /// Metres ahead of the head within which it feels what it cannot pass, and starts to
    /// go round it the way the stick leads past it (FR-SNAKE-016).
    let feelDistance: Double
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
        "lunge": .object(["reach": .value, "windUp": .value, "speed": .value, "angle": .value]),
        "coil": .object(["seconds": .value, "shoveReach": .value, "shoveSpeed": .value]),
        "turningRadius": .value,
        "neckSegments": .value,
        "feelDistance": .value,
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
    /// Metres a second squared the snake's head falls under off a ledge, going on
    /// across at the speed it walked off at, so that a drop is an arc (FR-SNAKE-220).
    let dropGravity: Double
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
        "dropGravity": .value,
        "navigationGraphCellSize": .value,
        "stepHeight": .value,
        "slopeAngle": .value,
        "bodyRadius": .value,
    ])
}

// MARK: - View (IF-VIEW-020)

struct ViewConfiguration: Decodable, Equatable {
    struct CentralRegion: Decodable, Equatable { let width: Double; let height: Double }
    /// How the drawn body sways as the snake crawls (FR-VIEW-330): metres to either
    /// side of its path, and metres of ground to one wave.
    struct Slither: Decodable, Equatable { let amplitude: Double; let wavelength: Double }

    let cameraPitch: Double
    /// The camera's vertical field of view, in degrees (FR-VIEW-010).
    let cameraFieldOfView: Double
    /// How far the camera stands from what it looks at, in lengths of the map's
    /// larger side: far enough back that the whole map fits before there is a snake
    /// to follow (FR-VIEW-020).
    let cameraDistanceInMapWidths: Double
    /// The light the scene is read by (FR-VIEW-130): the ambient light's colour, red,
    /// green and blue in 0…1, and its brightness as a power of two; the sun's
    /// intensity in lux, how far below the horizontal it shines from and how far
    /// round from straight ahead, in degrees.
    struct Colour: Decodable, Equatable { let red: Double; let green: Double; let blue: Double }
    let ambientColour: Colour
    let ambientIntensityExponent: Double
    let sunIntensity: Double
    let sunElevation: Double
    let sunAzimuth: Double
    let centralRegion: CentralRegion
    /// Seconds the camera takes to catch up with the head, as the time of a critically
    /// damped spring, so that a quick movement of the head is not a jolt of the frame
    /// (FR-VIEW-020).
    let cameraFollowLag: Double
    let slither: Slither
    /// Metres beyond the body itself at which a module stops hiding the snake and
    /// starts being drawn through (FR-VIEW-150).
    let seeThroughMargin: Double
    /// Metres around the head whose own floor the player is kept able to see: a
    /// module hiding any of it is drawn through, whether or not it hides the snake
    /// itself (FR-VIEW-155).
    let visibilityRadius: Double
    let stragglerDistance: Double
    let visiblePanicThreshold: Double
    /// How close to and how far from what it looks at the free camera of debug mode
    /// may be taken, in metres (FR-TOOL-070, ADR-0023).
    let freeCameraNearest: Double
    let freeCameraFarthest: Double
    /// How low towards the horizon and how steeply down the free camera may be
    /// tilted, in degrees below the horizontal (FR-TOOL-070, ADR-0023).
    let freeCameraLowestPitch: Double
    let freeCameraHighestPitch: Double

    static let schema = Schema.object([
        "cameraPitch": .value,
        "cameraFieldOfView": .value,
        "cameraDistanceInMapWidths": .value,
        "ambientColour": .object(["red": .value, "green": .value, "blue": .value]),
        "ambientIntensityExponent": .value,
        "sunIntensity": .value,
        "sunElevation": .value,
        "sunAzimuth": .value,
        "centralRegion": .object(["width": .value, "height": .value]),
        "cameraFollowLag": .value,
        "slither": .object(["amplitude": .value, "wavelength": .value]),
        "seeThroughMargin": .value,
        "visibilityRadius": .value,
        "stragglerDistance": .value,
        "visiblePanicThreshold": .value,
        "freeCameraNearest": .value,
        "freeCameraFarthest": .value,
        "freeCameraLowestPitch": .value,
        "freeCameraHighestPitch": .value,
    ])
}

// MARK: - Commander (IF-CMD-040)

/// What the model is told before it is asked anything (IF-CMD-040).
///
/// The instructions live in a file rather than in the code because a change to them is
/// a change to one of the four things a prompt measurement covers, and the bench has
/// to be run against the new text before it ships (FR-TOOL-170). A text that needs a
/// rebuild to try is a text nobody measures.
struct CommanderConfiguration: Decodable, Equatable {
    let instructions: String

    static let schema = Schema.object([
        "instructions": .value,
    ])
}

// MARK: - Bot (IF-BOT-010)

struct BotConfiguration: Decodable, Equatable {
    /// The five weights FR-BOT-090 names. Courage is not the other side of panic:
    /// panic pulls on the fear that sends a bot away, courage on the terms that keep
    /// it facing the danger, and a bot may carry both high.
    struct Weights: Decodable, Equatable {
        let panic: Double; let discipline: Double; let aggression: Double; let selfSacrifice: Double
        let courage: Double
    }
    struct Range: Decodable, Equatable { let lowest: Double; let highest: Double }
    struct Archetype: Decodable, Equatable {
        let basePersonalityWeights: Weights
        let allowedRanges: [String: Range]
        let runSpeed: Double
        /// What a bot of this kind starts with — named as a utility input by
        /// FR-BOT-080. What it fights with is `arms`, and the numbers behind each
        /// weapon are the catalogue's (FR-BOT-450).
        let health: Double
        let detectionRange: Double
        /// Which weapons out of the catalogue a bot of this kind is given when it is
        /// spawned, and how many grenades (FR-BOT-440).
        let arms: Arms
    }

    /// What an archetype carries, by the names the catalogue below knows it by: a
    /// weapon absent from the catalogue is a configuration error at spawn and not a
    /// bot that goes out unarmed (FR-BOT-440).
    struct Arms: Decodable, Equatable {
        let primary: String
        let sidearm: String
        let grenade: String
        let grenadesCarried: Int
        let knife: String
    }

    /// Every weapon the configuration describes, by kind (IF-BOT-010). An archetype
    /// names what it takes from here, so that two archetypes may carry different
    /// sidearms without a word changing in the specification (ADR-0075).
    struct Weapons: Decodable, Equatable {
        let firearms: [String: Firearm]
        let grenades: [String: Grenade]
        let knives: [String: Knife]
    }

    /// What one shot of a firearm is (FR-BOT-450): what it deals to what it strikes,
    /// how far it reaches, how long before it may be fired again, and how many rounds
    /// it holds between reloads — with how long filling it again takes (FR-BOT-550)
    /// and how many spare magazines a bot carries for it (FR-BOT-560).
    struct Firearm: Decodable, Equatable {
        let damage: Double
        let range: Double
        let timeBetweenShots: Double
        let magazine: Int
        let reloadTime: Double
        let spareMagazines: Int
    }

    /// What a grenade is (FR-BOT-470, FR-BOT-480, FR-BOT-490): what the blast deals,
    /// how far it may be thrown, how long it waits before it goes off, how wide the
    /// blast is, and how much every part of the snake beyond the first within it adds.
    struct Grenade: Decodable, Equatable {
        let damage: Double
        let throwRange: Double
        let fuseTime: Double
        let blastRadius: Double
        let furtherPartShare: Double
    }

    /// What a knife is (FR-BOT-510, FR-BOT-520): what it deals, how far an arm with
    /// one in it reaches, how long between one strike and the next, and how far it
    /// goes thrown.
    struct Knife: Decodable, Equatable {
        let damage: Double
        let reach: Double
        let timeBetweenStrikes: Double
        let throwRange: Double
    }

    let archetypes: [String: Archetype]
    let weapons: Weapons
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
    /// The weight of each term in an action's score against the others (FR-BOT-080):
    /// attacking, the threat, a wound, an order, an ally's need and an emptying
    /// magazine. `wounded` is the fear of a bot with nothing left, from which its
    /// remaining health is taken.
    struct UtilityTermWeights: Decodable, Equatable {
        let attack: Double
        let threat: Double
        let wounded: Double
        let obedience: Double
        let mercy: Double
        let empty: Double
        /// A position's height above the snake's head, up to a floor (FR-BOT-110).
        let height: Double
        /// The length of the snake's shortest path to a position, up to the bot's
        /// detection range (FR-BOT-115).
        let snakePath: Double
        /// A position within the grouping distance of a squadmate, while the squad is
        /// alarmed (FR-BOT-190).
        let together: Double
        /// How much a position gains for lying near the part of the arena the squad's
        /// commander pointed at (FR-BOT-116).
        let ordered: Double
        /// Throwing a grenade, against `attack` for firing (FR-BOT-470). Below
        /// `attack`, or a bot would throw its two grenades in the first seconds of
        /// every firefight: at half of it a bot throws once its magazine is half gone.
        let blast: Double
        /// Throwing the knife (FR-BOT-520), which is what a bot has one of. Below
        /// `attack` as well, and for the same reason doubled: a throw costs the knife,
        /// and what it is worth has to carry that.
        let thrown: Double
    }
    let utilityTermWeights: UtilityTermWeights
    /// How tall a bot's figure is drawn, in metres, at its tallest (FR-VIEW-070).
    /// The figure is a model in its own proportions; this is the size it is set down
    /// at (ADR-0022).
    let figureHeight: Double
    /// How far above the ground it stands on a bot's eyes are, in metres: where it
    /// looks and fires from (FR-BOT-050, FR-BOT-060, ADR-0022).
    let eyeHeight: Double
    /// Degrees a second a bot turns at, to face where it goes or what it fires at
    /// (FR-BOT-280).
    let turnSpeed: Double
    /// Degrees across a bot's field of view, level, centred on the way it faces: it
    /// sees nothing outside it (FR-BOT-050).
    let fieldOfView: Double
    /// Seconds between the turns of a bot standing with nothing else worth doing
    /// (FR-BOT-380).
    let lookRoundInterval: Double
    /// Metres a second a round flies at, and metres it flies before it is spent
    /// (FR-BOT-060, FR-BOT-405).
    let roundSpeed: Double
    let roundRange: Double
    /// Metres a second a bot with no cell beside cover moves across its line of fire
    /// at while it fires, and seconds before it turns back (FR-BOT-430).
    let strafingSpeed: Double
    let strafingInterval: Double
    /// Metres a second squared a bot gathers speed and slows at (FR-BOT-290).
    let acceleration: Double
    /// Seconds after which a bot forgets a sighting of the snake, and of an enemy;
    /// nothing is forgotten where the time is zero (FR-BOT-260).
    let snakeForgottenAfter: Double
    let enemyForgottenAfter: Double
    /// Seconds it takes what one bot sees to reach the rest of its squad, per squad
    /// (FR-BOT-310).
    let shareDelay: [String: Double]

    private static let weights = Schema.object([
        "panic": .value, "discipline": .value, "aggression": .value, "selfSacrifice": .value,
        "courage": .value,
    ])

    static let schema = Schema.object([
        "archetypes": .named(of: .object([
            "basePersonalityWeights": weights,
            "allowedRanges": .named(of: .object(["lowest": .value, "highest": .value])),
            "runSpeed": .value,
            "health": .value,
            "detectionRange": .value,
            "arms": .object([
                "primary": .value, "sidearm": .value,
                "grenade": .value, "grenadesCarried": .value, "knife": .value,
            ]),
        ])),
        "weapons": .object([
            "firearms": .named(of: .object([
                "damage": .value, "range": .value, "timeBetweenShots": .value, "magazine": .value,
                "reloadTime": .value, "spareMagazines": .value,
            ])),
            "grenades": .named(of: .object([
                "damage": .value, "throwRange": .value, "fuseTime": .value,
                "blastRadius": .value, "furtherPartShare": .value,
            ])),
            "knives": .named(of: .object([
                "damage": .value, "reach": .value, "timeBetweenStrikes": .value, "throwRange": .value,
            ])),
        ]),
        "overrideDistance": .value,
        "interruptDistance": .value,
        "groupingDistance": .value,
        "hysteresisMargin": .value,
        "deliberationPeriod": .value,
        "perFrameSlotMaximum": .value,
        "collapsePanicIncrement": .value,
        "fearWhenUnhurt": .value,
        "utilityTermWeights": .object([
            "attack": .value, "threat": .value, "wounded": .value,
            "obedience": .value, "mercy": .value, "empty": .value,
            "height": .value, "snakePath": .value, "together": .value, "ordered": .value,
            "blast": .value, "thrown": .value,
        ]),
        "figureHeight": .value,
        "eyeHeight": .value,
        "turnSpeed": .value,
        "fieldOfView": .value,
        "lookRoundInterval": .value,
        "roundSpeed": .value,
        "roundRange": .value,
        "strafingSpeed": .value,
        "strafingInterval": .value,
        "acceleration": .value,
        "snakeForgottenAfter": .value,
        "enemyForgottenAfter": .value,
        "shareDelay": .named(of: .value),
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

// MARK: - Scoring (IF-SCORE-010)

/// What decides whether a meal was seen and a loss found out: the windows in which a
/// bot that sees the eating is its witness (FR-SCORE-070, FR-SCORE-080), how long a
/// witness takes to report (FR-SCORE-090), and how near a bot must come to where a
/// squadmate fell to find its body gone (FR-SCORE-125). The points and multipliers the
/// interface also names are read once scoring is built.
struct ScoringConfiguration: Decodable, Equatable {
    /// Seconds after a meal ends during which a bot that sees where it happened is its
    /// witness (FR-SCORE-070).
    let witnessWindow: Double
    /// Seconds after a meal ends during which a bot that comes to see where it happened
    /// is its witness (FR-SCORE-080).
    let lateArrivalWindow: Double
    /// Seconds from becoming a witness to the squad knowing (FR-SCORE-090).
    let reportDelay: Double
    /// Metres (FR-SCORE-125).
    let inspectionDistance: Double

    static let schema = Schema.object([
        "witnessWindow": .value,
        "lateArrivalWindow": .value,
        "reportDelay": .value,
        "inspectionDistance": .value,
    ])
}
