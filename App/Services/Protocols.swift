import Foundation

protocol EPUBParsing {
  func parse(epubURL: URL) throws -> Book
}

protocol TextProcessing {
  func cleanHTML(_ url: URL) -> String
  func sentenceChunks(from text: String, targetChars: Int) -> [String]
}

protocol ChapterSynthesizing {
  func synthesize(
    chunks: [String],
    voiceID: String?,
    rate: Float,
    pitch: Float,
    to outURL: URL
  ) async throws -> TimeInterval
}

typealias ProgressHandler = (Int, Double, String) -> Void

actor ConversionEngine {
  func convert(
    epubURL: URL,
    settings: Settings,
    destination: URL,
    progress: ProgressHandler
  ) async throws -> Book {
    // Placeholder implementation
    throw NSError(domain: "ConversionEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]) 
  }
}
