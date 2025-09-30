import Foundation
import NaturalLanguage

final class TextCleaner: TextProcessing {
  func cleanHTML(_ url: URL) -> String {
    // Stub: replace with SwiftSoup cleaning
    (try? String(contentsOf: url)) ?? ""
  }

  func sentenceChunks(from text: String, targetChars: Int) -> [String] {
    var chunks: [String] = []
    let tokenizer = NLTokenizer(unit: .sentence)
    tokenizer.string = text
    var current = ""
    tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
      let sentence = String(text[range])
      if current.count + sentence.count > targetChars {
        if !current.isEmpty { chunks.append(current) }
        current = sentence
      } else {
        current += sentence
      }
      return true
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }
}
