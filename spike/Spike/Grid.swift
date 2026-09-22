// The navigation graph of ADR-0016: a grid of cells, each cell holding one or more
// walkable surfaces at different heights (a floor above a floor), edges between
// neighbouring surfaces within the step limit, plus explicit one-way transitions
// (drops). A* over it, with a straight-line smoothing pass. Throwaway code (spike/README.md).
import Foundation
import simd

struct GridNode: Hashable {
    let ix: Int
    let iz: Int
    let level: Int      // index into the cell's surfaces, lowest first
}

struct GridSurface {
    var height: Float
    var walkable: Bool
    var cost: Float = 1
}

final class NavGrid {
    let cellSize: Float
    let originX: Float, originZ: Float
    let nx: Int, nz: Int
    let stepLimit: Float
    // Surfaces per cell, flat: slot = cell * maxLevels + level; `count[cell]` says how many are used, sorted by height.
    static let maxLevels = 4
    private(set) var height: [Float]
    private(set) var walkable: [Bool]
    private(set) var cost: [Float]
    private(set) var count: [UInt8]
    private(set) var transitions: [Int: [(Int, flag: Int)]] = [:]  // node id -> one-way extra edges

    init(minX: Float, minZ: Float, maxX: Float, maxZ: Float, cellSize: Float, stepLimit: Float) {
        self.cellSize = cellSize
        self.originX = minX; self.originZ = minZ
        self.nx = Int(((maxX - minX) / cellSize).rounded(.up))
        self.nz = Int(((maxZ - minZ) / cellSize).rounded(.up))
        self.stepLimit = stepLimit
        let total = nx * nz * Self.maxLevels
        height = Array(repeating: 0, count: total)
        walkable = Array(repeating: false, count: total)
        cost = Array(repeating: 1, count: total)
        count = Array(repeating: 0, count: nx * nz)
    }

    var cellCount: Int { nx * nz }
    func surfaces(ofCell c: Int) -> Range<Int> { (c * Self.maxLevels)..<(c * Self.maxLevels + Int(count[c])) }

    // MARK: building

    func index(_ ix: Int, _ iz: Int) -> Int? {
        guard ix >= 0, iz >= 0, ix < nx, iz < nz else { return nil }
        return ix + iz * nx
    }

    func cellCoord(of p: SIMD3<Float>) -> (Int, Int) {
        (Int(((p.x - originX) / cellSize).rounded(.down)), Int(((p.z - originZ) / cellSize).rounded(.down)))
    }

    func center(_ n: GridNode) -> SIMD3<Float> {
        [originX + (Float(n.ix) + 0.5) * cellSize, height[(n.ix + n.iz * nx) * Self.maxLevels + n.level], originZ + (Float(n.iz) + 0.5) * cellSize]
    }

    /// Adds a surface at `h` to every cell whose centre is inside the XZ rectangle; `heightAt` may vary it (ramps).
    func addSurface(minX: Float, minZ: Float, maxX: Float, maxZ: Float, heightAt: (Float, Float) -> Float) {
        for iz in 0..<nz {
            for ix in 0..<nx {
                let cx = originX + (Float(ix) + 0.5) * cellSize, cz = originZ + (Float(iz) + 0.5) * cellSize
                guard cx >= minX, cx <= maxX, cz >= minZ, cz <= maxZ else { continue }
                let h = heightAt(cx, cz)
                let c = ix + iz * nx
                // Merge with an existing surface within half a metre (a ramp meeting a floor).
                if let k = surfaces(ofCell: c).first(where: { abs(height[$0] - h) <= 0.5 }) {
                    height[k] = max(height[k], h)
                    continue
                }
                guard Int(count[c]) < Self.maxLevels else { continue }
                // Insert keeping heights sorted.
                var k = c * Self.maxLevels + Int(count[c])
                while k > c * Self.maxLevels && height[k - 1] > h {
                    height[k] = height[k - 1]; walkable[k] = walkable[k - 1]; cost[k] = cost[k - 1]; k -= 1
                }
                height[k] = h; walkable[k] = true; cost[k] = 1
                count[c] += 1
            }
        }
    }

    /// Blocks every surface whose height lies in [bottom, top] inside the rectangle (a wall, a box).
    func block(minX: Float, minZ: Float, maxX: Float, maxZ: Float, bottom: Float, top: Float) {
        for iz in 0..<nz {
            for ix in 0..<nx {
                let cx = originX + (Float(ix) + 0.5) * cellSize, cz = originZ + (Float(iz) + 0.5) * cellSize
                guard cx >= minX, cx <= maxX, cz >= minZ, cz <= maxZ else { continue }
                for k in surfaces(ofCell: ix + iz * nx) where height[k] >= bottom - 0.01 && height[k] <= top { walkable[k] = false }
            }
        }
    }

    /// Removes walkability where another surface sits less than `clearance` above (the floor under a low ramp).
    func applyClearance(_ clearance: Float) {
        for c in 0..<cellCount {
            let r = surfaces(ofCell: c)
            for k in r {
                if r.contains(where: { $0 > k && height[$0] - height[k] < clearance }) { walkable[k] = false }
            }
        }
    }

    func addTransition(from a: SIMD3<Float>, to b: SIMD3<Float>, flag: Int) {
        guard let na = node(at: a), let nb = node(at: b) else { return }
        transitions[id(na), default: []].append((id(nb), flag))
    }

    /// The surface of the cell containing `p` whose height is closest to p.y — height-aware, unlike the API this replaces.
    func node(at p: SIMD3<Float>) -> GridNode? {
        let (ix, iz) = cellCoord(of: p)
        guard let c = index(ix, iz) else { return nil }
        var best = -1; var bestD = Float.greatestFiniteMagnitude
        for k in surfaces(ofCell: c) where walkable[k] {
            let d = abs(height[k] - p.y)
            if d < bestD { bestD = d; best = k - c * Self.maxLevels }
        }
        return best >= 0 ? GridNode(ix: ix, iz: iz, level: best) : nil
    }

    // MARK: neighbours and search

    // Flat node ids: (cell index * maxLevels + level). Search state lives in reusable arrays.
    private var gBuf: [Float] = []
    private var cameBuf: [Int32] = []
    private var closedBuf: [Bool] = []
    private var stamp: [Int32] = []
    private var currentStamp: Int32 = 0

    @inline(__always) private func id(_ n: GridNode) -> Int { (n.ix + n.iz * nx) * Self.maxLevels + n.level }
    @inline(__always) private func node(fromId i: Int) -> GridNode {
        let cell = i / Self.maxLevels
        return GridNode(ix: cell % nx, iz: cell / nx, level: i % Self.maxLevels)
    }

    /// A* from a to b. Returns cell centres (heights included), or nil when unreachable — never a partial path.
    func path(from a: SIMD3<Float>, to b: SIMD3<Float>, ignoreFlag: Int? = nil) -> [SIMD3<Float>]? {
        guard let start = node(at: a), let goal = node(at: b) else { return nil }
        if start == goal { return [] }
        let total = nx * nz * Self.maxLevels
        if gBuf.count != total {
            gBuf = Array(repeating: .greatestFiniteMagnitude, count: total)
            cameBuf = Array(repeating: -1, count: total)
            closedBuf = Array(repeating: false, count: total)
            stamp = Array(repeating: 0, count: total)
        }
        currentStamp &+= 1
        if currentStamp == 0 { currentStamp = 1; stamp = Array(repeating: 0, count: total) }
        let st = currentStamp
        @inline(__always) func touch(_ i: Int) {
            if stamp[i] != st { stamp[i] = st; gBuf[i] = .greatestFiniteMagnitude; cameBuf[i] = -1; closedBuf[i] = false }
        }
        let goalC = center(goal)
        let goalId = id(goal), startId = id(start)
        var open = MinHeap()
        touch(startId); gBuf[startId] = 0
        open.push(Int32(startId), 0)
        let dirs: [(Int, Int, Float)] = [(1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
        while let curId = open.pop().map({ Int($0) }) {
            if curId == goalId {
                var seq: [Int] = [goalId]; var c = goalId
                while cameBuf[c] >= 0 { c = Int(cameBuf[c]); seq.append(c) }
                return smooth(seq.reversed().map { center(node(fromId: $0)) })
            }
            if closedBuf[curId] { continue }
            closedBuf[curId] = true
            let cur = node(fromId: curId)
            let h = height[curId]
            let gCur = gBuf[curId]
            @inline(__always) func relax(_ nbId: Int, _ cost: Float, _ nb: GridNode) {
                touch(nbId)
                if closedBuf[nbId] { return }
                let ng = gCur + cost
                if ng < gBuf[nbId] {
                    gBuf[nbId] = ng; cameBuf[nbId] = Int32(curId)
                    let hcost = simd_length(center(nb) - goalC) / cellSize
                    open.push(Int32(nbId), ng + hcost)
                }
            }
            for (dx, dz, base) in dirs {
                let ix = cur.ix + dx, iz = cur.iz + dz
                guard ix >= 0, iz >= 0, ix < nx, iz < nz else { continue }
                let i = ix + iz * nx
                if dx != 0 && dz != 0 {
                    // No corner cutting.
                    let a = cur.ix + dx + cur.iz * nx, b = cur.ix + (cur.iz + dz) * nx
                    guard surfaces(ofCell: a).contains(where: { walkable[$0] && abs(height[$0] - h) <= stepLimit }),
                          surfaces(ofCell: b).contains(where: { walkable[$0] && abs(height[$0] - h) <= stepLimit }) else { continue }
                }
                for k in surfaces(ofCell: i) where walkable[k] && abs(height[k] - h) <= stepLimit {
                    relax(k, base * cost[k], GridNode(ix: ix, iz: iz, level: k - i * Self.maxLevels))
                }
            }
            if let t = transitions[curId] {
                for (m, flag) in t where flag != ignoreFlag { relax(m, 1, node(fromId: m)) }
            }
        }
        return nil
    }

    /// Drops intermediate waypoints where the straight line stays on walkable cells of the same surface.
    private func smooth(_ pts: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard pts.count > 2 else { return pts }
        var out = [pts[0]]; var i = 0
        while i < pts.count - 1 {
            // Look at most 12 waypoints ahead: a bounded cost per path, and paths turn every few cells anyway.
            var j = min(pts.count - 1, i + 12)
            while j > i + 1 && !lineClear(pts[i], pts[j]) { j -= 1 }
            out.append(pts[j]); i = j
        }
        return out
    }

    private func lineClear(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool {
        if abs(a.y - b.y) > stepLimit { return false }   // never cut across a level change
        let n = Int((simd_length(b - a) / cellSize).rounded(.up))
        guard n > 0 else { return true }
        for k in 0...n {
            let p = a + (b - a) * (Float(k) / Float(n))
            guard let n = node(at: p), abs(height[id(n)] - p.y) <= stepLimit else { return false }
        }
        return true
    }
}

/// A binary min-heap of (node id, priority); duplicates are tolerated, the closed set skips them.
struct MinHeap {
    private var items: [(Int32, Float)] = []
    mutating func push(_ n: Int32, _ p: Float) {
        items.append((n, p))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            if items[parent].1 <= items[i].1 { break }
            items.swapAt(parent, i); i = parent
        }
    }
    mutating func pop() -> Int32? {
        guard let top = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var m = i
                if l < items.count && items[l].1 < items[m].1 { m = l }
                if r < items.count && items[r].1 < items[m].1 { m = r }
                if m == i { break }
                items.swapAt(m, i); i = m
            }
        }
        return top.0
    }
}
