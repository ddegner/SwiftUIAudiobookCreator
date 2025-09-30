import Foundation

enum FileNamer {
  static func chapterFilename(index: Int, title: String) -> String {
    let safeTitle = title
      .replacingOccurrences(of: "[/\\:?*\"<>|]", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(format: "%03d %@.m4a", index + 1, safeTitle)
  }
}
