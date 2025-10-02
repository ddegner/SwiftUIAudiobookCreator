import SwiftUI
import Combine
import UniformTypeIdentifiers
@preconcurrency import AVFoundation
#if os(macOS)
import AppKit
#endif

// MARK: - Root ContentView

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var showImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("EPUB → Audiobook")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                // Book Preview
                CardContainer(title: "Book Preview") {
                    BookPreviewCardView(vm: vm, showImporter: $showImporter)
                }

                // Voice Settings
                CardContainer(title: "Voice Settings") {
                    VoiceSettingsCardView(vm: vm)
                }

                // Output Settings + Progress + Actions
                CardContainer(title: "Output Settings") {
                    OutputSettingsCardView(vm: vm)
                }

                if vm.showDebugLog {
                    CardContainer(title: "Debug Log") {
                        InlineLogView(logMessages: vm.logMessages)
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding()
            .overlay(alignment: .topTrailing) {
                Toggle("Debug Log", isOn: $vm.showDebugLog)
                    .toggleStyle(.switch)
                    .padding(.top, 6)
                    .padding(.trailing, 10)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.epub]) { result in
            switch result {
            case .success(let url):
                Task { await vm.parseEPUB(at: url) }
            case .failure(let error):
                vm.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Card Container & Field Row

struct CardContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(16)
        .background(
            Group {
                #if os(macOS)
                Color(NSColor.controlBackgroundColor)
                #else
                Color(UIColor.secondarySystemBackground)
                #endif
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

struct FieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var field: Content

    init(_ label: String, @ViewBuilder field: () -> Content) {
        self.label = label
        self.field = field()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 80, alignment: .trailing)
                .foregroundStyle(.secondary)
            field
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Book Preview Card

struct BookPreviewCardView: View {
    @ObservedObject var vm: AppViewModel
    @Binding var showImporter: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Display actual cover image if available, else fallback to placeholder
            Group {
                #if os(macOS)
                if let data = vm.book?.coverImageData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("Book cover")
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 80, height: 110)
                        .overlay {
                            if let title = vm.book?.title, let first = title.first {
                                Text(String(first))
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "book")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Book cover")
                }
                #else
                if let data = vm.book?.coverImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("Book cover")
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 80, height: 110)
                        .overlay {
                            if let title = vm.book?.title, let first = title.first {
                                Text(String(first))
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "book")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Book cover")
                }
                #endif
            }

            VStack(alignment: .leading, spacing: 8) {
                if let book = vm.book {
                    Text(book.title)
                        .font(.title2)
                        .lineLimit(2)
                        .accessibilityLabel("Title: \(book.title)")
                    if let author = book.author {
                        Text(author)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Author: \(author)")
                    }
                    if let url = vm.bookFileURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text("Import an EPUB to get started")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import EPUB", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)

                    if vm.book != nil {
                        Button(role: .destructive) {
                            vm.reset()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Voice Settings Card

struct VoiceSettingsCardView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldRow("Voice") {
                Picker("Voice", selection: $vm.voiceSelection) {
                    Text("af_heart").tag(VoiceSelection.afHeart)
                    Text("bm_george").tag(VoiceSelection.bmGeorge)
                }
                .labelsHidden()
                .frame(maxWidth: 240)
            }

            // Removed Speed control entirely

            HStack(spacing: 12) {
                Button {
                    Task { await vm.previewVoice() }
                } label: {
                    Label(vm.isPreviewing ? "Stop" : "Preview", systemImage: vm.isPreviewing ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.bordered)
                .disabled(vm.book == nil && vm.samplePreviewText.isEmpty)
            }
        }
    }
}

// MARK: - Output Settings Card

struct OutputSettingsCardView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldRow("Save to") {
                HStack(spacing: 8) {
                    Text(vm.audiobookSaveLocation?.path ?? "Not set")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(vm.audiobookSaveLocation?.path ?? "")
                    Button("Change") { vm.changeSaveLocation() }
                        .buttonStyle(.bordered)
                }
            }

            FieldRow("Format") {
                Picker("Format", selection: $vm.outputFormat) {
                    ForEach(OutputFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)
            }
            FieldRow("Parallelism") {
                let cpu = ProcessInfo.processInfo.processorCount
                let upper = max(1, min(cpu, 8))
                Stepper(value: $vm.maxParallelWorkers, in: 1...upper) {
                    Text("\(vm.maxParallelWorkers) \(vm.maxParallelWorkers == 1 ? "Worker" : "Workers")")
                }
                .frame(maxWidth: 240)
                .help("Limits how many chapters synthesize in parallel. Higher can be faster but uses more CPU and memory.")
            }

            // Primary CTA
            HStack(spacing: 12) {
                Button {
                    Task { await vm.convertToAudiobook() }
                } label: {
                    Text("Convert to Audiobook")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.book == nil || vm.modelURL == nil || vm.isSynthesizing)

                if vm.isSynthesizing {
                    Button(role: .cancel) { vm.cancelSynthesis() } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 2)

            if vm.isParsing {
                ProgressView("Parsing EPUB…")
            }

            if vm.isSynthesizing {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.currentStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: vm.progress, total: 1.0) {
                        Text("\(Int(vm.progress * 100))%")
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.top, 4)
            }

            if let url = vm.outputURL {
                #if os(macOS)
                HStack(spacing: 8) {
                    Button("Copy to Location…") { vm.saveAudiobookWithDialog() }
                        .buttonStyle(.bordered)
                    ShareLink(item: url) { Text("Share") }
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                    }
                }
                #else
                ShareLink(item: url) { Text("Export Audiobook") }
                #endif
            }

            if let sessionFolder = vm.currentSessionFolder {
                HStack(spacing: 8) {
                    Text("Chapter files available in:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sessionFolder.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #if os(macOS)
                    Button("Show Chapter Files") {
                        NSWorkspace.shared.selectFile(sessionFolder.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                    #endif
                    Button("Clean Up") {
                        vm.cleanupSessionFolder()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .padding(.top, 4)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Inline Log View

struct InlineLogView: View {
    let logMessages: [LogMessage]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(logMessages) { message in
                    HStack(alignment: .top, spacing: 8) {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Text(message.level.emoji)
                            .font(.caption)

                        Text(message.message)
                            .font(.caption)
                            .foregroundStyle(message.level.color)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(minHeight: 80, maxHeight: 240)
    }
}

// MARK: - Log Message Types (unchanged)

struct LogMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

enum LogLevel {
    case info
    case warning
    case error
    case success

    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }

    var color: Color {
        switch self {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}

// MARK: - Preview Audio Helper

final class AudioPreviewer {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var timePitch: AVAudioUnitTimePitch?

    func play(buffer: AVAudioPCMBuffer, speed: Double) {
        stop()
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let tp = AVAudioUnitTimePitch()
        tp.rate = Float(max(0.5, min(2.0, speed)) * 100) // AVAudioUnitTimePitch expects 0.5x-2x as 50-200

        engine.attach(player)
        engine.attach(tp)

        engine.connect(player, to: tp, format: buffer.format)
        engine.connect(tp, to: engine.mainMixerNode, format: buffer.format)

        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: [])
            player.play()
            self.engine = engine
            self.player = player
            self.timePitch = tp
        } catch {
            print("Preview engine failed: \(error)")
            stop()
        }
    }

    func stop() {
        player?.stop()
        engine?.stop()
        engine = nil
        player = nil
        timePitch = nil
    }
}

// MARK: - Concurrency Utilities
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) { self.value = value }

    func acquire() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    func release() {
        if let cont = waiters.first {
            waiters.removeFirst()
            cont.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - ViewModel & helpers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var book: Book?
    @Published var isParsing = false
    @Published var isSynthesizing = false
    @Published var progress: Double = 0
    @Published var currentStatus: String = ""
    @Published var outputURL: URL?
    @Published var errorMessage: String?
    @Published var logMessages: [LogMessage] = []

    @Published var voiceSelection: VoiceSelection = .afHeart
    // Removed voiceSpeed property as requested
    @Published var audiobookSaveLocation: URL?
    @Published var outputFormat: OutputFormat = .m4a
    @Published var showDebugLog: Bool = false
    @Published var isPreviewing: Bool = false
    @Published var maxParallelWorkers: Int = 2 {
        didSet {
            UserDefaults.standard.set(maxParallelWorkers, forKey: "maxParallelWorkers")
        }
    }

    @Published var bookFileURL: URL?
    @Published var currentSessionFolder: URL?

    let samplePreviewText: String = "This is a short preview of the selected voice."

    private var synthesisTask: Task<Void, Never>?
    private var isCancelled = false

    // Point this at your bundled model or downloaded location
    let modelURL: URL?

    private let epub = EPUBService()
    private let previewer = AudioPreviewer()

    init() {
        self.modelURL = Bundle.main.url(forResource: "kokoro-v1_0", withExtension: "safetensors")
        self.setupDefaultSaveLocation()

        // Load persisted parallelism setting (default to 2 if not set) and clamp to [1, CPU cores]
        let storedWorkers = (UserDefaults.standard.object(forKey: "maxParallelWorkers") as? Int) ?? 2
        let cpuCores = ProcessInfo.processInfo.processorCount
        self.maxParallelWorkers = max(1, min(cpuCores, storedWorkers))
    }

    private func setupDefaultSaveLocation() {
        // Default to Documents/Audiobooks folder
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audiobooksURL = documentsURL.appendingPathComponent("Audiobooks")

        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audiobooksURL, withIntermediateDirectories: true, attributes: nil)

        self.audiobookSaveLocation = audiobooksURL
    }

    private func log(_ message: String, level: LogLevel = .info) {
        let logMessage = LogMessage(timestamp: Date(), level: level, message: message)
        logMessages.append(logMessage)
        print("[\(level.emoji)] \(message)")
    }

    func changeSaveLocation() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Audiobook Folder"
        panel.message = "Choose where to save your audiobooks"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.audiobookSaveLocation = url
                self.log("Save location changed to: \(url.path)", level: .info)
            }
        }
        #endif
    }

    private func createConversionSessionFolder(uniqueID: String) throws -> URL {
        guard let saveLocation = audiobookSaveLocation else {
            throw NSError(domain: "Save", code: -1, userInfo: [NSLocalizedDescriptionKey: "No save location configured"])
        }

        // Create the save location directory if it doesn't exist
        try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true, attributes: nil)

        // Create a subfolder for this conversion session
        let sessionFolder = saveLocation.appendingPathComponent("conversion_\(uniqueID)")
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true, attributes: nil)
        
        log("Created conversion session folder: \(sessionFolder.path)", level: .info)
        return sessionFolder
    }

    private func moveAudiobookToSaveLocation(from tempURL: URL) throws -> URL {
        guard let saveLocation = audiobookSaveLocation else {
            throw NSError(domain: "Save", code: -1, userInfo: [NSLocalizedDescriptionKey: "No save location configured"])
        }

        // Create the save location directory if it doesn't exist
        try FileManager.default.createDirectory(at: saveLocation, withIntermediateDirectories: true, attributes: nil)

        // Generate a clean filename based on the book title
        let cleanTitle = book?.title.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-") ?? "audiobook"

        let fileExt = outputFormat.fileExtension
        let finalURL = saveLocation.appendingPathComponent("\(cleanTitle).\(fileExt)")

        // If file exists, append a number
        var finalPath = finalURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalPath.path) {
            let nameWithoutExt = cleanTitle
            finalPath = saveLocation.appendingPathComponent("\(nameWithoutExt) (\(counter)).\(fileExt)")
            counter += 1
        }

        // Move the file from temp to final location
        do {
            try FileManager.default.moveItem(at: tempURL, to: finalPath)
            log("Audiobook saved to: \(finalPath.path)", level: .success)
            return finalPath
        } catch {
            log("Failed to move audiobook from \(tempURL.path) to \(finalPath.path): \(error.localizedDescription)", level: .error)
            throw error
        }
    }

    // MARK: - Audio format helpers
    private final class ConverterInputState: @unchecked Sendable {
        var provided: Bool = false
        let buffer: AVAudioPCMBuffer
        init(buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    }

    nonisolated private func formatsMatch(_ a: AVAudioFormat, _ b: AVAudioFormat) -> Bool {
        return a.sampleRate == b.sampleRate &&
               a.channelCount == b.channelCount &&
               a.commonFormat == b.commonFormat &&
               a.isInterleaved == b.isInterleaved
    }

    nonisolated private func convert(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if formatsMatch(buffer.format, targetFormat) { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            throw NSError(domain: "Audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"]) }

        // Estimate a safe capacity for the output buffer
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio))
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            throw NSError(domain: "Audio", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate output buffer"]) }

        // Create a thread-safe input state
        let inputState = ConverterInputState(buffer: buffer)

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            // Use atomic operations to avoid concurrency issues
            if inputState.provided {
                outStatus.pointee = .endOfStream
                return nil
            } else {
                inputState.provided = true
                outStatus.pointee = .haveData
                return inputState.buffer
            }
        }

        var convError: NSError?
        let status = converter.convert(to: outBuffer, error: &convError, withInputFrom: inputBlock)
        if let convError { throw convError }
        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return outBuffer
        case .error:
            throw NSError(domain: "Audio", code: -3, userInfo: [NSLocalizedDescriptionKey: "Audio conversion failed"])
        @unknown default:
            throw NSError(domain: "Audio", code: -4, userInfo: [NSLocalizedDescriptionKey: "Audio conversion returned unknown status"])
        }
    }

    nonisolated private func duration(of buffer: AVAudioPCMBuffer) -> TimeInterval {
        let frames = Double(buffer.frameLength)
        let rate = buffer.format.sampleRate
        return frames / rate
    }

    func reset() {
        book = nil
        isParsing = false
        isSynthesizing = false
        progress = 0
        currentStatus = ""
        outputURL = nil
        errorMessage = nil
        logMessages.removeAll()
        synthesisTask?.cancel()
        synthesisTask = nil
        isCancelled = false
        bookFileURL = nil
        currentSessionFolder = nil
    }

    func cleanupSessionFolder() {
        guard let sessionFolder = currentSessionFolder else { return }
        do {
            try FileManager.default.removeItem(at: sessionFolder)
            currentSessionFolder = nil
            log("Cleaned up session folder: \(sessionFolder.path)", level: .info)
        } catch {
            log("Failed to clean up session folder: \(error.localizedDescription)", level: .error)
            errorMessage = "Failed to clean up session folder: \(error.localizedDescription)"
        }
    }

    func cancelSynthesis() {
        isCancelled = true
        synthesisTask?.cancel()
        isSynthesizing = false
        currentStatus = "Cancelled"
        log("Synthesis cancelled by user", level: .warning)
        errorMessage = "Synthesis cancelled"
    }

    func parseEPUB(at url: URL) async {
        reset()
        isParsing = true
        log("Starting EPUB parsing...")
        currentStatus = "Parsing EPUB..."
        self.bookFileURL = url

        do {
            // Use the more efficient method that reuses the EPUBDocument instance
            let (title, author, chapters) = try await epub.loadAllChapters(epubURL: url)

            let coverData = epub.extractCoverImageData(epubURL: url)
            self.book = Book(title: title, author: author, chapters: chapters, coverImageData: coverData)
            log("Successfully parsed EPUB: \(title) (\(chapters.count) chapters)", level: .success)
            if let author = author {
                log("Author: \(author)")
            }
        } catch {
            self.errorMessage = error.localizedDescription
            log("Failed to parse EPUB: \(error.localizedDescription)", level: .error)
        }
        isParsing = false
        currentStatus = ""
    }

    // Helper to calculate duration of an audio buffer

    func convertToAudiobook() async {
        guard let book = self.book, let modelURL = self.modelURL else { return }

        // Cancel any existing synthesis task
        synthesisTask?.cancel()
        isCancelled = false

        // Start the conversion process on a background thread
        synthesisTask = Task.detached { [weak self] in
            await self?.performConversion(book: book, modelURL: modelURL)
        }

        // Wait for the task to complete
        if let task = synthesisTask {
            await task.value
        }
    }

    nonisolated(nonsending) private func performConversion(book: Book, modelURL: URL) async {
        let startTime = Date()
        let totalCharacters = book.chapters.reduce(0) { $0 + $1.htmlContent.count }

        await MainActor.run {
            isSynthesizing = true
            progress = 0
            currentStatus = "Preparing conversion..."
            outputURL = nil
            errorMessage = nil
            log("Starting audiobook conversion...")
            log("Processing \(book.chapters.count) chapters (\(totalCharacters) characters)")
        }

        // Create unique ID for this conversion session
        let uniqueID = UUID().uuidString
        var sessionFolder: URL?

        do {
            let selectedVoice = await MainActor.run { self.voiceSelection.kokoroVoice }

            // Create a subfolder in the output directory for this conversion session
            sessionFolder = try await MainActor.run {
                try self.createConversionSessionFolder(uniqueID: uniqueID)
            }
            guard let sessionFolder = sessionFolder else {
                throw NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create conversion session folder"])
            }

            let totalChapters = book.chapters.count
            var mutableChapters = book.chapters  // we'll update startTime
            var cumulativeDuration: TimeInterval = 0

            let userCap = await MainActor.run { self.maxParallelWorkers }
            let cpu = ProcessInfo.processInfo.processorCount
            let maxConcurrency = max(1, min(cpu, totalChapters, userCap))
            await MainActor.run {
                log("Using \(maxConcurrency) parallel workers (user cap: \(userCap), CPU: \(cpu))")
                log("Available CPU cores: \(ProcessInfo.processInfo.processorCount)")
                log("Active processor count: \(ProcessInfo.processInfo.activeProcessorCount)")
            }
            let gate = AsyncSemaphore(value: maxConcurrency)

            struct ChapterResult {
                let index: Int
                let fileURL: URL
                let duration: TimeInterval
                let limitHits: Int
            }

            // Synthesize each chapter with bounded concurrency, writing to per-chapter temp WAV files
            let chapterResults = try await withThrowingTaskGroup(of: ChapterResult.self) { group in
                for (idx, chapter) in book.chapters.enumerated() {
                    await gate.acquire()
                    group.addTask {
                        defer { Task { await gate.release() } }
                        try Task.checkCancellation()

                        // Create a separate TTS instance per task
                        let tts = TTSService(modelURL: modelURL)
                        tts.limitHits = 0

                        await MainActor.run {
                            self.currentStatus = "Synthesizing chapter \(idx + 1) of \(totalChapters)..."
                            self.log("Worker: Processing chapter \(idx + 1)/\(totalChapters): '\(chapter.title)' (\(chapter.htmlContent.count) characters)")
                        }

                        let buffers = try tts.synthesizeWithFallback(chapter.htmlContent, voice: selectedVoice)
                        guard !buffers.isEmpty else {
                            throw NSError(domain: "TTS", code: -5, userInfo: [NSLocalizedDescriptionKey: "No audio produced for chapter \(idx + 1)"])
                        }

                        // Compute duration
                        let duration = buffers.reduce(0.0) { $0 + self.duration(of: $1) }

                        // Write to a temp WAV per chapter
                        let tmpURL = sessionFolder.appendingPathComponent("chapter_tmp_\(String(format: "%02d", idx + 1)).wav")
                        if let first = buffers.first {
                            try await appendBuffersToWAV(buffers: buffers, to: tmpURL, format: first.format)
                        }

                        return ChapterResult(index: idx, fileURL: tmpURL, duration: duration, limitHits: tts.limitHits)
                    }
                }

                var collected: [ChapterResult] = []
                for try await r in group {
                    collected.append(r)
                    await MainActor.run {
                        self.progress = Double(collected.count) / Double(totalChapters)
                    }
                }
                return collected.sorted { $0.index < $1.index }
            }

            // Prepare main audiobook WAV and per-chapter named files
            let wavURL = sessionFolder.appendingPathComponent("audiobook_\(uniqueID).wav")
            let m4aURL = sessionFolder.appendingPathComponent("audiobook_\(uniqueID).m4a")

            var mainAudioFile: AVAudioFile?
            var targetFormat: AVAudioFormat?

            // Stream each chapter temp file into the main WAV sequentially, then move temp to named file
            for result in chapterResults {
                try Task.checkCancellation()
                // Stream this chapter into the main WAV in a scoped block so the file closes before moving
                do {
                    let inFile = try AVAudioFile(forReading: result.fileURL)

                    // Initialize main file and target format from the first chapter encountered
                    if targetFormat == nil {
                        targetFormat = inFile.processingFormat
                        if let targetFormat {
                            var settings = targetFormat.settings
                            settings[AVFormatIDKey] = kAudioFormatLinearPCM
                            let isFloat = (targetFormat.commonFormat == .pcmFormatFloat32 || targetFormat.commonFormat == .pcmFormatFloat64)
                            settings[AVLinearPCMIsFloatKey] = isFloat
                            settings[AVLinearPCMBitDepthKey] = isFloat ? 32 : 16
                            settings[AVLinearPCMIsBigEndianKey] = false
                            settings[AVLinearPCMIsNonInterleaved] = !targetFormat.isInterleaved

                            try? FileManager.default.removeItem(at: wavURL)
                            mainAudioFile = try AVAudioFile(forWriting: wavURL, settings: settings)
                        }
                    }

                    guard let mainFile = mainAudioFile, let tFormat = targetFormat else {
                        throw NSError(domain: "Audio", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize main audio file"]) }

                    // Read in chunks and write to main WAV, converting if needed
                    let readFormat = inFile.processingFormat
                    let capacity: AVAudioFrameCount = 8192
                    while true {
                        try Task.checkCancellation()
                        guard let buf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: capacity) else { break }
                        try inFile.read(into: buf)
                        if buf.frameLength == 0 { break }

                        var writeBuf: AVAudioPCMBuffer = buf
                        if !self.formatsMatch(readFormat, tFormat) {
                            do {
                                writeBuf = try self.convert(buf, to: tFormat)
                            } catch {
                                // Best-effort: fall back to original buffer
                            }
                        }
                        try mainFile.write(from: writeBuf)
                    }
                }

                // Create individual, nicely named chapter file by moving the temp file
                let chapter = book.chapters[result.index]
                let cleanTitle = chapter.title
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .replacingOccurrences(of: "\\", with: "-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let chapterWavURL = sessionFolder.appendingPathComponent("chapter_\(String(format: "%02d", result.index + 1))_\(cleanTitle).wav")

                // If destination exists, remove it first
                try? FileManager.default.removeItem(at: chapterWavURL)
                do {
                    try FileManager.default.moveItem(at: result.fileURL, to: chapterWavURL)
                    await MainActor.run {
                        log("Created chapter file: \(chapterWavURL.lastPathComponent)", level: .success)
                    }
                } catch {
                    await MainActor.run {
                        log("Failed to finalize chapter file \(chapterWavURL.lastPathComponent): \(error.localizedDescription)", level: .warning)
                    }
                }

                // Calculate and store chapter start time
                mutableChapters[result.index].startTime = cumulativeDuration
                cumulativeDuration += result.duration
            }

            guard targetFormat != nil else {
                throw NSError(domain: "Audio", code: -6, userInfo: [NSLocalizedDescriptionKey: "No audio buffers synthesized"])
            }

            // Close the main audio file
            mainAudioFile = nil

            await MainActor.run {
                log("WAV file created at: \(wavURL.path)", level: .info)
                currentStatus = "Converting to M4A format..."
                log("Converting WAV to M4A format...")
            }

            try await transcodeWAVtoM4A(wavURL: wavURL, m4aURL: m4aURL)

            await MainActor.run {
                log("M4A file created at: \(m4aURL.path)", level: .info)
            }

            // Clean up the temporary WAV file after conversion
            try? FileManager.default.removeItem(at: wavURL)

            // Move the audiobook to the chosen save location (with selected extension)
            await MainActor.run {
                log("Attempting to move M4A file from \(m4aURL.path) to save location", level: .info)
            }
            let finalURL = try await MainActor.run {
                try self.moveAudiobookToSaveLocation(from: m4aURL)
            }

            // Write chapters.json sidecar file
            let chaptersMetadata = mutableChapters.map { chapter in
                [
                    "title": chapter.title,
                    "start": chapter.startTime ?? 0
                ] as [String: Any]
            }
            let jsonURL = finalURL.deletingLastPathComponent().appendingPathComponent("chapters.json")
            let jsonData = try JSONSerialization.data(withJSONObject: chaptersMetadata, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: jsonURL)

            // Preserve the conversion session folder for user inspection
            await MainActor.run {
                self.currentSessionFolder = sessionFolder
                log("Conversion session folder preserved: \(sessionFolder.path)", level: .info)
                log("Individual chapter files available in: \(sessionFolder.lastPathComponent)", level: .info)
            }

            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let charactersPerSecond = Double(totalCharacters) / duration

            // Aggregate token limit hits across tasks
            let totalLimitHits = chapterResults.reduce(0) { $0 + $1.limitHits }

            await MainActor.run {
                log("Conversion completed successfully!", level: .success)
                log("Total time: \(String(format: "%.1f", duration)) seconds", level: .info)
                log("Processing speed: \(String(format: "%.0f", charactersPerSecond)) characters/second", level: .info)
                log("Used \(maxConcurrency) parallel workers", level: .info)
                log("Kokoro token limit hits during conversion: \(totalLimitHits)", level: .warning)
                currentStatus = "Conversion completed"
                self.outputURL = finalURL
                self.progress = 1.0
            }

        } catch {
            // Preserve the conversion session folder even on error for debugging
            if let sessionFolder = sessionFolder {
                await MainActor.run {
                    self.currentSessionFolder = sessionFolder
                    log("Conversion failed. Session folder preserved for debugging: \(sessionFolder.path)", level: .warning)
                }
            }

            await MainActor.run {
                if error is CancellationError {
                    self.errorMessage = "Synthesis cancelled"
                    log("Conversion was cancelled", level: .warning)
                } else {
                    self.errorMessage = error.localizedDescription
                    log("Conversion failed: \(error.localizedDescription)", level: .error)
                }
                currentStatus = "Conversion failed"
            }
        }

        await MainActor.run {
            isSynthesizing = false
        }
    }

    func saveAudiobookWithDialog() {
        guard let outputURL = outputURL else { return }

        #if os(macOS)
        let panel = NSSavePanel()
        let ext = outputFormat.fileExtension
        panel.nameFieldStringValue = (book?.title ?? "audiobook").appending(".").appending(ext)
        panel.allowedContentTypes = [.mpeg4Audio]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try FileManager.default.copyItem(at: outputURL, to: url)
                    self.log("Audiobook copied to: \(url.path)", level: .success)
                } catch {
                    self.errorMessage = "Failed to copy audiobook: \(error.localizedDescription)"
                    self.log("Failed to copy audiobook: \(error.localizedDescription)", level: .error)
                }
            }
        }
        #endif
    }

    // MARK: - Preview voice
    func previewVoice() async {
        if isPreviewing {
            previewer.stop()
            isPreviewing = false
            return
        }
        guard let modelURL = modelURL else { return }

        isPreviewing = true
        defer { isPreviewing = false }

        do {
            let text: String
            if let first = book?.chapters.first?.htmlContent, !first.isEmpty {
                text = String(first.prefix(300))
            } else {
                text = samplePreviewText
            }

            let tts = TTSService(modelURL: modelURL)
            let buffers = try tts.synthesizeWithFallback(text, voice: self.voiceSelection.kokoroVoice)
            guard let first = buffers.first else { return }
            previewer.play(buffer: first, speed: 1.0)
        } catch {
            self.errorMessage = "Preview failed: \(error.localizedDescription)"
            self.log("Preview failed: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - Additional types

enum VoiceSelection: Hashable {
    case afHeart
    case bmGeorge

    var displayName: String {
        switch self {
        case .afHeart: return "af_heart"
        case .bmGeorge: return "bm_george"
        }
    }

    var kokoroVoice: KokoroVoice {
        switch self {
        case .afHeart: return .afHeart
        case .bmGeorge: return .bmGeorge
        }
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case m4a
    case m4b

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m4a: return "M4A"
        case .m4b: return "M4B"
        }
    }

    var fileExtension: String { rawValue }
}

extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Book and Chapter Models are defined in Models.swift



