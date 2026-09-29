// What a test reaches into a collection with, so that a value that is not there fails
// the test that wanted it rather than taking the whole run down (specs/50-verification.md,
// "A test that fails reports a failure, never a crash"). A subscript out of range, a
// forced unwrap and `try!` all end the process; these end the test, and say which
// element was missing and how many there were.
//
// implements: FR-TOOL-280
import RealityKit
import XCTest
@testable import CrawlCall

/// The element `offset` places from the start of a collection, or the test's failure
/// naming the offset and the count.
func element<C: Collection>(_ offset: Int, of collection: C,
                            file: StaticString = #filePath, line: UInt = #line) throws -> C.Element {
    try collection[checkedIndex(offset, of: collection, file: file, line: line)]
}

/// The index `offset` places from the start of a collection, for a test that changes
/// the element there, or the test's failure naming the offset and the count.
func checkedIndex<C: Collection>(_ offset: Int, of collection: C,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> C.Index {
    let found = offset >= 0
        ? collection.index(collection.startIndex, offsetBy: offset, limitedBy: collection.endIndex)
        : nil
    return try XCTUnwrap(found.flatMap { $0 == collection.endIndex ? nil : $0 },
                         "no element \(offset): the collection holds \(collection.count)",
                         file: file, line: line)
}

/// Three numbers as a vector, or the test's failure where there are not three.
func vector(_ numbers: [Double], file: StaticString = #filePath, line: UInt = #line) throws -> SIMD3<Double> {
    try XCTUnwrap(numbers.count == SIMD3<Double>.scalarCount ? SIMD3(numbers) : nil,
                  "\(numbers.count) numbers, not three: \(numbers)", file: file, line: line)
}

/// The position of the `corner`th index of a mesh's triangles: both the index and the
/// position it names come from the code under test, so either may be missing.
func vertex(_ corner: Int, of mesh: Mesh, file: StaticString = #filePath, line: UInt = #line) throws -> SIMD3<Double> {
    try element(Int(element(corner, of: mesh.indices, file: file, line: line)), of: mesh.positions,
                file: file, line: line)
}

extension Execution {
    /// Deliberation as a test poses it: every bot that knows the snake at all sees it
    /// now, where `snake` says, and one that does not has not seen it (FR-BOT-220).
    static func deliberate(_ bots: inout [Bot], slots: [Int], snake: [SIMD3<Double>], world: World) -> Volley {
        for index in bots.indices where bots[index].knowsSnake {
            bots[index].knowledge.snake = Dictionary(uniqueKeysWithValues: snake.enumerated().map {
                ($0.offset, Knowledge.Sighting(point: $0.element, time: .zero))
            })
        }
        return deliberate(&bots, slots: slots, world: world, now: .zero)
    }
}

/// How many triangles a mesh draws, over all its models and parts.
@MainActor
func triangles(of mesh: MeshResource) -> Int {
    mesh.contents.models.reduce(0) { sum, model in
        sum + model.parts.reduce(0) { $0 + ($1.triangleIndices?.count ?? 0) / 3 }
    }
}

/// The most triangles one shape of the game's own may take: RealityKit's generated
/// sphere is 8064 and its rounded box 13 068 at any size, where the game's own are a few
/// hundred; a tenth of the sphere tells the two kinds apart (ADR-0037, ADR-0046).
let mostTrianglesOfOneShape = 800
