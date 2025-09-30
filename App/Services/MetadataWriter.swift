import AVFoundation
import Foundation

final class MetadataWriter {
  func apply(
    to url: URL,
    bookTitle: String,
    author: String,
    chapterTitle: String,
    trackNumber: Int,
    artworkData: Data?
  ) throws {
    // Stub: In practice, set AVAssetWriter metadata before writing or remux after.
  }
}
