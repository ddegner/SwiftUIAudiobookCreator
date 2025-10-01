# Service Protocols

## Protocol-Oriented Architecture

The app uses protocol-oriented design to ensure testability, modularity, and flexibility. Each service is defined by a protocol that specifies the interface, allowing for easy mocking and testing.

## Core Service Protocols

### EPUPParserServiceProtocol
```swift
protocol EPUPParserServiceProtocol {
    func parseEPUB(from url: URL) async throws -> EPUBBook
    func validateEPUB(_ url: URL) async throws -> Bool
    func detectDRM(_ url: URL) async throws -> Bool
    func extractMetadata(from url: URL) async throws -> EPUBMetadata
    func extractChapters(from url: URL) async throws -> [EPUBChapter]
}

struct EPUBMetadata {
    let title: String
    let author: String
    let publisher: String?
    let publicationDate: Date?
    let language: String?
    let description: String?
    let coverImage: Data?
    let epubVersion: EPUBBook.EPUBVersion
}
```

### TextNormalizationServiceProtocol
```swift
protocol TextNormalizationServiceProtocol {
    func normalizeText(_ text: String, with settings: NormalizationSettings) async throws -> String
    func detectFootnotes(in text: String) async -> [FootnoteRange]
    func removeFootnotes(from text: String, patterns: [String]) async throws -> String
    func applyCustomReplacements(to text: String, replacements: [TextReplacement]) async throws -> String
    func normalizeNewlines(in text: String, handling: NormalizationSettings.NewlineHandling) async throws -> String
    func extractChapterTitle(from text: String) async -> String?
}

struct FootnoteRange {
    let range: NSRange
    let text: String
    let pattern: String
}
```

### TTSServiceProtocol
```swift
protocol TTSServiceProtocol {
    func synthesizeText(_ text: String, with settings: TTSSettings) async throws -> Data
    func getAvailableVoices() async throws -> [TTSVoice]
    func validateVoice(_ voice: TTSVoice) async throws -> Bool
    func estimateDuration(for text: String, voice: TTSVoice) async throws -> TimeInterval
    func isServiceAvailable() async -> Bool
}
```

### AudioExportServiceProtocol
```swift
protocol AudioExportServiceProtocol {
    func exportAudio(_ audioData: Data, to url: URL, format: AudioFormat) async throws
    func createM4AFile(from audioData: Data, metadata: AudioMetadata) async throws -> URL
    func combineAudioFiles(_ urls: [URL], outputURL: URL) async throws
    func validateAudioFormat(_ data: Data) async throws -> Bool
}

struct AudioFormat {
    let sampleRate: Int
    let bitRate: Int
    let channels: Int
    let format: AudioFileFormat
    
    enum AudioFileFormat: String, CaseIterable {
        case m4a = "m4a"
        case mp3 = "mp3"
        case wav = "wav"
        
        var fileExtension: String {
            return self.rawValue
        }
        
        var mimeType: String {
            switch self {
            case .m4a: return "audio/mp4"
            case .mp3: return "audio/mpeg"
            case .wav: return "audio/wav"
            }
        }
    }
}

struct AudioMetadata {
    let title: String
    let artist: String
    let album: String?
    let trackNumber: Int?
    let totalTracks: Int?
    let duration: TimeInterval?
    let genre: String?
}
```

## Protocol Implementations

### Service Container Protocol
```swift
protocol ServiceContainerProtocol {
    var epubParser: EPUPParserServiceProtocol { get }
    var textNormalizer: TextNormalizationServiceProtocol { get }
    var ttsService: TTSServiceProtocol { get }
    var audioExporter: AudioExportServiceProtocol { get }
}

// Default implementation
class ServiceContainer: ServiceContainerProtocol {
    lazy var epubParser: EPUPParserServiceProtocol = EPUPParserService()
    lazy var textNormalizer: TextNormalizationServiceProtocol = TextNormalizationService()
    lazy var ttsService: TTSServiceProtocol = KokoroTTSService()
    lazy var audioExporter: AudioExportServiceProtocol = AudioExportService()
}
```

## Dependency Injection

### Service Locator Pattern
```swift
class ServiceLocator {
    static let shared = ServiceLocator()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
}
```

### Environment-Based Service Registration
```swift
extension ServiceLocator {
    func registerDefaultServices() {
        register(EPUPParserService() as EPUPParserServiceProtocol, for: EPUPParserServiceProtocol.self)
        register(TextNormalizationService() as TextNormalizationServiceProtocol, for: TextNormalizationServiceProtocol.self)
        register(KokoroTTSService() as TTSServiceProtocol, for: TTSServiceProtocol.self)
        register(AudioExportService() as AudioExportServiceProtocol, for: AudioExportServiceProtocol.self)
    }
    
    func registerTestServices() {
        register(MockEPUPParserService() as EPUPParserServiceProtocol, for: EPUPParserServiceProtocol.self)
        register(MockTextNormalizationService() as TextNormalizationServiceProtocol, for: TextNormalizationServiceProtocol.self)
        register(MockTTSService() as TTSServiceProtocol, for: TTSServiceProtocol.self)
        register(MockAudioExportService() as AudioExportServiceProtocol, for: AudioExportServiceProtocol.self)
    }
}
```

## Usage in SwiftUI

### Environment-Based Service Injection
```swift
struct ContentView: View {
    @StateObject private var conversionProgress = ConversionProgress()
    @Environment(\.serviceLocator) private var serviceLocator
    
    var body: some View {
        // UI implementation
    }
}

// Environment key for service locator
struct ServiceLocatorKey: EnvironmentKey {
    static let defaultValue: ServiceLocator = ServiceLocator.shared
}

extension EnvironmentValues {
    var serviceLocator: ServiceLocator {
        get { self[ServiceLocatorKey.self] }
        set { self[ServiceLocatorKey.self] = newValue }
    }
}
```

## Benefits of Protocol-Oriented Design

1. **Testability**: Easy to create mock implementations for testing
2. **Flexibility**: Can swap implementations without changing client code
3. **Modularity**: Each service has a clear, focused responsibility
4. **Dependency Injection**: Services can be easily injected and configured
5. **Type Safety**: Protocols ensure compile-time contract compliance
6. **Extensibility**: New implementations can be added without modifying existing code

## Testing with Protocols

```swift
class MockEPUPParserService: EPUPParserServiceProtocol {
    var shouldThrowError = false
    var mockBook: EPUBBook?
    
    func parseEPUB(from url: URL) async throws -> EPUBBook {
        if shouldThrowError {
            throw ConversionError.parsingFailed("Mock error")
        }
        return mockBook ?? EPUBBook.sample
    }
    
    // Implement other protocol methods...
}

// Usage in tests
func testConversionFlow() async {
    let mockParser = MockEPUPParserService()
    let mockBook = EPUBBook.sample
    mockParser.mockBook = mockBook
    
    ServiceLocator.shared.register(mockParser, for: EPUPParserServiceProtocol.self)
    
    // Test conversion flow with mock
}
```