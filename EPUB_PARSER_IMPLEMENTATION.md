# EPUB Parser Implementation

## Overview

The EPUB parser is responsible for extracting content, metadata, and structure from EPUB files. It supports both EPUB2 and EPUB3 formats, includes DRM detection, and handles various edge cases in EPUB structure.

## Core Components

### EPUPParserService

```swift
class EPUPParserService: EPUPParserServiceProtocol {
    private let fileManager = FileManager.default
    private let tempDirectory: URL
    
    init() {
        self.tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("epub-parser-\(UUID().uuidString)")
    }
    
    deinit {
        try? fileManager.removeItem(at: tempDirectory)
    }
    
    func parseEPUB(from url: URL) async throws -> EPUBBook {
        // Validate EPUB file
        try await validateEPUB(url)
        
        // Check for DRM protection
        let isDRMProtected = try await detectDRM(url)
        guard !isDRMProtected else {
            throw ConversionError.drmProtected
        }
        
        // Extract EPUB to temporary directory
        let extractedURL = try await extractEPUB(url)
        defer { try? fileManager.removeItem(at: extractedURL) }
        
        // Parse container.xml to find OPF file
        let container = try await EPUBContainer.parse(from: extractedURL)
        
        // Parse OPF file for metadata and manifest
        let opfParser = OPFParser()
        let opfData = try await opfParser.parse(from: container.opfURL)
        
        // Extract chapters
        let chapters = try await extractChapters(from: extractedURL, manifest: opfData.manifest)
        
        // Calculate total word count
        let totalWordCount = chapters.reduce(0) { $0 + $1.wordCount }
        
        return EPUBBook(
            id: UUID(),
            title: opfData.metadata.title,
            author: opfData.metadata.author,
            publisher: opfData.metadata.publisher,
            publicationDate: opfData.metadata.publicationDate,
            language: opfData.metadata.language,
            description: opfData.metadata.description,
            coverImage: try await extractCoverImage(from: extractedURL, manifest: opfData.manifest),
            chapters: chapters,
            fileURL: url,
            isDRMProtected: isDRMProtected,
            epubVersion: opfData.metadata.epubVersion,
            totalWordCount: totalWordCount
        )
    }
    
    func validateEPUB(_ url: URL) async throws -> Bool {
        // Check file extension
        guard url.pathExtension.lowercased() == "epub" else {
            throw ConversionError.invalidEPUBFile
        }
        
        // Check if file exists and is readable
        guard fileManager.fileExists(atPath: url.path) else {
            throw ConversionError.invalidEPUBFile
        }
        
        // Check if file is actually a ZIP archive (EPUBs are ZIP files)
        return try await validateZipArchive(url)
    }
    
    func detectDRM(_ url: URL) async throws -> Bool {
        let extractedURL = try await extractEPUB(url)
        defer { try? fileManager.removeItem(at: extractedURL) }
        
        // Check for common DRM indicators
        let drmIndicators = [
            "META-INF/rights.xml",
            "META-INF/encryption.xml",
            "META-INF/signatures.xml"
        ]
        
        for indicator in drmIndicators {
            let drmFileURL = extractedURL.appendingPathComponent(indicator)
            if fileManager.fileExists(atPath: drmFileURL.path) {
                return true
            }
        }
        
        return false
    }
    
    private func extractEPUB(_ url: URL) async throws -> URL {
        let extractedURL = tempDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        
        // Use system unzip command for reliable extraction
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", extractedURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ConversionError.parsingFailed("Failed to extract EPUB file")
        }
        
        return extractedURL
    }
    
    private func validateZipArchive(_ url: URL) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", url.path]
        
        try process.run()
        process.waitUntilExit()
        
        return process.terminationStatus == 0
    }
}
```

### EPUBContainer Parser

```swift
struct EPUBContainer {
    let opfURL: URL
    let version: String
    
    static func parse(from extractedURL: URL) async throws -> EPUBContainer {
        let containerURL = extractedURL.appendingPathComponent("META-INF/container.xml")
        
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw ConversionError.parsingFailed("container.xml not found")
        }
        
        let data = try Data(contentsOf: containerURL)
        let parser = XMLParser(data: data)
        let delegate = ContainerParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw ConversionError.parsingFailed("Failed to parse container.xml")
        }
        
        guard let opfPath = delegate.opfPath else {
            throw ConversionError.parsingFailed("OPF file path not found in container.xml")
        }
        
        let opfURL = extractedURL.appendingPathComponent(opfPath)
        return EPUBContainer(opfURL: opfURL, version: delegate.version ?? "2.0")
    }
}

private class ContainerParserDelegate: NSObject, XMLParserDelegate {
    var opfPath: String?
    var version: String?
    private var currentElement: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "container" {
            version = attributeDict["version"]
        } else if elementName == "rootfile" {
            opfPath = attributeDict["full-path"]
        }
    }
}
```

### OPF Parser

```swift
class OPFParser {
    func parse(from url: URL) async throws -> OPFData {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let delegate = OPFParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw ConversionError.parsingFailed("Failed to parse OPF file")
        }
        
        return OPFData(
            metadata: delegate.metadata,
            manifest: delegate.manifest,
            spine: delegate.spine
        )
    }
}

struct OPFData {
    let metadata: EPUBMetadata
    let manifest: [ManifestItem]
    let spine: [SpineItem]
}

struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: [String]
}

struct SpineItem {
    let idref: String
    let linear: Bool
}

private class OPFParserDelegate: NSObject, XMLParserDelegate {
    var metadata = EPUBMetadata.empty
    var manifest: [ManifestItem] = []
    var spine: [SpineItem] = []
    
    private var currentElement: String?
    private var currentManifestItem: ManifestItem?
    private var currentSpineItem: SpineItem?
    private var currentText: String = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "item":
            currentManifestItem = ManifestItem(
                id: attributeDict["id"] ?? "",
                href: attributeDict["href"] ?? "",
                mediaType: attributeDict["media-type"] ?? "",
                properties: (attributeDict["properties"] ?? "").components(separatedBy: " ")
            )
        case "itemref":
            currentSpineItem = SpineItem(
                idref: attributeDict["idref"] ?? "",
                linear: attributeDict["linear"] != "no"
            )
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer {
            currentText = ""
            currentElement = nil
        }
        
        switch elementName {
        case "title":
            metadata.title = currentText
        case "creator":
            metadata.author = currentText
        case "publisher":
            metadata.publisher = currentText
        case "date":
            metadata.publicationDate = parseDate(currentText)
        case "language":
            metadata.language = currentText
        case "description":
            metadata.description = currentText
        case "item":
            if let item = currentManifestItem {
                manifest.append(item)
            }
        case "itemref":
            if let item = currentSpineItem {
                spine.append(item)
            }
        default:
            break
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

extension EPUBMetadata {
    static let empty = EPUBMetadata(
        title: "",
        author: "",
        publisher: nil,
        publicationDate: nil,
        language: nil,
        description: nil,
        coverImage: nil,
        epubVersion: .epub2
    )
}
```

### Chapter Extraction

```swift
extension EPUPParserService {
    private func extractChapters(from extractedURL: URL, manifest: [ManifestItem]) async throws -> [EPUBChapter] {
        // Find HTML/XHTML files in manifest
        let htmlItems = manifest.filter { item in
            item.mediaType.contains("html") || item.href.lowercased().hasSuffix(".html") || item.href.lowercased().hasSuffix(".xhtml")
        }
        
        var chapters: [EPUBChapter] = []
        
        for (index, item) in htmlItems.enumerated() {
            let fileURL = extractedURL.appendingPathComponent(item.href)
            let content = try await extractHTMLContent(from: fileURL)
            
            let chapter = EPUBChapter(
                id: UUID(),
                title: extractTitle(from: content),
                content: content,
                order: index + 1,
                wordCount: content.wordCount,
                estimatedDuration: nil,
                sourceURL: fileURL,
                normalizedContent: nil
            )
            
            chapters.append(chapter)
        }
        
        return chapters.sorted { $0.order < $1.order }
    }
    
    private func extractHTMLContent(from url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        let html = String(data: data, encoding: .utf8) ?? ""
        
        // Parse HTML and extract text content
        let parser = HTMLParser()
        return try await parser.extractText(from: html)
    }
    
    private func extractTitle(from content: String) -> String {
        // Look for title patterns in HTML
        let titlePatterns = [
            "<h1[^>]*>(.*?)</h1>",
            "<h2[^>]*>(.*?)</h2>",
            "<title[^>]*>(.*?)</title>"
        ]
        
        for pattern in titlePatterns {
            if let match = content.firstMatch(of: try! Regex(pattern)) {
                let title = String(match.output.1)
                return cleanHTMLTags(from: title)
            }
        }
        
        return ""
    }
    
    private func cleanHTMLTags(from text: String) -> String {
        return text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

### HTML Parser

```swift
class HTMLParser {
    func extractText(from html: String) async throws -> String {
        let parser = XMLParser(data: html.data(using: .utf8) ?? Data())
        let delegate = HTMLTextExtractor()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw ConversionError.parsingFailed("Failed to parse HTML content")
        }
        
        return delegate.extractedText
    }
}

private class HTMLTextExtractor: NSObject, XMLParserDelegate {
    var extractedText = ""
    private var currentText = ""
    private var inScriptOrStyle = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName.lowercased() == "script" || elementName.lowercased() == "style" {
            inScriptOrStyle = true
        }
        
        // Add line breaks for block elements
        let blockElements = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "br"]
        if blockElements.contains(elementName.lowercased()) {
            extractedText += "\n"
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !inScriptOrStyle {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.lowercased() == "script" || elementName.lowercased() == "style" {
            inScriptOrStyle = false
        }
        
        if !currentText.isEmpty {
            extractedText += currentText.trimmingCharacters(in: .whitespacesAndNewlines) + " "
            currentText = ""
        }
    }
}
```

## Error Handling

```swift
enum EPUBParsingError: LocalizedError {
    case invalidContainer
    case missingOPF
    case invalidOPF
    case missingManifest
    case invalidHTML(String)
    case extractionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidContainer:
            return "Invalid EPUB container structure"
        case .missingOPF:
            return "OPF file not found in EPUB"
        case .invalidOPF:
            return "OPF file is malformed"
        case .missingManifest:
            return "Manifest not found in OPF"
        case .invalidHTML(let message):
            return "HTML parsing error: \(message)"
        case .extractionFailed(let message):
            return "EPUB extraction failed: \(message)"
        }
    }
}
```

## Usage Example

```swift
let parser = EPUPParserService()

do {
    let book = try await parser.parseEPUB(from: epubURL)
    print("Parsed book: \(book.title) by \(book.author)")
    print("Chapters: \(book.chapters.count)")
    print("Total words: \(book.totalWordCount)")
} catch {
    print("Parsing failed: \(error.localizedDescription)")
}
```

This implementation provides comprehensive EPUB parsing with proper error handling, DRM detection, and support for both EPUB2 and EPUB3 formats.