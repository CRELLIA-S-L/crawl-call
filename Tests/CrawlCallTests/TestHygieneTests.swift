// The suite's own code holds nothing that ends the test process when a value is not
// there: no `try!`, no `as!`, no forced unwrap, no subscript by a number
// (specs/50-verification.md, "A test that fails reports a failure, never a crash").
// Without this the rule would hold only as long as everybody remembered it.
//
// file verifies: FR-TOOL-280
//
// The source is read as text: comments and string literals are passed over, and the
// code inside a string's interpolation is read as code. An implicitly unwrapped
// property a fixture is set up into (`var kit: Kit!`) is a declaration, not an unwrap,
// and is not counted. A dictionary keyed by numbers is looked up by a named key, so
// that its lookups are not taken for an array's.
import XCTest

final class TestHygieneTests: XCTestCase {
    struct Finding: Equatable, CustomStringConvertible {
        let file: String
        let line: Int
        let what: String
        var description: String { "\(file):\(line): \(what)" }
    }

    /// The code of a Swift source with comments and string literals blanked out, line
    /// for line; the code inside an interpolation is kept.
    static func code(of source: String) -> [String] {
        enum Mode { case code, lineComment, blockComment, string, multiline }
        var modes: [Mode] = [.code]
        var depths: [Int] = [0]           // open parentheses of each interpolation
        var out = ""
        let chars = Array(source)
        var i = 0
        func at(_ k: Int) -> Character? { k < chars.count ? chars[k] : nil }
        while i < chars.count {
            let c = chars[i]
            switch modes.last ?? .code {
            case .code:
                if c == "/", at(i + 1) == "/" { modes.append(.lineComment); out += "  "; i += 2; continue }
                if c == "/", at(i + 1) == "*" { modes.append(.blockComment); out += "  "; i += 2; continue }
                if c == "\"", at(i + 1) == "\"", at(i + 2) == "\"" { modes.append(.multiline); out += "   "; i += 3; continue }
                if c == "\"" { modes.append(.string); out += " "; i += 1; continue }
                if depths.count > 1 {
                    if c == "(" { depths[depths.count - 1] += 1 }
                    if c == ")" {
                        if depths[depths.count - 1] == 0 { depths.removeLast(); modes.removeLast(); out += " "; i += 1; continue }
                        depths[depths.count - 1] -= 1
                    }
                }
                out.append(c)
            case .lineComment:
                if c == "\n" { modes.removeLast(); out.append(c) } else { out += " " }
            case .blockComment:
                if c == "*", at(i + 1) == "/" { modes.removeLast(); out += "  "; i += 2; continue }
                out += c == "\n" ? "\n" : " "
            case .string, .multiline:
                let multiline = modes.last == .multiline
                if c == "\\", at(i + 1) == "(" { modes.append(.code); depths.append(0); out += "  "; i += 2; continue }
                if c == "\\" { out += "  "; i += 2; continue }
                if multiline, c == "\"", at(i + 1) == "\"", at(i + 2) == "\"" { modes.removeLast(); out += "   "; i += 3; continue }
                if !multiline, c == "\"" { modes.removeLast(); out += " "; i += 1; continue }
                out += c == "\n" ? "\n" : " "
            }
            i += 1
        }
        return out.components(separatedBy: "\n")
    }

    /// What in one line of code would end the process when a value is not there.
    static func crashes(in line: String) -> [String] {
        var found: [String] = []
        if line.contains("try!") { found.append("try!") }
        if line.contains("as!") { found.append("as!") }
        // A fixture's implicitly unwrapped property is declared, not unwrapped.
        let declaration = line.range(of: #"^\s*(private |fileprivate )?var \w+: [\w.<>\[\], ]+!\s*$"#,
                                     options: .regularExpression) != nil
        let unwrap = line.replacingOccurrences(of: "try!", with: "").replacingOccurrences(of: "as!", with: "")
        if !declaration, unwrap.range(of: #"[\w\)\]\?]!(?!=)"#, options: .regularExpression) != nil {
            found.append("forced unwrap")
        }
        if line.range(of: #"[\w\)\]\?]\[\s*\d+\s*\]"#, options: .regularExpression) != nil {
            found.append("subscript by a number")
        }
        return found
    }

    static func findings(in directory: URL) throws -> [Finding] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var found: [Finding] = []
        for file in files {
            let lines = code(of: try String(contentsOf: file, encoding: .utf8))
            for (number, line) in lines.enumerated() {
                for what in crashes(in: line) {
                    found.append(Finding(file: file.lastPathComponent, line: number + 1, what: what))
                }
            }
        }
        return found
    }

    func testTheSuiteHoldsNothingThatWouldCrashItWhereAValueIsMissing() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let found = try Self.findings(in: directory)
        XCTAssertEqual(found, [], "\n" + found.map(\.description).joined(separator: "\n"))
        // The suite is read at all: this file is among what was read.
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains("TestHygieneTests.swift"))
    }

    // MARK: - What the suite reaches into collections with

    func testAnElementThatIsThereIsReturned() throws {
        XCTAssertEqual(try element(0, of: [7, 8]), 7)
        XCTAssertEqual(try element(1, of: [7, 8]), 8)
        var numbers = [7, 8]
        numbers[try checkedIndex(1, of: numbers)] = 9
        XCTAssertEqual(numbers, [7, 9])
        XCTAssertEqual(try vector([1, 2, 3]), SIMD3(1, 2, 3))
    }

    func testAMissingElementFailsTheTestAndSaysWhatWasThere() {
        // Each of these records the failure a test would, and throws to end that test;
        // none of them ends the process.
        let expected = ["no element 2: the collection holds 2", "no element -1: the collection holds 2",
                        "no element 0: the collection holds 0", "2 numbers, not three: [1.0, 2.0]"]
        var seen: [String] = []
        XCTExpectFailure("a missing element is the test's failure") { issue in
            seen.append(issue.compactDescription)
            return true
        }
        XCTAssertThrowsError(try element(2, of: [7, 8]))
        XCTAssertThrowsError(try checkedIndex(-1, of: [7, 8]))
        XCTAssertThrowsError(try element(0, of: [Int]()))
        XCTAssertThrowsError(try vector([1, 2]))
        XCTAssertEqual(seen.count, expected.count, "\(seen)")
        for (description, message) in zip(seen, expected) {
            XCTAssertTrue(description.contains(message), "\(description) does not say \(message)")
        }
    }

    // MARK: - The reading itself

    func testEachWayOfCrashingIsFound() {
        XCTAssertEqual(Self.crashes(in: "let kit = try! Kit.load()"), ["try!"])
        XCTAssertEqual(Self.crashes(in: "let bot = thing as! Bot"), ["as!"])
        XCTAssertEqual(Self.crashes(in: "XCTAssertEqual(heights.max()!, 1)"), ["forced unwrap"])
        XCTAssertEqual(Self.crashes(in: "let a = module!.size"), ["forced unwrap"])
        XCTAssertEqual(Self.crashes(in: "XCTAssertTrue(bots[0].knowsSnake)"), ["subscript by a number"])
        XCTAssertEqual(Self.crashes(in: "let row = csv.split(separator: \",\")[1]"), ["subscript by a number"])
    }

    func testWhatCannotCrashIsNotFound() {
        XCTAssertEqual(Self.crashes(in: "XCTAssertTrue(a != b)"), [])
        XCTAssertEqual(Self.crashes(in: "XCTAssertFalse(!flag)"), [])
        XCTAssertEqual(Self.crashes(in: "    private var kit: Kit!"), [])
        XCTAssertEqual(Self.crashes(in: "let bot = try element(0, of: bots)"), [])
        XCTAssertEqual(Self.crashes(in: "bots[first].knowsSnake = true"), [])
        XCTAssertEqual(Self.crashes(in: "let rows: [Int] = []"), [])
    }

    func testCommentsAndStringsAreNotCodeButInterpolationsAre() {
        let source = """
        let a = 1 // bots[0]! try!
        /* bots[1] */ let b = "try! bots[2]!"
        let c = "bot\\(bots[3].id)"
        let d = \"\"\"
        bots[4]!
        \"\"\"
        """
        let lines = Self.code(of: source)
        XCTAssertEqual(lines.count, 6)
        XCTAssertEqual(lines.map { Self.crashes(in: $0) }, [[], [], ["subscript by a number"], [], [], []])
    }
}
