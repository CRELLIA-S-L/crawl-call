// Which pieces of the plan cover which cells of the ground. A question about a short
// stretch of the map — is anything between this bot's eyes and that cell — need not
// look at every piece of it, and on the blockout "every piece" is 558 (ADR-0028).
//
// The index only narrows the list: a caller still asks each candidate the question it
// asked before, so an answer through the index is the answer without it.
//
// implements: FR-BOT-050, FR-BOT-118
import Foundation

struct PieceIndex: Equatable {
    struct Cell: Hashable {
        let x: Int
        let z: Int
    }

    private let cellSize: Double
    private let pieceCount: Int
    private let cells: [Cell: [Int]]

    init(pieces: [ScenePlan.Piece], cellSize: Double) {
        self.cellSize = cellSize
        self.pieceCount = pieces.count
        var cells: [Cell: [Int]] = [:]
        if cellSize > .zero {
            for (index, piece) in pieces.enumerated() where piece.size.min() > .zero {
                let low = piece.centre - piece.size * Geometry.half
                let high = piece.centre + piece.size * Geometry.half
                for x in Self.cell(low.x, cellSize)...Self.cell(high.x, cellSize) {
                    for z in Self.cell(low.z, cellSize)...Self.cell(high.z, cellSize) {
                        cells[Cell(x: x, z: z), default: []].append(index)
                    }
                }
            }
        }
        self.cells = cells
    }

    /// The pieces whose footprint touches the ground between two corners, each once.
    /// Touching counts: a piece whose edge lies on the box's edge is a candidate, as the
    /// box test after it would keep it.
    func candidates(low: SIMD3<Double>, high: SIMD3<Double>) -> [Int] {
        // A box the grid cannot hold — no cell size, a coordinate that is not a number,
        // a span wider than the map has pieces — is answered with every piece, as the
        // scan before the index answered everything.
        // Checked without building anything: this runs for every sight test.
        guard cellSize > .zero,
              low.x.isFinite, low.z.isFinite, high.x.isFinite, high.z.isFinite,
              (high.x - low.x) / cellSize < Double(pieceCount),
              (high.z - low.z) / cellSize < Double(pieceCount) else { return Array(Int.zero..<pieceCount) }
        let xs = Self.cell(low.x, cellSize)...Self.cell(high.x, cellSize)
        let zs = Self.cell(low.z, cellSize)...Self.cell(high.z, cellSize)
        // Both spans are under the piece count here, so their product cannot overflow.
        guard xs.count * zs.count < pieceCount else { return Array(Int.zero..<pieceCount) }
        var seen = [Bool](repeating: false, count: pieceCount)
        var found: [Int] = []
        for x in xs {
            for z in zs {
                for index in cells[Cell(x: x, z: z)] ?? [] where !seen[index] {
                    seen[index] = true
                    found.append(index)
                }
            }
        }
        return found
    }

    private static func cell(_ metres: Double, _ size: Double) -> Int {
        Int((metres / size).rounded(.down))
    }
}
