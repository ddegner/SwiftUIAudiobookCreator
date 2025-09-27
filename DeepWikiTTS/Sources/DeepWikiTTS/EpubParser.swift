import Foundation
import ZIPFoundation
import SwiftSoup

public enum EpubParserError: Error {
    case invalidArchive
    case containerNotFound
    case opfNotFound
    case spineMissing
}

public final class EpubBookParser: @unchecked Sendable {
    private let url: URL
    private let config: EpubParsingConfig

    public init(epubURL: URL, config: EpubParsingConfig) {
        self.url = epubURL
        self.config = config
    }

    public func getBookTitle() -> String {
        (try? parseOPF().metadata.title) ?? "Untitled"
    }

    public func getBookAuthor() -> String {
        (try? parseOPF().metadata.author) ?? "Unknown"
    }

    public func getChapters() throws -> [Chapter] {
        let opf = try parseOPF()
        let archive = try openArchive()
        var chapters: [Chapter] = []
        for spineId in opf.spineItemRefs {
            guard let href = opf.manifest[spineId] else { continue }
            guard let entry = archive[hrefFullPath(opf: opf, href: href)] else { continue }
            var data = Data()
            _ = try archive.extract(entry) { chunkData in
                data.append(chunkData)
            }
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { continue }

            let cleaned = try processHTML(html)
            let title = extractTitle(fromHTML: html, fallbackText: cleaned)
            let chapter = Chapter(title: title, text: cleaned)
            chapters.append(chapter)
        }
        return chapters
    }

    // MARK: - Internals

    private func openArchive() throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else { throw EpubParserError.invalidArchive }
        return archive
    }

    private struct OPF: Sendable {
        struct Metadata: Sendable { let title: String; let author: String }
        let rootPath: String
        let packagePath: String
        let metadata: Metadata
        let manifest: [String: String] // id -> href
        let spineItemRefs: [String] // idrefs in reading order
    }

    private func parseOPF() throws -> OPF {
        let archive = try openArchive()
        // 1) Locate container.xml at META-INF/container.xml
        guard let containerEntry = archive["META-INF/container.xml"] else { throw EpubParserError.containerNotFound }
        var containerData = Data()
        _ = try archive.extract(containerEntry) { containerData.append($0) }
        guard let containerXML = String(data: containerData, encoding: .utf8) else { throw EpubParserError.containerNotFound }
        let containerDoc = try SwiftSoup.parse(containerXML)
        let rootfile = try containerDoc.select("rootfile").first()
        let fullPath = try rootfile?.attr("full-path") ?? ""
        guard !fullPath.isEmpty else { throw EpubParserError.opfNotFound }

        let rootDir = (fullPath as NSString).deletingLastPathComponent

        guard let opfEntry = archive[fullPath] else { throw EpubParserError.opfNotFound }
        var opfData = Data()
        _ = try archive.extract(opfEntry) { opfData.append($0) }
        guard let opfXML = String(data: opfData, encoding: .utf8) else { throw EpubParserError.opfNotFound }
        let opfDoc = try SwiftSoup.parse(opfXML)

        // Metadata
        let title = try opfDoc.select("metadata > title, metadata > dc|title, dc\:title").first()?.text() ?? ""
        let creator = try opfDoc.select("metadata > creator, metadata > dc|creator, dc\:creator").first()?.text() ?? ""

        // Manifest id -> href
        var manifest: [String: String] = [:]
        for item in try opfDoc.select("manifest > item").array() {
            let id = try item.attr("id")
            let href = try item.attr("href")
            manifest[id] = href
        }

        // Spine order idrefs
        var spine: [String] = []
        for itemref in try opfDoc.select("spine > itemref").array() {
            let idref = try itemref.attr("idref")
            spine.append(idref)
        }
        guard !spine.isEmpty else { throw EpubParserError.spineMissing }

        return OPF(
            rootPath: rootDir,
            packagePath: fullPath,
            metadata: .init(title: title, author: creator),
            manifest: manifest,
            spineItemRefs: spine
        )
    }

    private func hrefFullPath(opf: OPF, href: String) -> String {
        if opf.rootPath.isEmpty { return href }
        return (opf.rootPath as NSString).appendingPathComponent(href)
    }

    private func processHTML(_ html: String) throws -> String {
        let doc = try SwiftSoup.parse(html)
        // remove scripts/styles
        try doc.select("script, style").remove()
        let text = try doc.text("\n")
        var cleaned = text
        if config.applyFootnoteCleanup {
            cleaned = TextCleanup.cleanupFootnotes(cleaned)
        }
        cleaned = TextCleanup.applyNewlineMode(cleaned, mode: config.newlineMode, breakString: config.breakString)
        cleaned = try TextCleanup.applyRules(from: config.searchReplaceRulesURL, to: cleaned)
        return cleaned
    }

    private func extractTitle(fromHTML html: String, fallbackText: String) -> String {
        let maxLen = 60
        func firstFew(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "<blank>" }
            let prefix = String(trimmed.prefix(maxLen))
            return TextCleanup.sanitizeTitle(prefix)
        }

        switch config.titleMode {
        case .firstFew:
            return firstFew(fallbackText)
        case .tagText:
            if let title = try? SwiftSoup.parse(html).select("title,h1,h2,h3").first()?.text(), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TextCleanup.sanitizeTitle(title)
            }
            return "<blank>"
        case .auto:
            if let explicit = try? SwiftSoup.parse(html).select("title").first()?.text(), !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TextCleanup.sanitizeTitle(explicit)
            }
            if let h1 = try? SwiftSoup.parse(html).select("h1").first()?.text(), !h1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TextCleanup.sanitizeTitle(h1)
            }
            if let h2 = try? SwiftSoup.parse(html).select("h2").first()?.text(), !h2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TextCleanup.sanitizeTitle(h2)
            }
            if let h3 = try? SwiftSoup.parse(html).select("h3").first()?.text(), !h3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TextCleanup.sanitizeTitle(h3)
            }
            // if empty or numeric, fallback to first few chars
            let candidate = firstFew(fallbackText)
            let numeric = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: candidate.replacingOccurrences(of: " ", with: "")))
            return numeric ? firstFew(fallbackText) : candidate
        }
    }
}

