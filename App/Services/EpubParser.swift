import Foundation
import ZIPFoundation
import SWXMLHash

final class EpubParser: EPUBParsing {
  struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: String?
  }

  func parse(epubURL: URL) throws -> Book {
    let tempDir = try createTempWorkDir()
    let unzipRoot = tempDir.appendingPathComponent("unzipped")
    try FileManager.default.createDirectory(at: unzipRoot, withIntermediateDirectories: true)
    try unzip(epubURL: epubURL, to: unzipRoot)

    let containerXML = unzipRoot.appendingPathComponent("META-INF/container.xml")
    guard FileManager.default.fileExists(atPath: containerXML.path) else {
      throw makeError("Missing container.xml")
    }
    let container = try XMLHash.parse(Data(contentsOf: containerXML))
    guard let opfPath: String = try container["container"]["rootfiles"]["rootfile"].element?.attribute(by: "full-path")?.text else {
      throw makeError("Invalid container.xml")
    }

    let opfURL = unzipRoot.appendingPathComponent(opfPath)
    let opfDir = opfURL.deletingLastPathComponent()
    let opfDoc = try XMLHash.parse(Data(contentsOf: opfURL))

    let metadata = opfDoc["package"]["metadata"]
    let title = metadata["title"].element?.text ?? epubURL.deletingPathExtension().lastPathComponent
    let author = metadata["creator"].element?.text ?? "Unknown"

    var manifest: [String: ManifestItem] = [:]
    for item in opfDoc["package"]["manifest"]["item"].all {
      let id = item.element?.attribute(by: "id")?.text ?? ""
      let href = item.element?.attribute(by: "href")?.text ?? ""
      let mediaType = item.element?.attribute(by: "media-type")?.text ?? ""
      let properties = item.element?.attribute(by: "properties")?.text
      if !id.isEmpty { manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties) }
    }

    var coverImage: NSImage? = nil
    // cover via <meta name="cover" content="id">
    if let coverId = metadata["meta"].all.first(where: { $0.element?.attribute(by: "name")?.text == "cover" })?.element?.attribute(by: "content")?.text,
       let coverItem = manifest[coverId] {
      let coverURL = opfDir.appendingPathComponent(coverItem.href)
      if let data = try? Data(contentsOf: coverURL), let img = NSImage(data: data) { coverImage = img }
    }

    var chapters: [Chapter] = []
    var titleMap: [String: String] = [:]

    // Titles from EPUB3 nav.xhtml if present
    if let navItem = manifest.values.first(where: { $0.properties?.contains("nav") == true }) {
      let navURL = opfDir.appendingPathComponent(navItem.href)
      if FileManager.default.fileExists(atPath: navURL.path),
         let navDoc = try? XMLHash.parse(Data(contentsOf: navURL)) {
        for li in navDoc["html"]["body"]["nav"]["ol"]["li"].all {
          if let href = li["a"].element?.attribute(by: "href")?.text,
             let text = li["a"].element?.text {
            let base = href.components(separatedBy: "#").first ?? href
            titleMap[base] = text.trimmingCharacters(in: .whitespacesAndNewlines)
          }
        }
      }
    } else if let ncxItem = manifest.values.first(where: { $0.mediaType.contains("ncx") }) {
      let ncxURL = opfDir.appendingPathComponent(ncxItem.href)
      if FileManager.default.fileExists(atPath: ncxURL.path),
         let ncx = try? XMLHash.parse(Data(contentsOf: ncxURL)) {
        for point in ncx["ncx"]["navMap"]["navPoint"].all {
          if let src = point["content"].element?.attribute(by: "src")?.text,
             let text = point["navLabel"]["text"].element?.text {
            let base = src.components(separatedBy: "#").first ?? src
            titleMap[base] = text.trimmingCharacters(in: .whitespacesAndNewlines)
          }
        }
      }
    }

    let spineItems = opfDoc["package"]["spine"]["itemref"].all
    for (idx, itemref) in spineItems.enumerated() {
      guard let idref = itemref.element?.attribute(by: "idref")?.text,
            let item = manifest[idref] else { continue }
      // Only include html/xhtml
      if !item.mediaType.contains("html") { continue }
      let resolved = opfDir.appendingPathComponent(item.href)
      var titleGuess = titleMap[item.href]
      if titleGuess == nil {
        titleGuess = resolved.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
      }
      chapters.append(Chapter(index: idx, title: titleGuess ?? "Chapter \(idx+1)", htmlURL: resolved))
    }

    return Book(title: title, author: author, cover: coverImage, chapters: chapters)
  }

  private func unzip(epubURL: URL, to destination: URL) throws {
    guard let archive = Archive(url: epubURL, accessMode: .read) else {
      throw makeError("Unable to read EPUB archive")
    }
    for entry in archive { _ = try archive.extract(entry, to: destination.appendingPathComponent(entry.path)) }
  }

  private func createTempWorkDir() throws -> URL {
    let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("EpubToAudiobook-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
  }

  private func makeError(_ message: String) -> NSError {
    NSError(domain: "EpubParser", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
