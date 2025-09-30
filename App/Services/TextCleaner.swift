import Foundation
import NaturalLanguage
import SwiftSoup

final class TextCleaner: TextProcessing {
  func cleanHTML(_ url: URL) -> String {
    guard let html = try? String(contentsOf: url) else { return "" }
    do {
      let doc: Document = try SwiftSoup.parse(html)
      try doc.select("script,style,nav,footer,figure,aside").remove()
      let bodyText = try doc.body()?.text() ?? ""
      return normalize(bodyText)
    } catch {
      return normalize(html)
    }
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

  private func normalize(_ text: String) -> String {
    var s = text
    s = s.replacingOccurrences(of: "-\n", with: "")
    s = s.replacingOccurrences(of: "\r", with: "\n")
    s = s.replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
    s = s.replacingOccurrences(of: "\n", with: " ")
    s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
