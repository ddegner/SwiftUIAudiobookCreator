import Foundation

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let htmlContent: String
    // Start time of this chapter in seconds within the final audio (optional; filled during export)
    var startTime: TimeInterval? = nil
}

struct Book {
    let title: String
    let author: String?
    let chapters: [Chapter]
    // Raw cover image bytes extracted from the EPUB (if available)
    let coverImageData: Data?

    init(title: String, author: String?, chapters: [Chapter], coverImageData: Data? = nil) {
        self.title = title
        self.author = author
        self.chapters = chapters
        self.coverImageData = coverImageData
    }
}
