import Foundation
#if canImport(EPUBKit)
import EPUBKit
#endif

enum EPUBServiceError: Error, LocalizedError {
    case openFailed
    case chapterDataNotFound(String)

    var errorDescription: String? {
        switch self {
        case .openFailed: return "Failed to open EPUB."
        case .chapterDataNotFound(let href): return "Chapter data not found for href: \(href)"
        }
    }
}

struct ChapterRef { let title: String; let href: String }

#if canImport(EPUBKit)
// Real EPUBService backed by EPUBKit
struct EPUBService {
    // Load basic metadata and ordered chapter references using common EPUBKit properties
    func loadEPUB(at url: URL) throws -> (title: String, author: String?, chapters: [ChapterRef]) {
        guard let doc = EPUBDocument(url: url) else { throw EPUBServiceError.openFailed }
        return try loadEPUB(from: doc)
    }

    // Load metadata and chapters from an existing EPUBDocument (more efficient for multiple chapters)
    func loadEPUB(from document: EPUBDocument) throws -> (title: String, author: String?, chapters: [ChapterRef]) {
        let title = document.title ?? "Untitled"
        let author = document.author
        var chapters: [ChapterRef] = []
        for spine in document.spine.items {
            if let item = document.manifest.items[spine.idref] {
                let chapterTitle = URL(fileURLWithPath: item.path).lastPathComponent
                chapters.append(ChapterRef(title: chapterTitle, href: item.path))
            }
        }
        return (title, author, chapters)
    }

    // Convert XHTML/HTML data to plain text suitable for TTS
    func htmlToPlainText(_ htmlData: Data) -> String {
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attr = try? NSAttributedString(data: htmlData, options: opts, documentAttributes: nil) {
            return attr.string
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    // Resolve chapter href to raw data from the EPUB container
    func dataForChapter(epubURL: URL, href: String) throws -> Data {
        guard let doc = EPUBDocument(url: epubURL) else {
            throw EPUBServiceError.chapterDataNotFound(href)
        }

        // Find the manifest item for this href
        guard let item = doc.manifest.items.first(where: { $0.value.path == href })?.value else {
            throw EPUBServiceError.chapterDataNotFound(href)
        }

        // Construct the full URL for the resource within the EPUB
        let resourceURL = doc.contentDirectory.appendingPathComponent(item.path)
        return try Data(contentsOf: resourceURL)
    }

    // Efficiently load all chapters using a single EPUBDocument instance
    func loadAllChapters(epubURL: URL) throws -> (title: String, author: String?, chapters: [Chapter]) {
        guard let document = EPUBDocument(url: epubURL) else {
            throw EPUBServiceError.openFailed
        }

        let (title, author, chapterRefs) = try loadEPUB(from: document)

        var chapters: [Chapter] = []
        for ref in chapterRefs {
            let data = try dataForChapter(from: document, href: ref.href)
            let plain = htmlToPlainText(data)
            chapters.append(Chapter(title: ref.title, htmlContent: plain))
        }

        return (title, author, chapters)
    }

    // Get chapter data using an existing document (more efficient)
    private func dataForChapter(from document: EPUBDocument, href: String) throws -> Data {
        // Find the manifest item for this href
        guard let item = document.manifest.items.first(where: { $0.value.path == href })?.value else {
            throw EPUBServiceError.chapterDataNotFound(href)
        }

        // Construct the full URL for the resource within the EPUB
        let resourceURL = document.contentDirectory.appendingPathComponent(item.path)
        return try Data(contentsOf: resourceURL)
    }

    // Attempt to extract cover image data from the EPUB
    func extractCoverImageData(epubURL: URL) -> Data? {
        guard let document = EPUBDocument(url: epubURL) else {
            return nil
        }

        // 1) Prefer items explicitly marked as cover-image
        if let item = document.manifest.items.first(where: { ($0.value.property ?? "").contains("cover-image") })?.value {
            let url = document.contentDirectory.appendingPathComponent(item.path)
            return try? Data(contentsOf: url)
        }

        // 2) Heuristic: find first image item whose id or path contains "cover"
        if let item = document.manifest.items.first(where: {
            ($0.value.id.lowercased().contains("cover") || $0.value.path.lowercased().contains("cover")) &&
            $0.value.mediaType.rawValue.hasPrefix("image/")
        })?.value {
            let url = document.contentDirectory.appendingPathComponent(item.path)
            return try? Data(contentsOf: url)
        }

        // 3) Fallback: first image in manifest
        if let item = document.manifest.items.first(where: { $0.value.mediaType.rawValue.hasPrefix("image/") })?.value {
            let url = document.contentDirectory.appendingPathComponent(item.path)
            return try? Data(contentsOf: url)
        }

        return nil
    }
}
#else
// Fallback EPUBService that allows the app to build without EPUBKit.
struct EPUBService {
    func loadEPUB(at url: URL) throws -> (title: String, author: String?, chapters: [ChapterRef]) {
        throw EPUBServiceError.openFailed
    }

    func htmlToPlainText(_ htmlData: Data) -> String { "" }

    func dataForChapter(epubURL: URL, href: String) throws -> Data {
        throw EPUBServiceError.chapterDataNotFound(href)
    }

    func extractCoverImageData(epubURL: URL) -> Data? { nil }
}
#endif


