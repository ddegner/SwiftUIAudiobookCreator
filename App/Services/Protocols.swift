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
    let parser = EpubParser()
    let cleaner = TextCleaner()
    let tts = TTSWriter()
    let tagger = MetadataWriter()

    var book = try parser.parse(epubURL: epubURL)
    // Create output directory Book Title (Author)
    let folderName = "\(book.title) (\(book.author))"
      .replacingOccurrences(of: "[/\\:?*\"<>|]", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let outDir = destination.appendingPathComponent(folderName, isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    for i in 0..<(book.chapters.count) {
      try Task.checkCancellation()
      var chapter = book.chapters[i]

      let text = cleaner.cleanHTML(chapter.htmlURL)
      if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 {
        progress(i, Double(i) / Double(max(book.chapters.count, 1)), "Skipping short chapter: \(chapter.title)")
        continue
      }
      let chunks = cleaner.sentenceChunks(from: text, targetChars: settings.chunkChars)

      let filename = FileNamer.chapterFilename(index: chapter.index, title: chapter.title)
      let outURL = outDir.appendingPathComponent(filename)
      let duration = try await tts.synthesize(
        chunks: chunks,
        voiceID: settings.voiceID,
        rate: settings.rate,
        pitch: settings.pitch,
        to: outURL
      )
      chapter.text = text
      chapter.outputURL = outURL
      chapter.duration = duration
      book.chapters[i] = chapter

      try? tagger.apply(
        to: outURL,
        bookTitle: book.title,
        author: book.author,
        chapterTitle: chapter.title,
        trackNumber: i + 1,
        artworkData: nil
      )

      let overall = Double(i + 1) / Double(max(book.chapters.count, 1))
      progress(i, overall, "Finished: \(chapter.title)")
    }
    return book
  }
}
