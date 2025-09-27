import Foundation

enum TextCleanupError: Error {
    case invalidRules
}

struct SearchReplaceRule: Decodable, Sendable {
    let pattern: String
    let replacement: String
    let options: String?
}

enum TextCleanup {
    static func sanitizeTitle(_ raw: String) -> String {
        let collapsed = raw.replacingOccurrences(of: "\s+", with: " ", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "[\t\r\n]+", with: " ", options: .regularExpression)
        return cleaned
    }

    static func applyNewlineMode(_ text: String, mode: NewlineMode, breakString: String) -> String {
        switch mode {
        case .single:
            return text.replacingOccurrences(of: "\n+", with: breakString, options: .regularExpression)
        case .double:
            return text
                .replacingOccurrences(of: "\n{2,}", with: breakString, options: .regularExpression)
                .replacingOccurrences(of: "(?<!\n)\n(?!\n)", with: " ", options: .regularExpression)
        case .none:
            return text.replacingOccurrences(of: "\n", with: " ")
        }
    }

    static func cleanupFootnotes(_ text: String) -> String {
        var processed = text
        processed = processed.replacingOccurrences(of: "(?<=[\u{2000}-\u{206F}\u{2E00}-\u{2E7F}\p{P}])\s*\d{1,3}(?!\w)", with: "", options: [.regularExpression])
        processed = processed.replacingOccurrences(of: "\[(?:\d+(?:\.\d+)*)\]", with: "", options: [.regularExpression])
        return processed
    }

    static func applyRules(from url: URL?, to text: String) throws -> String {
        guard let url = url else { return text }
        let data = try Data(contentsOf: url)
        let rules = try JSONDecoder().decode([SearchReplaceRule].self, from: data)
        var result = text
        for rule in rules {
            var opts: NSRegularExpression.Options = []
            if let options = rule.options?.lowercased() {
                if options.contains("i") { opts.insert(.caseInsensitive) }
            }
            let regex = try NSRegularExpression(pattern: rule.pattern, options: opts)
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
        }
        return result
    }
}

