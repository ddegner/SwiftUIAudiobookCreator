import SwiftUI
import DeepWikiTTS

final class AppViewModel: ObservableObject {
    @Published var epubURL: URL?
    @Published var chapters: [Chapter] = []
    @Published var bookTitle: String = ""
    @Published var bookAuthor: String = ""
    @Published var parsingConfig = EpubParsingConfig()
    @Published var isParsing = false
    @Published var parseError: String?

    func openEPUB() {
        guard let url = FilePicker.pickEPUB() else { return }
        epubURL = url
        parse()
    }

    func parse() {
        guard let url = epubURL else { return }
        isParsing = true
        parseError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let parser = EpubBookParser(epubURL: url, config: self.parsingConfig)
            let title = parser.getBookTitle()
            let author = parser.getBookAuthor()
            do {
                let ch = try parser.getChapters()
                DispatchQueue.main.async {
                    self.bookTitle = title
                    self.bookAuthor = author
                    self.chapters = ch
                    self.isParsing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.parseError = String(describing: error)
                    self.isParsing = false
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @StateObject private var tts = TTSManager()
    @State private var voiceConfig = TTSVoiceConfig()
    @State private var outputDirectory: URL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!.appendingPathComponent("DeepWikiTTS")
    @State private var resumeIndex: Int = 0
    @State private var lastGeneratedURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Open EPUB…") { model.openEPUB() }
                if model.isParsing { ProgressView().controlSize(.small) }
                if let err = model.parseError { Text(err).foregroundColor(.red).lineLimit(2) }
            }
            .accessibilityLabel("Open EPUB")
            .keyboardShortcut("o", modifiers: [.command])

            if let url = model.epubURL {
                Text(url.lastPathComponent).font(.headline)
            }

            if !model.bookTitle.isEmpty || !model.bookAuthor.isEmpty {
                Text("\(model.bookTitle) — \(model.bookAuthor)")
            }

            List(model.chapters.prefix(50), id: \.title, selection: $resumeIndex) { ch in
                VStack(alignment: .leading) {
                    Text(ch.title).font(.headline)
                    Text(ch.text.prefix(200))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 240)

            Divider()
            OptionsView(config: $model.parsingConfig)
            VoiceControlsView(voiceConfig: $voiceConfig)

            HStack {
                Button("Choose Output Folder…") {
                    if let url = FolderPicker.pickFolder() { outputDirectory = url }
                }
                Text(outputDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Stepper("Start at chapter: \(resumeIndex + 1)", value: $resumeIndex, in: 0...max(model.chapters.count - 1, 0))
                    .frame(maxWidth: 280)
                Button(tts.isRunning ? "Cancel" : "Generate Audio") {
                    if tts.isRunning { tts.cancel() }
                    else {
                        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                        let meta = BookMetadata(title: model.bookTitle, author: model.bookAuthor)
                        tts.generate(chapters: model.chapters, voice: voiceConfig, outDir: outputDirectory, metadata: meta, startIndex: resumeIndex) { finalURL in
                            lastGeneratedURL = finalURL
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                if tts.isRunning { ProgressView(value: tts.progress) }
                Button("Generate Selected Chapter Only") {
                    guard resumeIndex < model.chapters.count else { return }
                    let ch = model.chapters[resumeIndex]
                    let meta = BookMetadata(title: model.bookTitle, author: model.bookAuthor)
                    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                    tts.generate(chapters: [ch], voice: voiceConfig, outDir: outputDirectory, metadata: meta, startIndex: 0) { finalURL in
                        lastGeneratedURL = finalURL
                    }
                }
            }

            if let url = lastGeneratedURL {
                Divider()
                PlaybackView(fileURL: url)
                BooksButton(fileURL: url)
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
    }
}

enum FilePicker {
    static func pickEPUB() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["epub"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = panel.runModal()
        return response == .OK ? panel.url : nil
    }

    static func pickRules() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = panel.runModal()
        return response == .OK ? panel.url : nil
    }
}

enum FolderPicker {
    static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        let resp = panel.runModal()
        return resp == .OK ? panel.url : nil
    }
}

