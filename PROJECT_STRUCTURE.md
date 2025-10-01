# Project Structure

```
EPUBAudiobookConverter/
├── EPUBAudiobookConverter.xcodeproj
├── EPUBAudiobookConverter/
│   ├── App/
│   │   ├── EPUBAudiobookConverterApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── EPUBBook.swift
│   │   ├── EPUBChapter.swift
│   │   ├── NormalizationSettings.swift
│   │   ├── TTSSettings.swift
│   │   └── ConversionProgress.swift
│   ├── Services/
│   │   ├── Protocols/
│   │   │   ├── EPUPParserServiceProtocol.swift
│   │   │   ├── TextNormalizationServiceProtocol.swift
│   │   │   ├── TTSServiceProtocol.swift
│   │   │   └── AudioExportServiceProtocol.swift
│   │   ├── EPUPParserService.swift
│   │   ├── TextNormalizationService.swift
│   │   ├── KokoroTTSService.swift
│   │   └── AudioExportService.swift
│   ├── Views/
│   │   ├── MainView.swift
│   │   ├── DropZoneView.swift
│   │   ├── SettingsView.swift
│   │   ├── ProgressView.swift
│   │   └── Components/
│   │       ├── NormalizationSettingsView.swift
│   │       ├── TTSSettingsView.swift
│   │       └── ConversionProgressView.swift
│   ├── Utilities/
│   │   ├── EPUBParser/
│   │   │   ├── EPUBContainer.swift
│   │   │   ├── OPFParser.swift
│   │   │   ├── NCXParser.swift
│   │   │   └── HTMLParser.swift
│   │   ├── TextProcessing/
│   │   │   ├── TextNormalizer.swift
│   │   │   ├── FootnoteDetector.swift
│   │   │   └── RegexProcessor.swift
│   │   └── Extensions/
│   │       ├── String+Extensions.swift
│   │       ├── URL+Extensions.swift
│   │       └── FileManager+Extensions.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       └── Localizable.strings
├── Tests/
│   ├── EPUBAudiobookConverterTests/
│   │   ├── Services/
│   │   │   ├── EPUPParserServiceTests.swift
│   │   │   ├── TextNormalizationServiceTests.swift
│   │   │   └── AudioExportServiceTests.swift
│   │   ├── Utilities/
│   │   │   ├── TextNormalizerTests.swift
│   │   │   ├── FootnoteDetectorTests.swift
│   │   │   └── RegexProcessorTests.swift
│   │   └── MockServices/
│   │       ├── MockEPUPParserService.swift
│   │       ├── MockTextNormalizationService.swift
│   │       └── MockTTSService.swift
│   └── EPUBAudiobookConverterUITests/
│       └── EPUBAudiobookConverterUITests.swift
└── Documentation/
    ├── ARCHITECTURE.md
    ├── API_DOCUMENTATION.md
    └── TESTING_GUIDE.md
```

## Directory Descriptions

### App/
Contains the main app entry point and root content view.

### Models/
Data models representing EPUB books, chapters, settings, and conversion progress.

### Services/
Protocol-oriented services for EPUB parsing, text normalization, TTS, and audio export.

### Views/
SwiftUI views organized by functionality with reusable components.

### Utilities/
Helper classes organized by domain (EPUB parsing, text processing, extensions).

### Tests/
Comprehensive test suite with unit tests for services and utilities, plus mock services for testing.

### Documentation/
Technical documentation for architecture, API, and testing guidelines.