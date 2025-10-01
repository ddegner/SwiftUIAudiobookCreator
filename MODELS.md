# Data Models

## Core Models

### EPUBBook
```swift
struct EPUBBook: Codable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let publisher: String?
    let publicationDate: Date?
    let language: String?
    let description: String?
    let coverImage: Data?
    let chapters: [EPUBChapter]
    let fileURL: URL
    let isDRMProtected: Bool
    let epubVersion: EPUBVersion
    let totalWordCount: Int
    
    enum EPUBVersion: String, Codable {
        case epub2 = "2.0"
        case epub3 = "3.0"
    }
}
```

### EPUBChapter
```swift
struct EPUBChapter: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let wordCount: Int
    let estimatedDuration: TimeInterval?
    let sourceURL: URL?
    let normalizedContent: String?
    
    // Computed properties
    var displayTitle: String {
        title.isEmpty ? "Chapter \(order)" : title
    }
}
```

### NormalizationSettings
```swift
struct NormalizationSettings: Codable {
    var newlineHandling: NewlineHandling
    var removeFootnotes: Bool
    var footnotePatterns: [String]
    var customReplacements: [TextReplacement]
    var preserveChapterTitles: Bool
    var removePageBreaks: Bool
    var normalizeSpacing: Bool
    var removeSpecialCharacters: Bool
    
    enum NewlineHandling: String, CaseIterable, Codable {
        case preserve = "preserve"
        case convertToSpaces = "convert_to_spaces"
        case remove = "remove"
        
        var displayName: String {
            switch self {
            case .preserve: return "Preserve"
            case .convertToSpaces: return "Convert to Spaces"
            case .remove: return "Remove"
            }
        }
    }
    
    static let `default` = NormalizationSettings(
        newlineHandling: .convertToSpaces,
        removeFootnotes: true,
        footnotePatterns: [
            "\\[\\d+\\]",
            "\\(\\d+\\)",
            "\\*\\d+\\*"
        ],
        customReplacements: [],
        preserveChapterTitles: true,
        removePageBreaks: true,
        normalizeSpacing: true,
        removeSpecialCharacters: false
    )
}

struct TextReplacement: Codable, Identifiable {
    let id: UUID
    var pattern: String
    var replacement: String
    var isRegex: Bool
    var isEnabled: Bool
    
    init(pattern: String, replacement: String, isRegex: Bool = false) {
        self.id = UUID()
        self.pattern = pattern
        self.replacement = replacement
        self.isRegex = isRegex
        self.isEnabled = true
    }
}
```

### TTSSettings
```swift
struct TTSSettings: Codable {
    var voice: TTSVoice
    var speed: Double // 0.5 - 2.0
    var pitch: Double // 0.5 - 2.0
    var volume: Double // 0.0 - 1.0
    var quality: TTSQuality
    var enableSSML: Bool
    
    enum TTSQuality: String, CaseIterable, Codable {
        case standard = "standard"
        case high = "high"
        case premium = "premium"
        
        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .high: return "High"
            case .premium: return "Premium"
            }
        }
        
        var sampleRate: Int {
            switch self {
            case .standard: return 22050
            case .high: return 44100
            case .premium: return 48000
            }
        }
    }
    
    static let `default` = TTSSettings(
        voice: TTSVoice.default,
        speed: 1.0,
        pitch: 1.0,
        volume: 1.0,
        quality: .high,
        enableSSML: false
    )
}

struct TTSVoice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
    let gender: VoiceGender
    let isNeural: Bool
    let sampleRate: Int
    
    enum VoiceGender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
        case neutral = "neutral"
    }
    
    static let `default` = TTSVoice(
        id: "en-us-alloy",
        name: "Alloy",
        language: "en-US",
        gender: .neutral,
        isNeural: true,
        sampleRate: 44100
    )
}
```

### ConversionProgress
```swift
class ConversionProgress: ObservableObject {
    @Published var isConverting: Bool = false
    @Published var currentChapter: Int = 0
    @Published var totalChapters: Int = 0
    @Published var progress: Double = 0.0
    @Published var currentOperation: String = ""
    @Published var estimatedTimeRemaining: TimeInterval?
    @Published var error: ConversionError?
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var currentChapterTitle: String {
        guard currentChapter > 0 && currentChapter <= totalChapters else {
            return "Processing..."
        }
        return "Chapter \(currentChapter) of \(totalChapters)"
    }
}

enum ConversionError: LocalizedError, Identifiable {
    case invalidEPUBFile
    case drmProtected
    case parsingFailed(String)
    case ttsServiceUnavailable
    case audioGenerationFailed(String)
    case fileSystemError(String)
    case normalizationFailed(String)
    
    var id: String {
        switch self {
        case .invalidEPUBFile: return "invalid_epub"
        case .drmProtected: return "drm_protected"
        case .parsingFailed: return "parsing_failed"
        case .ttsServiceUnavailable: return "tts_unavailable"
        case .audioGenerationFailed: return "audio_generation_failed"
        case .fileSystemError: return "file_system_error"
        case .normalizationFailed: return "normalization_failed"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidEPUBFile:
            return "The selected file is not a valid EPUB file."
        case .drmProtected:
            return "This EPUB file is DRM-protected and cannot be processed."
        case .parsingFailed(let message):
            return "Failed to parse EPUB file: \(message)"
        case .ttsServiceUnavailable:
            return "Text-to-speech service is currently unavailable."
        case .audioGenerationFailed(let message):
            return "Failed to generate audio: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .normalizationFailed(let message):
            return "Text normalization failed: \(message)"
        }
    }
}
```

## Usage Examples

### Creating a Book
```swift
let book = EPUBBook(
    id: UUID(),
    title: "Sample Book",
    author: "Author Name",
    publisher: "Publisher",
    publicationDate: Date(),
    language: "en",
    description: "Book description",
    coverImage: nil,
    chapters: [],
    fileURL: URL(fileURLWithPath: "/path/to/book.epub"),
    isDRMProtected: false,
    epubVersion: .epub3,
    totalWordCount: 50000
)
```

### Configuring Settings
```swift
var settings = NormalizationSettings.default
settings.newlineHandling = .convertToSpaces
settings.customReplacements.append(
    TextReplacement(
        pattern: "Mr\\.", 
        replacement: "Mister", 
        isRegex: true
    )
)

var ttsSettings = TTSSettings.default
ttsSettings.voice = TTSVoice(
    id: "en-us-nova",
    name: "Nova",
    language: "en-US",
    gender: .female,
    isNeural: true,
    sampleRate: 44100
)
```