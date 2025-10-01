# Text Normalization Implementation

## Overview

The text normalization system processes EPUB content to prepare it for high-quality text-to-speech conversion. It handles various text formatting issues, removes unwanted elements, and applies custom transformations.

## Core Components

### TextNormalizationService

```swift
class TextNormalizationService: TextNormalizationServiceProtocol {
    private let footnoteDetector = FootnoteDetector()
    private let regexProcessor = RegexProcessor()
    
    func normalizeText(_ text: String, with settings: NormalizationSettings) async throws -> String {
        var normalizedText = text
        
        // Step 1: Remove page breaks and special formatting
        if settings.removePageBreaks {
            normalizedText = try await removePageBreaks(normalizedText)
        }
        
        // Step 2: Handle newlines based on settings
        normalizedText = try await normalizeNewlines(in: normalizedText, handling: settings.newlineHandling)
        
        // Step 3: Remove footnotes if enabled
        if settings.removeFootnotes {
            normalizedText = try await removeFootnotes(from: normalizedText, patterns: settings.footnotePatterns)
        }
        
        // Step 4: Apply custom text replacements
        normalizedText = try await applyCustomReplacements(to: normalizedText, replacements: settings.customReplacements)
        
        // Step 5: Normalize spacing
        if settings.normalizeSpacing {
            normalizedText = try await normalizeSpacing(normalizedText)
        }
        
        // Step 6: Remove special characters if enabled
        if settings.removeSpecialCharacters {
            normalizedText = try await removeSpecialCharacters(normalizedText)
        }
        
        return normalizedText
    }
    
    func detectFootnotes(in text: String) async -> [FootnoteRange] {
        return await footnoteDetector.detectFootnotes(in: text)
    }
    
    func removeFootnotes(from text: String, patterns: [String]) async throws -> String {
        return try await footnoteDetector.removeFootnotes(from: text, patterns: patterns)
    }
    
    func applyCustomReplacements(to text: String, replacements: [TextReplacement]) async throws -> String {
        return try await regexProcessor.applyReplacements(to: text, replacements: replacements)
    }
    
    func normalizeNewlines(in text: String, handling: NormalizationSettings.NewlineHandling) async throws -> String {
        switch handling {
        case .preserve:
            return text
        case .convertToSpaces:
            return text.replacingOccurrences(of: "\n", with: " ")
                         .replacingOccurrences(of: "\r", with: " ")
        case .remove:
            return text.replacingOccurrences(of: "\n", with: "")
                       .replacingOccurrences(of: "\r", with: "")
        }
    }
    
    func extractChapterTitle(from text: String) async -> String? {
        return await extractTitleFromText(text)
    }
    
    // MARK: - Private Methods
    
    private func removePageBreaks(_ text: String) async throws -> String {
        let pageBreakPatterns = [
            "\\[Page \\d+\\]",
            "\\[PAGE \\d+\\]",
            "\\[page \\d+\\]",
            "\\[Page\\d+\\]",
            "\\[PAGE\\d+\\]",
            "\\[page\\d+\\]",
            "\\f", // Form feed character
            "\\u{000C}" // Unicode form feed
        ]
        
        var result = text
        for pattern in pageBreakPatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return result
    }
    
    private func normalizeSpacing(_ text: String) async throws -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removeSpecialCharacters(_ text: String) async throws -> String {
        // Remove control characters but preserve basic punctuation
        let allowedCharacterSet = CharacterSet.whitespacesAndNewlines
            .union(.alphanumerics)
            .union(CharacterSet(charactersIn: ".,!?;:'\"()-"))
        
        return String(text.unicodeScalars.filter { allowedCharacterSet.contains($0) })
    }
    
    private func extractTitleFromText(_ text: String) async -> String? {
        let lines = text.components(separatedBy: .newlines)
        
        // Look for title-like patterns in the first few lines
        for line in lines.prefix(10) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmedLine.isEmpty else { continue }
            
            // Check if line looks like a title
            if isTitleLike(trimmedLine) {
                return trimmedLine
            }
        }
        
        return nil
    }
    
    private func isTitleLike(_ text: String) -> Bool {
        // Title characteristics:
        // - Not too long (less than 100 characters)
        // - Not all caps (unless very short)
        // - Contains some letters
        // - Doesn't start with common non-title words
        
        guard text.count <= 100 else { return false }
        guard text.rangeOfCharacter(from: .letters) != nil else { return false }
        
        let lowercaseText = text.lowercased()
        let nonTitleStarters = ["chapter", "part", "section", "page", "the", "a", "an"]
        
        for starter in nonTitleStarters {
            if lowercaseText.hasPrefix(starter + " ") {
                return false
            }
        }
        
        // If it's very short and all caps, it might be a title
        if text.count <= 20 && text == text.uppercased() {
            return true
        }
        
        // If it's mostly lowercase with some capitals, it's likely a title
        let uppercaseCount = text.filter { $0.isUppercase }.count
        let lowercaseCount = text.filter { $0.isLowercase }.count
        
        if uppercaseCount > 0 && lowercaseCount > uppercaseCount {
            return true
        }
        
        return false
    }
}
```

### FootnoteDetector

```swift
class FootnoteDetector {
    private let defaultPatterns = [
        "\\[\\d+\\]",           // [1], [2], etc.
        "\\(\\d+\\)",           // (1), (2), etc.
        "\\*\\d+\\*",           // *1*, *2*, etc.
        "\\d+\\.",              // 1., 2., etc.
        "\\d+\\s*\\]",          // 1], 2], etc.
        "\\d+\\s*\\)",          // 1), 2), etc.
        "\\d+\\s*\\*",          // 1*, 2*, etc.
        "\\^\\d+",              // ^1, ^2, etc.
        "\\d+\\s*\\^",          // 1^, 2^, etc.
        "\\[fn\\d+\\]",         // [fn1], [fn2], etc.
        "\\[note\\d+\\]",       // [note1], [note2], etc.
        "\\[footnote\\d+\\]"    // [footnote1], [footnote2], etc.
    ]
    
    func detectFootnotes(in text: String) async -> [FootnoteRange] {
        var footnotes: [FootnoteRange] = []
        let patterns = defaultPatterns
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            let range = NSRange(text.startIndex..., in: text)
            
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                
                let footnoteRange = FootnoteRange(
                    range: match.range,
                    text: String(text[Range(match.range, in: text)!]),
                    pattern: pattern
                )
                footnotes.append(footnoteRange)
            }
        }
        
        return footnotes
    }
    
    func removeFootnotes(from text: String, patterns: [String]) async throws -> String {
        var result = text
        let allPatterns = defaultPatterns + patterns
        
        for pattern in allPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            } catch {
                throw ConversionError.normalizationFailed("Invalid regex pattern: \(pattern)")
            }
        }
        
        return result
    }
    
    func removeFootnoteBlocks(from text: String) async throws -> String {
        // Remove entire footnote blocks (e.g., at the end of chapters)
        let footnoteBlockPatterns = [
            "\\n\\s*\\d+\\.\\s*[^\\n]+(?:\\n[^\\n]+)*",  // Numbered footnotes
            "\\n\\s*\\[\\d+\\]\\s*[^\\n]+(?:\\n[^\\n]+)*", // Bracketed footnotes
            "\\n\\s*\\*\\d+\\*\\s*[^\\n]+(?:\\n[^\\n]+)*"  // Starred footnotes
        ]
        
        var result = text
        
        for pattern in footnoteBlockPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .dotMatchesLineSeparators])
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            } catch {
                throw ConversionError.normalizationFailed("Invalid footnote block pattern: \(pattern)")
            }
        }
        
        return result
    }
}
```

### RegexProcessor

```swift
class RegexProcessor {
    func applyReplacements(to text: String, replacements: [TextReplacement]) async throws -> String {
        var result = text
        
        for replacement in replacements.filter({ $0.isEnabled }) {
            result = try await applyReplacement(replacement, to: result)
        }
        
        return result
    }
    
    private func applyReplacement(_ replacement: TextReplacement, to text: String) async throws -> String {
        do {
            if replacement.isRegex {
                let regex = try NSRegularExpression(pattern: replacement.pattern)
                let range = NSRange(text.startIndex..., in: text)
                return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement.replacement)
            } else {
                return text.replacingOccurrences(of: replacement.pattern, with: replacement.replacement)
            }
        } catch {
            throw ConversionError.normalizationFailed("Invalid regex pattern: \(replacement.pattern)")
        }
    }
    
    func validatePattern(_ pattern: String, isRegex: Bool) -> Bool {
        if isRegex {
            do {
                _ = try NSRegularExpression(pattern: pattern)
                return true
            } catch {
                return false
            }
        } else {
            return !pattern.isEmpty
        }
    }
}
```

### TextNormalizer (Utility Class)

```swift
class TextNormalizer {
    static func cleanWhitespace(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func normalizeQuotes(_ text: String) -> String {
        return text
            .replacingOccurrences(of: """, with: "\"")
            .replacingOccurrences(of: """, with: "\"")
            .replacingOccurrences(of: "'", with: "'")
            .replacingOccurrences(of: "'", with: "'")
    }
    
    static func normalizeDashes(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "—", with: " - ")
            .replacingOccurrences(of: "–", with: " - ")
            .replacingOccurrences(of: "―", with: " - ")
    }
    
    static func normalizeEllipses(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "…", with: "...")
            .replacingOccurrences(of: ". . .", with: "...")
    }
    
    static func removeHTMLTags(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
    
    static func expandAbbreviations(_ text: String) -> String {
        let abbreviations = [
            "Mr.": "Mister",
            "Mrs.": "Missus",
            "Dr.": "Doctor",
            "Prof.": "Professor",
            "Rev.": "Reverend",
            "St.": "Saint",
            "U.S.": "United States",
            "U.K.": "United Kingdom",
            "etc.": "etcetera",
            "vs.": "versus",
            "e.g.": "for example",
            "i.e.": "that is",
            "a.m.": "A M",
            "p.m.": "P M"
        ]
        
        var result = text
        for (abbreviation, expansion) in abbreviations {
            result = result.replacingOccurrences(of: abbreviation, with: expansion)
        }
        return result
    }
    
    static func normalizeNumbers(_ text: String) -> String {
        // Convert written numbers to digits for better TTS
        let numberWords = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
            "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
            "eighty": "80", "ninety": "90", "hundred": "100", "thousand": "1000",
            "million": "1000000", "billion": "1000000000"
        ]
        
        var result = text
        for (word, digit) in numberWords {
            result = result.replacingOccurrences(of: "\\b\(word)\\b", with: digit, options: [.regularExpression, .caseInsensitive])
        }
        return result
    }
}
```

## Advanced Text Processing

### Smart Text Segmentation

```swift
class TextSegmenter {
    func segmentIntoParagraphs(_ text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
        return paragraphs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func segmentIntoSentences(_ text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        return sentences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                       .filter { !$0.isEmpty }
    }
    
    func detectDialogue(_ text: String) -> [DialogueRange] {
        var dialogues: [DialogueRange] = []
        
        // Look for quoted dialogue
        let quotePattern = "\"([^\"]+)\""
        let regex = try! NSRegularExpression(pattern: quotePattern)
        let range = NSRange(text.startIndex..., in: text)
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match else { return }
            
            let dialogueRange = DialogueRange(
                range: match.range,
                text: String(text[Range(match.range, in: text)!]),
                speaker: extractSpeaker(from: text, around: match.range)
            )
            dialogues.append(dialogueRange)
        }
        
        return dialogues
    }
    
    private func extractSpeaker(from text: String, around range: NSRange) -> String? {
        // Look for speaker indicators before the dialogue
        let beforeRange = NSRange(location: max(0, range.location - 100), length: min(100, range.location))
        let beforeText = String(text[Range(beforeRange, in: text)!])
        
        let speakerPatterns = [
            "([A-Z][a-z]+)\\s+said:",
            "([A-Z][a-z]+)\\s+asked:",
            "([A-Z][a-z]+)\\s+replied:",
            "([A-Z][a-z]+)\\s+shouted:"
        ]
        
        for pattern in speakerPatterns {
            let regex = try! NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: beforeText, range: NSRange(beforeText.startIndex..., in: beforeText)) {
                return String(beforeText[Range(match.range(at: 1), in: beforeText)!])
            }
        }
        
        return nil
    }
}

struct DialogueRange {
    let range: NSRange
    let text: String
    let speaker: String?
}
```

## Usage Examples

### Basic Text Normalization

```swift
let normalizer = TextNormalizationService()
let settings = NormalizationSettings.default

let normalizedText = try await normalizer.normalizeText(originalText, with: settings)
```

### Custom Text Replacements

```swift
var settings = NormalizationSettings.default
settings.customReplacements.append(
    TextReplacement(pattern: "Dr\\.", replacement: "Doctor", isRegex: true)
)
settings.customReplacements.append(
    TextReplacement(pattern: "Mr\\.", replacement: "Mister", isRegex: true)
)

let normalizer = TextNormalizationService()
let processedText = try await normalizer.normalizeText(text, with: settings)
```

### Footnote Detection and Removal

```swift
let footnoteDetector = FootnoteDetector()
let footnotes = await footnoteDetector.detectFootnotes(in: text)
print("Found \(footnotes.count) footnotes")

let cleanText = try await footnoteDetector.removeFootnotes(from: text, patterns: ["\\[\\d+\\]"])
```

This comprehensive text normalization system ensures that EPUB content is properly prepared for high-quality TTS conversion while maintaining readability and natural flow.