// What a bot looks like: a figure put together from rounded primitives, as ADR-0002
// has the whole game assembled, and as the concept's line-up of archetypes was
// rendered (`materials/concept/render-03.jpg`) — a big head, a short body, and an
// archetype told apart by its headgear and what it carries (FR-VIEW-070).
//
// Described as data first and built second, so that a test can read what a figure is
// made of without a renderer: which parts, where, and in what paint.
//
// The figure is a model and knows only its own proportions. How big it is drawn is
// the bot configuration's `figureHeight` (IF-BOT-010, ADR-0022), passed in when it is
// built; where a bot looks from is the configuration's `eyeHeight`, which the model
// does not read. The two agree when the eye height is the figure's height times the
// share of it the model's eyes are painted at (`eyeShare`), as the shipped numbers do.
//
// The figure faces +z, towards the camera (FR-VIEW-010), because a bot has no facing
// of its own to turn it by.
//
// file implements: FR-VIEW-340, FR-VIEW-060, FR-VIEW-070, FR-VIEW-290, FR-VIEW-240
import Foundation
import RealityKit
import UIKit

enum Figure {
    /// What a part is painted with. The squad's colour is on the body and on the
    /// headgear, so that the silhouette that names the archetype names the side too
    /// (FR-VIEW-060); everything else is shared by both squads.
    enum Paint: CaseIterable {
        case squad, skin, cloth, boots, metal, dark, white, lamp
    }

    enum Shape: Equatable {
        case box(SIMD3<Double>, corner: Double)
        case sphere(radius: Double)
        /// A cylinder is made standing along y; `lying` turns it onto z.
        case cylinder(radius: Double, height: Double, lying: Bool)
    }

    /// Which part of the figure says what: the headgear and the weapon are what
    /// FR-VIEW-070 reads an archetype from, the eyes are where the bot looks from.
    enum Role: Equatable {
        case body, head, eye, headgear, weapon, kit
        /// A leg and its boot, which swing together from the hip as the bot walks
        /// (FR-VIEW-290); the right one is on −x, since the figure faces +z.
        case leftLeg, rightLeg
    }

    /// One of the four things a bot carries (FR-BOT-440), as the figure draws them:
    /// what is in the hands is what it is using, and the rest hang where they are
    /// carried (FR-VIEW-340).
    enum Carried: String, CaseIterable, Equatable { case primary, sidearm, grenade, knife }

    struct Part: Equatable {
        let role: Role
        let shape: Shape
        /// Where its centre is, in metres from the point between the feet.
        let centre: SIMD3<Double>
        /// Stretch along each axis — a helmet is a squashed sphere.
        var stretch = SIMD3<Double>(1, 1, 1)
        /// Turned about the vertical, in radians: what a weapon slung across the back
        /// is turned by, where in the hands it points forward.
        var turn: Double = .zero
        let paint: Paint
        /// Which of the bot's weapons this part is, for the parts that are one: the
        /// view finds it by this to move it between the hands and its place.
        var carried: Carried?
    }

    /// The proportions the figure is drawn in: a figure this tall, with its eyes at
    /// `drawnEye`. Units that are nobody else's — the size on screen comes from the
    /// configuration, by `parts(for:height:)`.
    private static let drawnHeight = 1.6
    private static let drawnEye = 1.25
    /// How far up the figure its eyes are painted, as a share of its height. A bot
    /// configuration whose eye height is its figure height times this looks from where
    /// its figure's eyes are.
    static var eyeShare: Double { drawnEye / drawnHeight }

    /// The head, whose middle is where the eyes are, in the drawn proportions.
    private static let headRadius = 0.25
    private static let headCentre = drawnEye - 0.03
    /// Where the legs end and the body begins.
    private static let hips = 0.42

    /// The figure's parts set down at a height, in metres, at its tallest.
    ///
    /// `using` is the weapon drawn in the hands and `carrying` what the bot still has
    /// on it at all — a knife it has thrown and an empty pouch are drawn nowhere
    /// (FR-VIEW-340, FR-BOT-520).
    static func parts(for archetype: Archetype, height: Double,
                      using: Carried = .primary,
                      carrying: Set<Carried> = Set(Carried.allCases)) -> [Part] {
        let scale = height / drawnHeight
        return drawn(archetype, using: using, carrying: carrying).map { part in
            let shape: Shape
            switch part.shape {
            case .box(let size, let corner): shape = .box(size * scale, corner: corner * scale)
            case .sphere(let radius): shape = .sphere(radius: radius * scale)
            case .cylinder(let radius, let length, let lying):
                shape = .cylinder(radius: radius * scale, height: length * scale, lying: lying)
            }
            return Part(role: part.role, shape: shape, centre: part.centre * scale,
                        stretch: part.stretch, turn: part.turn, paint: part.paint, carried: part.carried)
        }
    }

    /// The figure in its drawn proportions.
    private static func drawn(_ archetype: Archetype, using: Carried = .primary,
                              carrying: Set<Carried> = Set(Carried.allCases)) -> [Part] {
        let heavy = archetype == .heavy
        let torso = heavy ? SIMD3(0.54, 0.5, 0.34) : SIMD3(0.42, 0.45, 0.28)
        let hips = Figure.hips
        let torsoCentre = hips + torso.y / 2
        var parts: [Part] = [
            // Legs and boots.
            Part(role: .rightLeg, shape: .box(SIMD3(0.15, 0.36, 0.16), corner: 0.04), centre: SIMD3(-0.1, 0.24, 0), paint: .cloth),
            Part(role: .leftLeg, shape: .box(SIMD3(0.15, 0.36, 0.16), corner: 0.04), centre: SIMD3(0.1, 0.24, 0), paint: .cloth),
            Part(role: .rightLeg, shape: .box(SIMD3(0.17, 0.08, 0.22), corner: 0.03), centre: SIMD3(-0.1, 0.04, 0.02), paint: .boots),
            Part(role: .leftLeg, shape: .box(SIMD3(0.17, 0.08, 0.22), corner: 0.03), centre: SIMD3(0.1, 0.04, 0.02), paint: .boots),
            // Torso and arms, in the squad's colour.
            Part(role: .body, shape: .box(torso, corner: 0.08), centre: SIMD3(0, torsoCentre, 0), paint: .squad),
            Part(role: .body, shape: .box(SIMD3(0.11, 0.36, 0.13), corner: 0.05),
                 centre: SIMD3(-(torso.x / 2 + 0.06), torsoCentre + 0.02, 0.03), paint: .squad),
            Part(role: .body, shape: .box(SIMD3(0.11, 0.36, 0.13), corner: 0.05),
                 centre: SIMD3(torso.x / 2 + 0.06, torsoCentre + 0.02, 0.03), paint: .squad),
            // The head, and the eyes on its face, looking at the camera.
            Part(role: .head, shape: .sphere(radius: headRadius), centre: SIMD3(0, headCentre, 0), paint: .skin),
            Part(role: .eye, shape: .sphere(radius: 0.028), centre: SIMD3(-0.08, drawnEye, headRadius - 0.03), paint: .dark),
            Part(role: .eye, shape: .sphere(radius: 0.028), centre: SIMD3(0.08, drawnEye, headRadius - 0.03), paint: .dark),
        ]
        parts += headgear(for: archetype)
        parts += carried(by: archetype, torso: torso, torsoCentre: torsoCentre,
                         using: using, carrying: carrying)
        return parts
    }

    /// What is on the head, in the squad's colour, and the one thing a camera looking
    /// down reads first.
    private static func headgear(for archetype: Archetype) -> [Part] {
        let top = headCentre + headRadius * 0.35
        let helmet = Part(role: .headgear, shape: .sphere(radius: 0.29), centre: SIMD3(0, top, -0.01),
                          stretch: SIMD3(1, 0.62, 1), paint: .squad)
        switch archetype {
        case .assault:
            // A plain round helmet.
            return [helmet]
        case .heavy:
            // A wider helmet with goggles across the front.
            return [Part(role: .headgear, shape: .sphere(radius: 0.33), centre: SIMD3(0, top, -0.01),
                         stretch: SIMD3(1.05, 0.62, 1.05), paint: .squad),
                    Part(role: .headgear, shape: .box(SIMD3(0.34, 0.08, 0.06), corner: 0.03),
                         centre: SIMD3(0, top + 0.02, 0.27), paint: .dark)]
        case .sapper:
            // The helmet with a lamp on its brow.
            return [helmet,
                    Part(role: .headgear, shape: .sphere(radius: 0.065), centre: SIMD3(0, top + 0.08, 0.25), paint: .lamp)]
        case .scout:
            // A cap: a shallow crown and a peak out front.
            return [Part(role: .headgear, shape: .sphere(radius: 0.26), centre: SIMD3(0, top, -0.02),
                         stretch: SIMD3(1, 0.45, 1), paint: .squad),
                    Part(role: .headgear, shape: .box(SIMD3(0.28, 0.03, 0.18), corner: 0.012),
                         centre: SIMD3(0, top - 0.02, 0.26), paint: .squad)]
        case .sniper:
            // A knitted hat, taller than a helmet, with a bobble on top.
            return [Part(role: .headgear, shape: .sphere(radius: 0.265), centre: SIMD3(0, top + 0.02, -0.01),
                         stretch: SIMD3(1, 0.85, 1), paint: .squad),
                    Part(role: .headgear, shape: .sphere(radius: 0.075), centre: SIMD3(0, drawnHeight - 0.075, -0.01), paint: .squad)]
        case .medic:
            // The helmet with a white band over it from front to back. Not a red
            // cross: that emblem is protected, and games keep off it (ADR-0022).
            return [helmet,
                    Part(role: .headgear, shape: .box(SIMD3(0.09, 0.04, 0.5), corner: 0.015),
                         centre: SIMD3(0, top + 0.175, -0.01), paint: .white)]
        }
    }

    /// What it carries (FR-VIEW-340): the weapon it is using in its hands, out in
    /// front where its outline shows from above, and the rest where each is carried —
    /// the primary across the back, the sidearm and the knife at the belt, the
    /// grenades at the belt in front.
    ///
    /// The primary is also the second half of what an archetype is read by (FR-VIEW-070),
    /// which is why each kind has a shape of its own and why the sapper keeps its
    /// sledgehammer: that is its wrecking tool rather than a weapon (ADR-0086), and it
    /// is drawn as kit.
    private static func carried(by archetype: Archetype, torso: SIMD3<Double>, torsoCentre: Double,
                                using: Carried, carrying: Set<Carried>) -> [Part] {
        let hand = torso.x / 2 + 0.06
        /// Where a weapon in the hands is: out in front, at the height of the chest.
        let held = SIMD3(0.06, torsoCentre, 0.26)
        let drawn = SIMD3(hand, torsoCentre - 0.2, 0.1)
        var parts: [Part] = []

        if carrying.contains(.primary) {
            let shape: Shape
            switch archetype {
            case .assault: shape = .box(SIMD3(0.07, 0.1, 0.46), corner: 0.02)
            case .heavy:   shape = .cylinder(radius: 0.1, height: 0.8, lying: true)
            case .sapper:  shape = .box(SIMD3(0.06, 0.09, 0.55), corner: 0.02)
            case .scout:   shape = .box(SIMD3(0.05, 0.08, 0.62), corner: 0.02)
            case .sniper:  shape = .box(SIMD3(0.05, 0.07, 1.0), corner: 0.02)
            case .medic:   shape = .box(SIMD3(0.06, 0.1, 0.32), corner: 0.02)
            }
            // The heavy's tube rides on the shoulder in its hands, where every other
            // primary is held at the chest.
            let inHand = archetype == .heavy
                ? SIMD3(hand + 0.02, torsoCentre + torso.y / 2 + 0.08, 0.12)
                : held
            let onBack = SIMD3(.zero, torsoCentre + 0.04, -(torso.z / 2 + 0.09))
            parts.append(Part(role: .weapon, shape: shape,
                              centre: using == .primary ? inHand : onBack,
                              turn: using == .primary ? .zero : .pi / 2,
                              paint: .metal, carried: .primary))
        }
        if carrying.contains(.sidearm) {
            parts.append(Part(role: .weapon, shape: .box(SIMD3(0.05, 0.09, 0.17), corner: 0.015),
                              centre: using == .sidearm ? drawn : SIMD3(hand, hips + 0.1, .zero),
                              paint: .metal, carried: .sidearm))
        }
        if carrying.contains(.knife) {
            parts.append(Part(role: .weapon, shape: .box(SIMD3(0.02, 0.05, 0.16), corner: 0.008),
                              centre: using == .knife ? drawn : SIMD3(-hand, hips + 0.1, .zero),
                              paint: .metal, carried: .knife))
        }
        if carrying.contains(.grenade) {
            parts.append(Part(role: .weapon, shape: .sphere(radius: 0.045),
                              centre: using == .grenade ? drawn : SIMD3(-0.05, hips + 0.12, torso.z / 2 + 0.03),
                              paint: .dark, carried: .grenade))
        }
        parts += kit(of: archetype, torso: torso, torsoCentre: torsoCentre, hand: hand)
        return parts
    }

    /// What an archetype carries that is not a weapon: the sapper's sledgehammer, held
    /// upright for breaking partitions (FR-BOT-070), and the medic's satchel.
    private static func kit(of archetype: Archetype, torso: SIMD3<Double>, torsoCentre: Double,
                            hand: Double) -> [Part] {
        switch archetype {
        case .sapper:
            return [Part(role: .kit, shape: .cylinder(radius: 0.025, height: 0.75, lying: false),
                         centre: SIMD3(hand + 0.08, 0.52, 0.06), paint: .cloth),
                    Part(role: .kit, shape: .box(SIMD3(0.13, 0.13, 0.26), corner: 0.02),
                         centre: SIMD3(hand + 0.08, 0.92, 0.06), paint: .metal)]
        case .medic:
            return [Part(role: .kit, shape: .box(SIMD3(0.1, 0.2, 0.24), corner: 0.03),
                         centre: SIMD3(-(hand + 0.02), hips + 0.02, .zero), paint: .white)]
        case .assault, .heavy, .scout, .sniper:
            return []
        }
    }

    /// Which weapon a bot is using, as its last decision says (FR-VIEW-340): what it
    /// is firing, throwing or striking with, and otherwise its primary, which is what
    /// a bot walks about holding.
    static func using(_ action: Action?) -> Carried {
        switch action {
        case .fire(_, .sidearm), .reload(.sidearm): return .sidearm
        case .throwGrenade: return .grenade
        case .strike, .throwKnife: return .knife
        case .fire, .reload, .close, .takeCover, .moveToOrderedZone, .flee, .heal, .advance, .explore,
             .takeTreasure, .carryTreasure, .none:
            return .primary
        }
    }

    /// What a bot still has on it to be drawn: both firearms always, an empty pouch
    /// and a thrown knife nowhere (FR-BOT-520).
    static func carrying(_ arms: Arms) -> Set<Carried> {
        var carried: Set<Carried> = [.primary, .sidearm]
        if arms.grenades.left > .zero { carried.insert(.grenade) }
        if arms.knife != nil { carried.insert(.knife) }
        return carried
    }

    // MARK: building it

    /// One figure as an entity, `height` metres tall, its origin at the feet. `materials` holds one per
    /// paint, made once for the whole squad so that a match's worth of figures shares
    /// a handful of materials rather than carrying a hundred.
    @MainActor
    static func make(_ archetype: Archetype, height: Double, materials: [Paint: any Material]) -> Entity {
        let figure = Entity()
        // Each leg hangs from a hip, a joint at the top of the leg, so that the walk
        // can swing it (FR-VIEW-290).
        let joints = [Role.leftLeg, .rightLeg].map { side -> (Role, Entity) in
            let joint = Entity()
            joint.name = side == .leftLeg ? EntityName.leftHip : EntityName.rightHip
            joint.position = SIMD3<Float>(hip(side, height: height))
            figure.addChild(joint)
            return (side, joint)
        }
        for part in parts(for: archetype, height: height) {
            let model = ModelEntity(mesh: mesh(for: part.shape), materials: [materials[part.paint] ?? SimpleMaterial()])
            // A weapon is named by which weapon it is, so that the view can find it
            // again and move it between the hands and its place (FR-VIEW-340).
            model.name = part.carried.map { EntityName.weapon($0.rawValue) } ?? "\(part.role)"
            model.position = SIMD3<Float>(part.centre)
            model.scale = SIMD3<Float>(part.stretch)
            model.orientation = turned(part)
            if let joint = joints.first(where: { $0.0 == part.role })?.1 {
                model.position -= joint.position
                joint.addChild(model)
            } else {
                figure.addChild(model)
            }
        }
        return figure
    }

    /// How a part is turned: about the vertical by its own turn, and a cylinder lying
    /// on z by the quarter turn that lays it there.
    static func turned(_ part: Part) -> simd_quatf {
        var orientation = simd_quatf(angle: Float(part.turn), axis: SIMD3<Float>(0, 1, 0))
        if case .cylinder(_, _, true) = part.shape {
            orientation *= simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        }
        return orientation
    }

    /// Where a leg's hip joint is on a figure `height` tall: at the top of the leg,
    /// over its middle.
    static func hip(_ side: Role, height: Double) -> SIMD3<Double> {
        let scale = height / drawnHeight
        return SIMD3(side == .rightLeg ? -legSpread : legSpread, hips, .zero) * scale
    }
    /// How far each leg stands off the middle, in the figure's own units.
    private static let legSpread = 0.1

    @MainActor
    private static func mesh(for shape: Shape) -> MeshResource {
        switch shape {
        // Of the game's own low shapes: RealityKit's rounded box is 13 068 triangles and
        // its sphere 8064 at any size, which made the eight figures four fifths of every
        // triangle in the frame (ADR-0046).
        case .box(let size, let corner):
            return .roundedBox(SIMD3<Float>(size), corner: Float(corner), segments: LowPoly.figureCornerSegments)
        case .sphere(let radius):
            return LowPolySphere.mesh(radius: Float(radius), rings: LowPoly.figureRings,
                                      segments: LowPoly.figureSegments)
                ?? .generateSphere(radius: Float(radius))
        case .cylinder(let radius, let height, _):
            return .generateCylinder(height: Float(height), radius: Float(radius))
        }
    }

    /// The paints for one squad.
    @MainActor
    static func materials(for squad: Squad) -> [Paint: any Material] {
        var result: [Paint: any Material] = [:]
        for paint in Paint.allCases {
            let rgb = colour(of: paint, squad: squad)
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y),
                                                     blue: CGFloat(rgb.z), alpha: 1))
            material.roughness = paint == .metal ? 0.5 : 0.8
            material.metallic = 0.0
            if paint == .lamp {
                material.emissiveColor = .init(color: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1))
                material.emissiveIntensity = 1
            }
            result[paint] = material
        }
        return result
    }

    /// Red, green and blue in 0…1. The squad's is `BotEntity.colour(for:)`, the one
    /// the tracers are drawn in; the rest belong to no side.
    static func colour(of paint: Paint, squad: Squad) -> SIMD3<Double> {
        switch paint {
        case .squad: return BotEntity.colour(for: squad)
        case .skin: return SIMD3(0.96, 0.86, 0.76)
        case .cloth: return SIMD3(0.36, 0.38, 0.44)
        case .boots: return SIMD3(0.28, 0.2, 0.15)
        case .metal: return SIMD3(0.3, 0.32, 0.36)
        case .dark: return SIMD3(0.12, 0.12, 0.14)
        case .white: return SIMD3(0.95, 0.95, 0.93)
        case .lamp: return SIMD3(1, 0.95, 0.7)
        }
    }
}
