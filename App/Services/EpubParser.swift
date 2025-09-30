import Foundation

final class EpubParser: EPUBParsing {
  func parse(epubURL: URL) throws -> Book {
    // Stub: replace with real unzip + OPF parsing
    return Book(title: epubURL.deletingPathExtension().lastPathComponent,
                author: "Unknown",
                cover: nil,
                chapters: [])
  }
}
