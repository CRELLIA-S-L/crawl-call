// The catalogue of error kinds (ART-070). Every error the game reports names its kind
// by one of these identifiers and opens its line with it — `MAP_REPEATED_KIT: line 4
// names the kit a second time` — so that a search, a filter or a test holds on to the
// kind while the wording of the message is free to improve (FR-TOOL-200).
//
// One enum rather than a list per error type: raw values of one enum are unique by
// construction — the compiler rejects a second case with the same string — which is
// the "unique across the game" the requirement asks for, kept by the language instead
// of by a test.
//
// implements: FR-TOOL-200
import Foundation

enum ErrorIdentifier: String, CaseIterable {
    // Configuration files (ADR-0012).
    case configFileMissing = "CONFIG_FILE_MISSING"
    case configNotJSON = "CONFIG_NOT_JSON"
    case configBadShape = "CONFIG_BAD_SHAPE"
    case configUndecodable = "CONFIG_UNDECODABLE"

    // The shape a configuration file must have.
    case schemaNotAnObject = "SCHEMA_NOT_AN_OBJECT"
    case schemaUnknownKey = "SCHEMA_UNKNOWN_KEY"
    case schemaMissingKey = "SCHEMA_MISSING_KEY"
    case schemaWrongKind = "SCHEMA_WRONG_KIND"

    // A module kit and its legend.
    case kitMissing = "KIT_MISSING"
    case kitLegendKeyNotOneCharacter = "KIT_LEGEND_KEY_NOT_ONE_CHARACTER"
    case kitModuleFieldNotThreeNumbers = "KIT_MODULE_FIELD_NOT_THREE_NUMBERS"
    case kitStepModuleNotInLegend = "KIT_STEP_MODULE_NOT_IN_LEGEND"

    // Finding and reading a map file.
    case mapMissing = "MAP_MISSING"
    case mapUnreadable = "MAP_UNREADABLE"

    // Parsing a map file (IF-MAP-010).
    case mapNoKit = "MAP_NO_KIT"
    case mapNoFloors = "MAP_NO_FLOORS"
    case mapRepeatedKit = "MAP_REPEATED_KIT"
    case mapNoSetting = "MAP_NO_SETTING"
    case mapRepeatedSetting = "MAP_REPEATED_SETTING"
    case mapUnknownDirective = "MAP_UNKNOWN_DIRECTIVE"
    case mapGridBeforeAnyFloor = "MAP_GRID_BEFORE_ANY_FLOOR"
    case mapRepeatedFloor = "MAP_REPEATED_FLOOR"
    case mapBadFloorNumber = "MAP_BAD_FLOOR_NUMBER"
    case mapBadTransition = "MAP_BAD_TRANSITION"
    case mapTransitionToUnknownFloor = "MAP_TRANSITION_TO_UNKNOWN_FLOOR"
    case mapRaggedGrid = "MAP_RAGGED_GRID"
    case mapUnknownCharacter = "MAP_UNKNOWN_CHARACTER"
    case mapEmptyFloor = "MAP_EMPTY_FLOOR"
    case mapFlightLeadsNowhere = "MAP_FLIGHT_LEADS_NOWHERE"
    case mapFlightTooSteep = "MAP_FLIGHT_TOO_STEEP"

    // The setting a map names (FR-MAP-120, FR-MAP-140).
    case settingUnknown = "SETTING_UNKNOWN"
    case settingHorizonInFrame = "SETTING_HORIZON_IN_FRAME"
    case sceneryNoAmbientLight = "SCENERY_NO_AMBIENT_LIGHT"
    case scenerySkyImageNotPainted = "SCENERY_SKY_IMAGE_NOT_PAINTED"
    case scenerySkyNotGenerated = "SCENERY_SKY_NOT_GENERATED"

    // Building the scene's light.
    case sceneAmbientBitmapNotCreated = "SCENE_AMBIENT_BITMAP_NOT_CREATED"
    case sceneAmbientBitmapNotReadBack = "SCENE_AMBIENT_BITMAP_NOT_READ_BACK"
    case sceneAmbientLightNotGenerated = "SCENE_AMBIENT_LIGHT_NOT_GENERATED"
}

/// What stands between an error's identifier and its message (FR-TOOL-200).
enum ErrorLine {
    static let separator = ": "
}

/// An error that knows its kind. Its line is the identifier, the separator and the
/// details, in that order, whatever the error is — the format lives here once, and an
/// error type supplies only which kind it is and what happened.
protocol IdentifiedError: Error, CustomStringConvertible {
    var identifier: ErrorIdentifier { get }
    /// What happened, for a person: the part of the line that describes and
    /// configures nothing, and so stays where the error is raised (ART-070).
    var details: String { get }
}

extension IdentifiedError {
    var description: String { identifier.rawValue + ErrorLine.separator + details }
}
