import XCTest
@testable import EpubToAudiobook

final class ParserTests: XCTestCase {
  func testParserStub() throws {
    let parser = EpubParser()
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Sample.epub")
    FileManager.default.createFile(atPath: tmp.path, contents: Data(), attributes: nil)
    let book = try parser.parse(epubURL: tmp)
    XCTAssertFalse(book.title.isEmpty)
  }
}
