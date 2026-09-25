// What a test reaches into a collection with, so that a value that is not there fails
// the test that wanted it rather than taking the whole run down (specs/50-verification.md,
// "A test that fails reports a failure, never a crash"). A subscript out of range, a
// forced unwrap and `try!` all end the process; these end the test, and say which
// element was missing and how many there were.
//
// implements: FR-TOOL-280
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
