// Whether a map, as drawn, shows the snake a way its body cannot take (FR-MAP-260,
// ADR-0035). Asked of a map to be played, at launch, so that a map that looks open
// where it is closed is refused where it is written rather than found on the phone.
//
// Two pictures of each floor are laid over a fine grid and compared. What the eye
// sees: open where there is ground to stand on — on the ground floor the ground the
// setting draws, on any other floor its cells — and nothing that stops the body stands;
// shut everywhere else. What the snake can do: its head is somewhere only inside a cell
// it can stand in, and no nearer to what stops its body than the body's radius. Where
// the eye sees open ground and the head cannot be is the space between the two, and a
// map is refused where that space
//
// - runs between two things the eye sees apart, somewhere the snake can come to — a
//   gap it looks through and cannot take;
// - parts two stretches of ground the snake can stand on that the eye sees as one — a
//   way through it looks for and cannot find;
// - lies on the straight way between two places the snake stands, farther from what
//   stops its body than the body's radius — ground it sees and cannot walk, as in a
//   cell the drawn ground closes over. Ground drawn where it leads nowhere — beyond the
//   map's outermost cells, or in a corner the drawn edge rounds off — shows no way.
//
// None of those names a kind of place. A gap between walls, the side of a flight, a
// tree at the water's edge and a cell the drawn ground closes over are all found by
// the same comparison, and so is whatever nobody has thought of yet.
//
// implements: FR-MAP-260
import Foundation

enum Passages {
    /// A place where the map shows the snake a way it cannot take.
    struct Finding: Equatable {
        enum Kind: Equatable {
            /// A gap between two things the eye sees apart.
            case closedGap
            /// Two stretches of ground the eye sees as one and the snake cannot join.
            case partedGround
            /// Open ground on a straight way between two places the snake stands, which
            /// it cannot walk and nothing it sees is near enough to explain.
            case unreachableGround
        }

        let kind: Kind
        let level: Int
        /// The cell the finding is named by.
        let cell: PieceIndex.Cell
    }

    /// What the check is measured against: the snake's body, and the step it climbs.
    struct Body {
        let radius: Double
        let stepHeight: Double
    }

    /// Every place on the plan where the map shows a way the snake cannot take. `edge`
    /// is the setting's edge round the ground floor, where the setting draws one.
    static func findings(in map: MapSpecification, plan: ScenePlan, edge: Outline?,
                         body: Body) -> [Finding] {
        let groundLevel = plan.groundLevel
        var found: [Finding] = []
        for level in Set(plan.pieces.map(\.level)).sorted() {
            let drawn = level == groundLevel ? edge : nil
            found += Floor(level: level, map: map, plan: plan, edge: drawn, body: body).findings()
        }
        return found
    }

    /// Refuses a map to be played that shows the snake a way its body cannot take,
    /// naming the first such place by its line and column (FR-MAP-260).
    static func require(_ map: MapSpecification, plan: ScenePlan, setting: Setting, body: Body) throws {
        let first = findings(in: map, plan: plan, edge: setting.edge(around: plan), body: body).first
        if let finding = first {
            let place = map.place(of: finding.cell, floor: finding.level)
            throw MapParseError.wayNotTaken(line: place.line, column: place.column)
        }
    }

    // MARK: - One floor

    private struct Floor {
        let level: Int
        let grid: SampleGrid
        let cellSize: Double
        /// Where the eye sees ground with nothing on it that stops the body.
        let seenOpen: [Bool]
        /// Where the snake's head can be.
        let reachable: [Bool]
        /// Metres from each sample to the nearest thing that stops the body.
        let clearance: [Double]
        let radius: Double
        /// The cells of what stops the body, each with its footprint on the ground.
        let blockers: [(cell: PieceIndex.Cell, low: SIMD2<Double>, high: SIMD2<Double>)]

        init(level: Int, map: MapSpecification, plan: ScenePlan, edge: Outline?, body: Body) {
            self.level = level
            self.cellSize = plan.cellSize
            self.radius = body.radius
            let feet = Double(level) * plan.floorHeight
            // What the body cannot pass on this floor: what stops movement, and ground
            // more than a step above the floor — a flight's side (ADR-0033).
            let blocks = plan.pieces.filter { piece in
                guard piece.level == level, piece.size.min() > .zero else { return false }
                let bottom = piece.centre.y - piece.size.y * Geometry.half
                let top = piece.centre.y + piece.size.y * Geometry.half
                let inTheWay = piece.ground ? top > feet + body.stepHeight + Geometry.samePosition : piece.stopsMovement
                return inTheWay && bottom < feet + body.radius * Motion.heightInRadii && top > feet
            }
            let standable = Set(map.placements.filter { $0.floor == level && $0.isPassable }
                .map { PieceIndex.Cell(x: $0.x, z: $0.z) })
            let cells = plan.cells { $0 == level }

            if let edge {
                grid = edge.grid
            } else {
                let xs = cells.map(\.x), zs = cells.map(\.z)
                let pad = plan.cellSize * Geometry.half + body.radius + OutlineGrid.pad
                let low = SIMD2(Double(xs.min() ?? .zero), Double(zs.min() ?? .zero)) * plan.cellSize - pad
                let high = SIMD2(Double(xs.max() ?? .zero), Double(zs.max() ?? .zero)) * plan.cellSize + pad
                grid = SampleGrid(covering: low, high, step: OutlineGrid.step)
            }
            // The drawn ground, and over a floor below it the ground floor's own cells:
            // where there is none, the eye looks down into a basement.
            let drawn = edge.map { $0.region(atLeast: .zero, sparingBasements: false) }
            let basement = plan.cells { $0 < level }
            var shut = [Bool](repeating: false, count: grid.count)
            var ground = shut
            var inCell = shut
            for row in Int.zero..<grid.height {
                for column in Int.zero..<grid.width {
                    let p = grid.point(column, row)
                    let i = grid.index(column, row)
                    let here = PieceIndex.Cell(x: Int((p.x / plan.cellSize).rounded()), z: Int((p.y / plan.cellSize).rounded()))
                    if let drawn {
                        ground[i] = drawn[i] >= .zero && (cells.contains(here) || !basement.contains(here))
                    } else {
                        ground[i] = cells.contains(here)
                    }
                    inCell[i] = standable.contains(here)
                }
            }
            blockers = blocks.map { piece in
                let half = SIMD2(piece.size.x, piece.size.z) * Geometry.half
                let centre = SIMD2(piece.centre.x, piece.centre.z)
                return (PieceIndex.Cell(x: Int((centre.x / plan.cellSize).rounded()), z: Int((centre.y / plan.cellSize).rounded())),
                        centre - half, centre + half)
            }
            for piece in blocks {
                let half = SIMD2(piece.size.x, piece.size.z) * Geometry.half
                let centre = SIMD2(piece.centre.x, piece.centre.z)
                let low = ((centre - half - grid.origin) / grid.step).rounded(.up)
                let high = ((centre + half - grid.origin) / grid.step).rounded(.down)
                let first = SIMD2(max(Int(low.x), .zero), max(Int(low.y), .zero))
                let last = SIMD2(min(Int(high.x), grid.width - Distances.oneMore),
                                 min(Int(high.y), grid.height - Distances.oneMore))
                guard first.x <= last.x, first.y <= last.y else { continue }
                for row in first.y...last.y { for column in first.x...last.x { shut[grid.index(column, row)] = true } }
            }
            let clearance = DistanceField.distance(to: shut, on: grid)
            self.clearance = clearance
            seenOpen = zip(ground, shut).map { $0 && !$1 }
            let nearest = body.radius - grid.step * Geometry.half
            reachable = zip(inCell, clearance).map { $0 && $1 >= nearest }
        }

        func findings() -> [Finding] {
            let between = zip(seenOpen, reachable).map { $0 && !$1 }
            // What the eye sees as one thing: whatever is not open ground, with things
            // that touch joined — sampled, a touch can fall between two samples.
            let seenBlocked = seenOpen.map { !$0 }
            let near = DistanceField.distance(to: seenBlocked, on: grid).map { $0 <= grid.step * Samples.touch }
            let things = Labels(near, grid: grid, diagonal: true)
            let gaps = Labels(between, grid: grid, diagonal: true)
            let open = Labels(seenOpen, grid: grid, diagonal: false)
            let stands = Labels(reachable, grid: grid, diagonal: false)

            var found: [Finding] = []
            // A gap the eye looks through between two things, where the snake can
            // come to it.
            for gap in Int.zero..<gaps.count {
                var bordered = Set<Int>()
                var comesTo = false
                for i in gaps.members[gap] {
                    for j in grid.neighbours(i, diagonal: true) {
                        if seenBlocked[j], let thing = things.label[j] { bordered.insert(thing) }
                        if reachable[j] { comesTo = true }
                    }
                }
                guard comesTo, bordered.count > Distances.oneMore else { continue }
                // One gap can join many things — the ground drawn along the shore runs
                // round the whole island — so each is named, but the largest, where it
                // comes nearest to the largest: the gap is between those two.
                let ordered = bordered.sorted { things.members[$0].count < things.members[$1].count }
                guard let large = ordered.last else { continue }
                let fromLarge = DistanceField.distance(to: things.mask(large), on: grid)
                for small in ordered.dropLast() {
                    let nearest = things.members[small].filter { seenBlocked[$0] }.min { fromLarge[$0] < fromLarge[$1] }
                    if let nearest { found.append(finding(.closedGap, at: nearest, byWhatStandsThere: true)) }
                }
            }
            // Ground the eye sees as one, which the snake stands on in parts.
            for area in Int.zero..<open.count {
                let parts = Set(open.members[area].compactMap { stands.label[$0] })
                guard parts.count > Distances.oneMore else { continue }
                let ordered = parts.sorted { stands.members[$0].count < stands.members[$1].count }
                guard let small = ordered.first, let large = ordered.last else { continue }
                let fromSmall = DistanceField.distance(to: stands.mask(small), on: grid)
                let fromLarge = DistanceField.distance(to: stands.mask(large), on: grid)
                // The middle of the way between them: as far from either as it is from the
                // other, and no farther than it must be.
                let crossing = open.members[area].filter { between[$0] }.min {
                    max(fromSmall[$0], fromLarge[$0]) < max(fromSmall[$1], fromLarge[$1])
                }
                if let crossing { found.append(finding(.partedGround, at: crossing)) }
            }
            // Open ground on a straight way between two places the snake stands, where
            // nothing that stops its body is near enough to keep it out: along every
            // row and every column of samples, a run of such ground with the snake's
            // ground at both ends and nothing the eye sees as shut in between.
            let unexplained = (Int.zero..<grid.count).map {
                between[$0] && clearance[$0] >= radius + grid.step * Samples.tolerance
            }
            var ways: [Int] = []
            func walk(_ line: [Int]) {
                var start: Int?          // the last sample the snake stands on
                var run: [Int] = []      // unexplained samples since then
                var clear = true         // nothing shut since then
                for i in line {
                    if reachable[i] {
                        if start != nil, clear, !run.isEmpty { ways.append(run[run.count / 2]) }
                        start = i; run = []; clear = true
                    } else if !seenOpen[i] {
                        clear = false
                    } else if unexplained[i] {
                        run.append(i)
                    }
                }
            }
            for row in Int.zero..<grid.height { walk((Int.zero..<grid.width).map { grid.index($0, row) }) }
            for column in Int.zero..<grid.width { walk((Int.zero..<grid.height).map { grid.index(column, $0) }) }
            for gap in Set(ways.compactMap { gaps.label[$0] }).sorted() {
                // The middle of the unexplained ground in that gap.
                let members = gaps.members[gap].filter { unexplained[$0] }
                guard !members.isEmpty else { continue }
                let centre = members.reduce(SIMD2<Double>.zero) { $0 + grid.point($1 % grid.width, $1 / grid.width) }
                    / Double(members.count)
                func away(_ i: Int) -> Double {
                    let d = grid.point(i % grid.width, i / grid.width) - centre
                    return (d * d).sum()
                }
                if let middle = members.min(by: { away($0) < away($1) }) {
                    found.append(finding(.unreachableGround, at: middle))
                }
            }
            return found.sorted { ($0.cell.z, $0.cell.x, "\($0.kind)") < ($1.cell.z, $1.cell.x, "\($1.kind)") }
        }

        /// A finding named by the cell a sample lies in — or, `byWhatStandsThere`, by
        /// the cell of the piece the sample is part of: a sample on a piece's face lies
        /// on the line between two cells, and the piece is the one meant.
        private func finding(_ kind: Finding.Kind, at sample: Int, byWhatStandsThere: Bool = false) -> Finding {
            let p = grid.point(sample % grid.width, sample / grid.width)
            let slack = grid.step * Samples.touch
            let piece = blockers.first { p.x >= $0.low.x - slack && p.x <= $0.high.x + slack
                && p.y >= $0.low.y - slack && p.y <= $0.high.y + slack }
            let cell = byWhatStandsThere ? piece?.cell : nil
            return Finding(kind: kind, level: level,
                           cell: cell ?? PieceIndex.Cell(x: Int((p.x / cellSize).rounded()), z: Int((p.y / cellSize).rounded())))
        }
    }

    /// Numbers of samples the comparison allows for the grid it is made on.
    private enum Samples {
        /// Things this many steps apart are taken as touching: sampled, a touch can
        /// fall between two samples.
        static let touch = 1.5
        /// How far, in steps, a sampled distance can be off from the true one.
        static let tolerance = 2.0
    }

    /// The connected parts of a set of samples, each numbered.
    private struct Labels {
        /// For each sample, the part it belongs to; nil outside the set.
        let label: [Int?]
        let members: [[Int]]
        var count: Int { members.count }

        init(_ mask: [Bool], grid: SampleGrid, diagonal: Bool) {
            var label = [Int?](repeating: nil, count: mask.count)
            var members: [[Int]] = []
            for start in mask.indices where mask[start] && label[start] == nil {
                let part = members.count
                var stack = [start]
                var these: [Int] = []
                label[start] = part
                while let i = stack.popLast() {
                    these.append(i)
                    for j in grid.neighbours(i, diagonal: diagonal) where mask[j] && label[j] == nil {
                        label[j] = part
                        stack.append(j)
                    }
                }
                members.append(these)
            }
            self.label = label
            self.members = members
        }

        func mask(_ part: Int) -> [Bool] {
            var mask = [Bool](repeating: false, count: label.count)
            for i in members[part] { mask[i] = true }
            return mask
        }
    }
}

extension SampleGrid {
    /// The samples next to one, across and down, and corner to corner where asked.
    func neighbours(_ index: Int, diagonal: Bool) -> [Int] {
        let column = index % width, row = index / width
        let one = Distances.oneMore
        var around: [Int] = []
        for dz in -one...one {
            for dx in -one...one where (dx != .zero || dz != .zero) && (diagonal || dx == .zero || dz == .zero) {
                let c = column + dx, r = row + dz
                if c >= .zero, c < width, r >= .zero, r < height { around.append(self.index(c, r)) }
            }
        }
        return around
    }
}
