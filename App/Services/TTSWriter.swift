import AVFoundation
import Foundation

final class TTSWriter: ChapterSynthesizing {
  func synthesize(
    chunks: [String],
    voiceID: String?,
    rate: Float,
    pitch: Float,
    to outURL: URL
  ) async throws -> TimeInterval {
    // Stub: implement AVSpeechSynthesizer.write + AVAssetWriter
    if FileManager.default.fileExists(atPath: outURL.path) {
      try FileManager.default.removeItem(at: outURL)
    }
    FileManager.default.createFile(atPath: outURL.path, contents: Data(), attributes: nil)
    return 0
  }
}
