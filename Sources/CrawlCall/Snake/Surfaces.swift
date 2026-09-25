// Where the snake's head may be, in metres, answered from the same navigation graph
// the bots path over and the same tuning numbers they are measured by (FR-MAP-025) —
// and how close to what stands on that ground its body may come, answered from the
// boxes the scene is built from (ADR-0021).
//
// Heights are the graph's: a cell's surface is its node's, which on a flight of stairs
// is not its floor's (FR-MAP-020, FR-MAP-150, ADR-0033).
//
// implements: FR-MAP-025, FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-220, FR-MAP-150, FR-MAP-020, FR-MAP-220, FR-SNAKE-260
import Foundation

struct Surfaces {
    let graph: NavigationGraph
    let cellSize: Double
    let floorHeight: Double
    /// The largest drop the head may take and still call it a path (IF-MAP-020).
    let maximumDropHeight: Double
    /// Metres a second squared the head falls under off a ledge (FR-SNAKE-220).
    let dropGravity: Double
    /// How wide the body is, which is how close to a wall the head may come.
    let bodyRadius: Double
    /// The tallest step the head may climb; with the stage-1 grid nothing is stepped,
    /// and it is read here so that snake and graph cannot disagree later.
    let stepHeight: Double
    /// The steepest slope the head may take, read for the same reason.
    let slopeAngle: Double
    /// The cells something stands in that the head cannot walk through. The graph
    /// cannot tell these from thin air — both are simply not walkable — and the
    /// difference is the whole of it: air is a ledge to drop from, a wall is a wall
    /// (FR-SNAKE-010).
    private let occupied: Set<NavigationGraph.Node>
    /// What the body may not pass: every module the map places, as the box the scene
    /// is built from, with whether it is ground. A module that is not ground is in the
    /// way wherever it reaches the body's height; ground is in the way only where it
    /// stands more than a step above the body's feet — the side of a step too tall to
    /// climb onto — and is walked on otherwise (ADR-0021, ADR-0033).
    private let obstacles: [(lowest: SIMD3<Double>, highest: SIMD3<Double>, ground: Bool)]
    /// The cells of gaps in a floor narrower than the body, which the snake crawls
    /// across at the floor's height rather than falling into (FR-SNAKE-260). The graph
    /// holds none of them: a bot does not cross a gap.
    let bridges: Set<NavigationGraph.Node>

    init(graph: NavigationGraph, kit: Kit, tuning: TuningConfiguration, map: MapSpecification) {
        self.occupied = Set(map.placements.filter { !$0.isPassable }
            .map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
        // What stops no movement — a shrub — is no obstacle at all (FR-MAP-220).
        self.obstacles = ScenePlan.make(map: map, kit: kit, cellSize: tuning.navigationGraphCellSize).pieces
            .filter { $0.stopsMovement || $0.ground }
            .map { (lowest: $0.centre - $0.size * Geometry.half, highest: $0.centre + $0.size * Geometry.half,
                    ground: $0.ground) }
        self.graph = graph
        self.cellSize = tuning.navigationGraphCellSize
        self.floorHeight = kit.floorHeight
        self.maximumDropHeight = tuning.maximumDropHeight
        self.dropGravity = tuning.dropGravity
        self.bodyRadius = tuning.bodyRadius
        self.stepHeight = tuning.stepHeight
        self.slopeAngle = tuning.slopeAngle
        self.bridges = Self.narrowGaps(in: graph, occupied: occupied, cellSize: tuning.navigationGraphCellSize,
                                       floorHeight: kit.floorHeight, stepHeight: tuning.stepHeight,
                                       bodyRadius: tuning.bodyRadius)
    }

    /// The cells of every floor that hold nothing to stand on, in a gap too narrow for
    /// the body: somewhere no point is as far from the floor around it as the body's
    /// radius. What holds the body at a floor's height is its cells — a surface from a
    /// step below that height up to the floor above, on whichever floor, or a cell
    /// something stands on — and a
    /// gap is the empty ground among them, sampled on a fine grid. A gap that reaches
    /// the grid's edge is as wide as the world beyond the map, and is a ledge.
    private static func narrowGaps(in graph: NavigationGraph, occupied: Set<NavigationGraph.Node>,
                                   cellSize: Double, floorHeight: Double, stepHeight: Double,
                                   bodyRadius: Double) -> Set<NavigationGraph.Node> {
        var found: Set<NavigationGraph.Node> = []
        for floor in graph.floors {
            let elevation = Double(floor) * floorHeight
            // A surface near this floor's height holds the body; one rising from it — a
            // flight's taller steps — stands on it, and is no gap either.
            let holding = Set(graph.nodes.filter {
                let h = graph.height(of: $0, floorHeight: floorHeight)
                return h >= elevation - stepHeight && h < elevation + floorHeight
            }.map { PieceIndex.Cell(x: $0.x, z: $0.z) })
                .union(occupied.filter { $0.floor == floor }.map { PieceIndex.Cell(x: $0.x, z: $0.z) })
            guard !holding.isEmpty else { continue }
            let xs = holding.map(\.x), zs = holding.map(\.z)
            let pad = cellSize + bodyRadius * Geometry.bothSides
            let low = SIMD2(Double(xs.min() ?? .zero), Double(zs.min() ?? .zero)) * cellSize - pad
            let high = SIMD2(Double(xs.max() ?? .zero), Double(zs.max() ?? .zero)) * cellSize + pad
            let grid = SampleGrid(covering: low, high, step: OutlineGrid.step)
            func cell(_ i: Int) -> PieceIndex.Cell {
                let p = grid.point(i % grid.width, i / grid.width)
                return PieceIndex.Cell(x: Int((p.x / cellSize).rounded()), z: Int((p.y / cellSize).rounded()))
            }
            let held = (Int.zero..<grid.count).map { holding.contains(cell($0)) }
            let fromFloor = DistanceField.distance(to: held, on: grid)
            var seen = [Bool](repeating: false, count: grid.count)
            for start in held.indices where !held[start] && !seen[start] {
                var stack = [start], members: [Int] = [], wide = false
                seen[start] = true
                while let i = stack.popLast() {
                    members.append(i)
                    let column = i % grid.width, row = i / grid.width
                    if column == .zero || row == .zero || column == grid.width - Distances.oneMore
                        || row == grid.height - Distances.oneMore || fromFloor[i] >= bodyRadius { wide = true }
                    for j in grid.neighbours(i, diagonal: false) where !held[j] && !seen[j] {
                        seen[j] = true
                        stack.append(j)
                    }
                }
                guard !wide else { continue }
                for i in members {
                    let c = cell(i)
                    found.insert(NavigationGraph.Node(floor: floor, x: c.x, z: c.z))
                }
            }
        }
        return found
    }

    /// The cell a position falls in. Cells are centred on their coordinates, so the
    /// nearest index is the one the position belongs to.
    func cell(of position: SIMD3<Double>, floor: Int) -> NavigationGraph.Node {
        NavigationGraph.Node(floor: floor,
                             x: Int((position.x / cellSize).rounded()),
                             z: Int((position.z / cellSize).rounded()))
    }

    /// The height of a floor's walking surface.
    func elevation(of floor: Int) -> Double { Double(floor) * floorHeight }

    /// The height of a node's walking surface: on a flight, its step's.
    func height(of node: NavigationGraph.Node) -> Double { graph.height(of: node, floorHeight: floorHeight) }

    /// The node a head at `here` walks onto when it crosses into the cell at `target`:
    /// the neighbour the graph joins it to there, on whichever floor — the same floor,
    /// or, off the top of a flight, the floor above (FR-MAP-020). The one nearest in
    /// height where there is more than one. Nil where the graph joins nothing there.
    ///
    /// A head that crosses a corner of its cell enters the cell corner to corner with
    /// it, which the graph does not join directly: it joins cells side by side. It
    /// goes through one of the two cells beside both, where the graph joins it to that
    /// one and that one to the cell it entered. Taken for a ledge, a corner dropped the
    /// head off a balcony wherever it crossed one (FR-SNAKE-220, ADR-0036). Where
    /// neither cell beside both joins them, the two cells meet at a point, which is a
    /// gap narrower than the body, crawled across (FR-SNAKE-260).
    ///
    /// A gap in the floor narrower than the body is crawled across at the floor's
    /// height (FR-SNAKE-260): its cells, which the graph does not hold, are walked
    /// onto and off like the floor's own.
    func step(from here: NavigationGraph.Node, into target: NavigationGraph.Node) -> NavigationGraph.Node? {
        if let next = besideStep(from: here, into: target) { return next }
        guard abs(target.x - here.x) == MapGrid.neighbourStep, abs(target.z - here.z) == MapGrid.neighbourStep else { return nil }
        for through in [NavigationGraph.Node(floor: here.floor, x: target.x, z: here.z),
                        NavigationGraph.Node(floor: here.floor, x: here.x, z: target.z)] {
            if let middle = besideStep(from: here, into: through), let next = besideStep(from: middle, into: target) {
                return next
            }
        }
        return ground(at: target, near: height(of: here))
    }

    private func besideStep(from here: NavigationGraph.Node, into target: NavigationGraph.Node) -> NavigationGraph.Node? {
        guard abs(target.x - here.x) + abs(target.z - here.z) == MapGrid.neighbourStep else { return nil }
        let at = height(of: here)
        // Off a bridge the graph joins nothing; onto one it joins nothing either. Both
        // are ground within a step, as the graph's own edges are.
        let joined = graph.isWalkable(here) && !bridges.contains(here)
            ? graph.neighbours(of: here).filter { $0.x == target.x && $0.z == target.z }
            : []
        let candidates = joined.isEmpty ? (ground(at: target, near: at).map { [$0] } ?? []) : Array(joined)
        return candidates.min { abs(height(of: $0) - at) < abs(height(of: $1) - at) }
    }

    /// Ground at a cell within a step of a height: a node of the graph, or a cell of a
    /// gap narrower than the body (FR-SNAKE-260). Nil where there is none.
    private func ground(at cell: NavigationGraph.Node, near at: Double) -> NavigationGraph.Node? {
        let there = graph.floors.map { NavigationGraph.Node(floor: $0, x: cell.x, z: cell.z) }
            .filter { graph.isWalkable($0) || bridges.contains($0) }
            .filter { abs(height(of: $0) - at) <= stepHeight + Geometry.samePosition }
        return there.min { abs(height(of: $0) - at) < abs(height(of: $1) - at) }
    }

    /// The floor a declared transition leads down to from this cell, if there is one.
    /// A transition is an edge and an edge has two ends: the bots walk it either way
    /// and so does the snake, which is what keeps a balcony from being a trap.
    func descent(at position: SIMD3<Double>, from floor: Int) -> Int? {
        let here = cell(of: position, floor: floor)
        return graph.neighbours(of: here)
            .filter { $0.x == here.x && $0.z == here.z && $0.floor < floor }
            .map(\.floor)
            .max()
    }

    /// The floor a declared transition leads up to from this cell, if there is one.
    /// A transition is an edge of the graph between the same cell on two floors
    /// (FR-MAP-020), which is what a map's `transition` line becomes — so the stairs
    /// the head climbs and the edge the bots path along are the same thing, said
    /// once.
    func rise(at position: SIMD3<Double>, from floor: Int) -> Int? {
        let here = cell(of: position, floor: floor)
        return graph.neighbours(of: here)
            .filter { $0.x == here.x && $0.z == here.z && $0.floor > floor }
            .map(\.floor)
            .min()
    }

    /// The ground the head lands on when it leaves a ledge at `height`: the highest
    /// surface below it at the same place, lower by more than a step — a step lower is
    /// walked down, not dropped to — and no further down than the tuning allows
    /// (FR-SNAKE-220). The side of a flight is such a ledge as well as a balcony's edge.
    /// Nil where there is nothing to land on within reach.
    func landing(below position: SIMD3<Double>, from floor: Int, at height: Double) -> NavigationGraph.Node? {
        // A ledge is where nothing stands. Walking into a wall with an open floor
        // beneath it is walking into a wall, not stepping off an edge — and without
        // this the head drops through the balcony's own walls.
        guard !occupied.contains(cell(of: position, floor: floor)) else { return nil }
        let here = cell(of: position, floor: floor)
        guard let node = graph.node(atX: here.x, z: here.z, below: height - stepHeight - Geometry.samePosition),
              height - self.height(of: node) <= maximumDropHeight + Geometry.samePosition else { return nil }
        return node
    }

    /// Where a head that walked off a ledge at `edge`, at `speed` along `unit`, comes
    /// down (FR-SNAKE-220, ADR-0040): as far on as it goes in the time it falls under
    /// the drop gravity, and no farther than the air at the ledge's height is open,
    /// or nearer, where that is where the ground below first lets the body land clear
    /// with nothing in its way to it; straight down where nothing farther does. The
    /// caller has already found straight down open.
    func arc(from edge: SIMD3<Double>, floor: Int, along unit: SIMD2<Double>,
             speed: Double) -> (landing: SIMD3<Double>, floor: Int, seconds: Double)? {
        let feet = edge.y
        func fallTime(to height: Double) -> Double {
            dropGravity > .zero ? (Geometry.bothSides * max(feet - height, .zero) / dropGravity).squareRoot() : .zero
        }
        func point(_ metres: Double, at height: Double) -> SIMD3<Double> {
            SIMD3(edge.x + unit.x * metres, height, edge.z + unit.y * metres)
        }
        func landing(_ metres: Double) -> (landing: SIMD3<Double>, floor: Int, seconds: Double)? {
            guard let below = self.landing(below: point(metres, at: feet), from: floor, at: feet) else { return nil }
            let ground = height(of: below)
            let seconds = fallTime(to: ground)
            guard metres <= speed * seconds + Geometry.samePosition,
                  fits(point(metres, at: ground), feet: ground, leaving: feet) else { return nil }
            // Nothing down there in the body's way to it, asked at the landing's height:
            // what stands lower than the ledge it leaves is flown over.
            var along = Motion.arcCheckStep
            while along < metres {
                guard fits(point(along, at: ground), feet: ground, leaving: feet) else { return nil }
                along += Motion.arcCheckStep
            }
            return (point(metres, at: ground), below.floor, seconds)
        }
        // The arc flies through open air at the ledge's height: where ground comes back
        // at that height — the far side of a hole — the arc ends short of it by the
        // body's radius, rather than going on under the floor it left.
        var open: Double = .zero
        let farthest = speed * fallTime(to: feet - maximumDropHeight)
        while open < farthest,
              ground(at: cell(of: point(open + Motion.arcCheckStep, at: feet), floor: floor), near: feet) == nil {
            open += Motion.arcCheckStep
        }
        let reach = open < farthest ? max(open - bodyRadius, .zero) : farthest
        var metres = (reach / Motion.arcSearchStep).rounded(.down) * Motion.arcSearchStep
        while metres > .zero {
            if let found = landing(metres) { return found }
            metres -= Motion.arcSearchStep
        }
        return landing(.zero)
    }

    // MARK: the body against what stands on the ground (ADR-0021)

    /// How far the body at a position is from the nearest thing it cannot pass, and
    /// which way on the ground leads away from it. Metres are the gap between the
    /// body and the module: zero where it touches, negative where it is inside.
    /// Nil where nothing stands at the body's height on that floor.
    ///
    /// The body is a circle of its radius around the head on the ground plane, as
    /// tall as it is wide, standing on the floor's surface; a module counts when its
    /// box reaches into that height, so a wall of the floor above is not in the way
    /// of a head on the floor below.
    func clearance(at position: SIMD3<Double>, floor: Int) -> (metres: Double, away: SIMD2<Double>)? {
        clearance(at: position, feet: elevation(of: floor))
    }

    /// The same, for a body whose feet are at `feet` metres: on a flight, its step's.
    ///
    /// `leaving` is the height of a ledge the body is dropping from, where it is: what
    /// was not in its way up there — the step whose side it slides down, and the next
    /// step up, which it stood a step below — is not in the way of its landing either,
    /// though the body lands half beside them and walks clear of them after (FR-SNAKE-220).
    func clearance(at position: SIMD3<Double>, feet bottom: Double,
                   leaving ledge: Double = -.infinity) -> (metres: Double, away: SIMD2<Double>)? {
        let top = bottom + Motion.heightInRadii * bodyRadius
        let groundInTheWay = max(bottom, ledge) + stepHeight + Geometry.samePosition
        var nearest: (metres: Double, away: SIMD2<Double>)?
        for box in obstacles where box.lowest.y < top && box.highest.y > bottom
            && (!box.ground || box.highest.y > groundInTheWay) {
            let offset = SIMD2(position.x - (box.lowest.x + box.highest.x) * Geometry.half,
                               position.z - (box.lowest.z + box.highest.z) * Geometry.half)
            let half = SIMD2((box.highest.x - box.lowest.x) * Geometry.half,
                             (box.highest.z - box.lowest.z) * Geometry.half)
            // How far outside the footprint along each axis; negative inside it.
            let beyond = SIMD2(abs(offset.x) - half.x, abs(offset.y) - half.y)
            let outside = SIMD2(max(beyond.x, .zero), max(beyond.y, .zero))
            let length = (outside.x * outside.x + outside.y * outside.y).squareRoot()
            let metres: Double
            let away: SIMD2<Double>
            if length > .zero {
                metres = length
                away = SIMD2(offset.x < .zero ? -outside.x : outside.x,
                             offset.y < .zero ? -outside.y : outside.y) / length
            } else if beyond.x > beyond.y {
                // Inside: out through the nearest side.
                metres = beyond.x
                away = SIMD2(offset.x < .zero ? Geometry.belowSide : Geometry.aboveSide, .zero)
            } else {
                metres = beyond.y
                away = SIMD2(.zero, offset.y < .zero ? Geometry.belowSide : Geometry.aboveSide)
            }
            let gap = metres - bodyRadius
            if nearest == nil || gap < nearest!.metres { nearest = (gap, away) }
        }
        return nearest
    }

    /// How far the body can go from a position along a direction on the ground, up
    /// to a distance, and which way leads away from what stopped it, where something
    /// did. The body stops where it touches, not where the step began.
    ///
    /// A body already inside something may go wherever it goes no deeper, so that a
    /// head set down overlapping a wall is not frozen there.
    ///
    /// Only the far end of the step is asked about, and that is enough: a step is
    /// never longer than half a cell, and the thinnest module in a kit is still wider
    /// than that once the body's width is added on each side of it — a partition of
    /// 0.1 m is 0.7 m to a body of 0.3 m — so no step can pass from one side of a
    /// module to the other.
    func room(from position: SIMD3<Double>, feet: Double, along unit: SIMD2<Double>,
              upTo distance: Double) -> (metres: Double, against: SIMD2<Double>?) {
        let deepest = min(.zero, clearance(at: position, feet: feet)?.metres ?? .zero)
        func at(_ metres: Double) -> SIMD3<Double> {
            SIMD3(position.x + unit.x * metres, position.y, position.z + unit.y * metres)
        }
        func fits(_ metres: Double) -> Bool {
            guard let there = clearance(at: at(metres), feet: feet) else { return true }
            return there.metres >= deepest - Motion.depthSlack
        }
        if fits(distance) { return (distance, nil) }
        var low: Double = .zero
        var high = distance
        while high - low > Motion.contactPrecision {
            let middle = (low + high) * Geometry.half
            if fits(middle) { low = middle } else { high = middle }
        }
        // What stopped the body is what it would be inside of just past the contact —
        // not what is nearest at the contact, where a body in a corner touches two
        // things at once and the one it is not pressing into may be named.
        return (low, clearance(at: at(high), feet: feet)?.away)
    }

    /// Whether the body can stand at a position without being inside anything.
    func fits(_ position: SIMD3<Double>, floor: Int) -> Bool {
        fits(position, feet: elevation(of: floor))
    }

    /// The same, for a body whose feet are at `feet` metres, dropping from a ledge at
    /// `leaving` where it is.
    func fits(_ position: SIMD3<Double>, feet: Double, leaving ledge: Double = -.infinity) -> Bool {
        (clearance(at: position, feet: feet, leaving: ledge)?.metres ?? .zero) >= -Motion.overlapTolerance
    }

    /// A place for the body near a position, clear of what it cannot pass: moved out
    /// of whatever it overlaps, without leaving the cell the position is in. The
    /// position itself where that cannot be done.
    ///
    /// The match sets the head down with this (ADR-0021): it starts at a spawn point
    /// (`Game.start`, FR-MAP-180), which can be a corner of a room, and a body wider
    /// than a cell sits in both walls there.
    func clear(_ position: SIMD3<Double>, feet: Double) -> SIMD3<Double> {
        var here = position
        for _ in Int.zero..<Motion.pushOutAttempts {
            guard let near = clearance(at: here, feet: feet), near.metres < .zero else { break }
            here += SIMD3(near.away.x, .zero, near.away.y) * -near.metres
        }
        // The cell is a matter of x and z alone; any floor names it.
        guard cell(of: here, floor: .zero) == cell(of: position, floor: .zero),
              fits(here, feet: feet) else { return position }
        return here
    }
}
