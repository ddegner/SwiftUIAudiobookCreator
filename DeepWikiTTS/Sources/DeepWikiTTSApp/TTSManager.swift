import Foundation
import DeepWikiTTS

final class TTSManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentIndex: Int = 0
    @Published var progress: Double = 0
    @Published var error: String?

    private var writer = TTSWriter()

    func generate(chapters: [Chapter], voice: TTSVoiceConfig, outDir: URL, metadata: BookMetadata, startIndex: Int = 0, onChapterDone: @escaping (URL) -> Void) {
        guard !chapters.isEmpty else { return }
        isRunning = true
        currentIndex = startIndex
        error = nil

        func writeNext() {
            if currentIndex >= chapters.count { isRunning = false; return }
            let ch = chapters[currentIndex]
            let filename = String(format: "%03d_%@.m4a", currentIndex + 1, ch.title)
            let rawOut = outDir.appendingPathComponent(filename)
            writer.writeChapter(chapter: ch, voiceConfig: voice, outputURL: rawOut) { p in
                DispatchQueue.main.async { self.progress = p }
            } completion: { result in
                switch result {
                case .success(let url):
                    let tagged = outDir.appendingPathComponent(String(format: "%03d_%@_tagged.m4a", self.currentIndex + 1, ch.title))
                    MetadataExporter.tagM4A(inputURL: url, outputURL: tagged, tagging: .init(book: metadata, chapterIndex: self.currentIndex + 1)) { tagRes in
                        DispatchQueue.main.async {
                            switch tagRes {
                            case .success(let final): onChapterDone(final)
                            case .failure(let e): self.error = String(describing: e)
                            }
                            self.currentIndex += 1
                            writeNext()
                        }
                    }
                case .failure(let e):
                    DispatchQueue.main.async { self.error = String(describing: e); self.currentIndex += 1; writeNext() }
                }
            }
        }
        writeNext()
    }

    func cancel() {
        writer.cancel()
        isRunning = false
    }
}

