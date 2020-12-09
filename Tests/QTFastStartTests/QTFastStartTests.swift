import XCTest
@testable import QTFastStart

final class QTFastStartTests: XCTestCase {
    func testLocal() {
        do {
            let m4a = try Data(contentsOf: URL(fileURLWithPath: "/Users/jacky/Desktop/134646452-44100-2-fdf33f73afe05.m4a"))
            let optmized = QTFastStart().process(m4a)
            try optmized.write(to: URL(fileURLWithPath: "/Users/jacky/Desktop/optimized.m4a"))
        } catch {
            print(error)
            XCTFail()
        }
    }

    static var allTests = [
        ("testLocal", testLocal),
    ]
}
