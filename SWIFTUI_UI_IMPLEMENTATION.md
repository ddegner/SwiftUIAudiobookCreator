# SwiftUI UI Implementation

## Overview

This section covers the implementation of a modern, single-screen SwiftUI interface for the EPUB to Audiobook converter. The UI follows macOS design guidelines with a clean, intuitive layout that provides all necessary controls and feedback.

## Core UI Components

### Main App Structure

```swift
// EPUBAudiobookConverterApp.swift
import SwiftUI

@main
struct EPUBAudiobookConverterApp: App {
    @StateObject private var serviceLocator = ServiceLocator()
    @StateObject private var conversionProgress = ConversionProgress()
    @StateObject private var voiceManager = VoiceManager(ttsService: ServiceLocator.shared.resolve(TTSServiceProtocol.self)!)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceLocator)
                .environmentObject(conversionProgress)
                .environmentObject(voiceManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    serviceLocator.registerDefaultServices()
                    Task {
                        await voiceManager.loadVoices()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
```

### ContentView (Main Interface)

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @EnvironmentObject private var conversionProgress: ConversionProgress
    @EnvironmentObject private var voiceManager: VoiceManager
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with book info and settings
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 250)
        } detail: {
            // Main conversion area
            MainConversionView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("Conversion Error", isPresented: $viewModel.showingError) {
            Button("OK") { viewModel.showingError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

### ContentViewModel

```swift
// ContentViewModel.swift
import SwiftUI
import Combine

class ContentViewModel: ObservableObject {
    @Published var selectedBook: EPUBBook?
    @Published var normalizationSettings = NormalizationSettings.default
    @Published var ttsSettings = TTSSettings.default
    @Published var showingSettings = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var isProcessing = false
    
    private let serviceLocator = ServiceLocator.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for conversion progress updates
        NotificationCenter.default.publisher(for: .conversionProgressUpdated)
            .sink { [weak self] notification in
                if let error = notification.object as? ConversionError {
                    self?.errorMessage = error.localizedDescription
                    self?.showingError = true
                }
            }
            .store(in: &cancellables)
    }
    
    func selectBook(_ book: EPUBBook) {
        selectedBook = book
    }
    
    func startConversion() {
        guard let book = selectedBook else { return }
        
        Task {
            await performConversion(book: book)
        }
    }
    
    private func performConversion(book: EPUBBook) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let conversionService = ConversionService(
                epubParser: serviceLocator.resolve(EPUPParserServiceProtocol.self)!,
                textNormalizer: serviceLocator.resolve(TextNormalizationServiceProtocol.self)!,
                ttsService: serviceLocator.resolve(TTSServiceProtocol.self)!,
                audioExporter: serviceLocator.resolve(AudioExportServiceProtocol.self)!
            )
            
            try await conversionService.convertBook(book, normalizationSettings: normalizationSettings, ttsSettings: ttsSettings)
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
```

### SidebarView

```swift
// SidebarView.swift
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject private var voiceManager: VoiceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Book Selection
            BookSelectionView(viewModel: viewModel)
            
            Divider()
            
            // Voice Settings
            VoiceSettingsView(viewModel: viewModel)
            
            Divider()
            
            // Normalization Settings
            NormalizationSettingsView(viewModel: viewModel)
            
            Divider()
            
            // Conversion Controls
            ConversionControlsView(viewModel: viewModel)
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}
```

### BookSelectionView

```swift
// BookSelectionView.swift
import SwiftUI

struct BookSelectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var isDragOver = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EPUB Book")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let book = viewModel.selectedBook {
                BookInfoView(book: book) {
                    viewModel.selectedBook = nil
                }
            } else {
                DropZoneView(isDragOver: $isDragOver) {
                    selectEPUBFile()
                }
            }
        }
    }
    
    private func selectEPUBFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.epub]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await loadBook(from: url)
            }
        }
    }
    
    private func loadBook(from url: URL) async {
        do {
            let parser = ServiceLocator.shared.resolve(EPUPParserServiceProtocol.self)!
            let book = try await parser.parseEPUB(from: url)
            await MainActor.run {
                viewModel.selectBook(book)
            }
        } catch {
            await MainActor.run {
                viewModel.errorMessage = error.localizedDescription
                viewModel.showingError = true
            }
        }
    }
}
```

### DropZoneView

```swift
// DropZoneView.swift
import SwiftUI

struct DropZoneView: View {
    @Binding var isDragOver: Bool
    let onFileSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Drag & Drop EPUB File")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("or click to browse")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Select EPUB File") {
                onFileSelected()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                if url.pathExtension.lowercased() == "epub" {
                    DispatchQueue.main.async {
                        onFileSelected()
                    }
                }
            }
        }
        
        return true
    }
}
```

### BookInfoView

```swift
// BookInfoView.swift
import SwiftUI

struct BookInfoView: View {
    let book: EPUBBook
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if let coverImage = book.coverImage, let nsImage = NSImage(data: coverImage) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "Chapters", value: "\(book.chapters.count)")
                InfoRow(label: "Words", value: "\(book.totalWordCount)")
                InfoRow(label: "Version", value: book.epubVersion.rawValue)
                InfoRow(label: "DRM", value: book.isDRMProtected ? "Protected" : "Free")
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}
```

### VoiceSettingsView

```swift
// VoiceSettingsView.swift
import SwiftUI

struct VoiceSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject private var voiceManager: VoiceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Voice", selection: Binding(
                    get: { viewModel.ttsSettings.voice },
                    set: { viewModel.ttsSettings.voice = $0 }
                )) {
                    ForEach(voiceManager.availableVoices) { voice in
                        Text(voice.name)
                            .tag(voice)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Voice Parameters
            VStack(alignment: .leading, spacing: 8) {
                Text("Speed: \(String(format: "%.1f", viewModel.ttsSettings.speed))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.ttsSettings.speed },
                        set: { viewModel.ttsSettings.speed = $0 }
                    ),
                    in: 0.5...2.0,
                    step: 0.1
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pitch: \(String(format: "%.1f", viewModel.ttsSettings.pitch))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.ttsSettings.pitch },
                        set: { viewModel.ttsSettings.pitch = $0 }
                    ),
                    in: 0.5...2.0,
                    step: 0.1
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Volume: \(Int(viewModel.ttsSettings.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { viewModel.ttsSettings.volume },
                        set: { viewModel.ttsSettings.volume = $0 }
                    ),
                    in: 0.0...1.0,
                    step: 0.1
                )
            }
            
            // Quality Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Quality", selection: Binding(
                    get: { viewModel.ttsSettings.quality },
                    set: { viewModel.ttsSettings.quality = $0 }
                )) {
                    ForEach(TTSSettings.TTSQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName)
                            .tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
```

### NormalizationSettingsView

```swift
// NormalizationSettingsView.swift
import SwiftUI

struct NormalizationSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Processing")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Newline Handling
            VStack(alignment: .leading, spacing: 8) {
                Text("Newline Handling")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Newline Handling", selection: Binding(
                    get: { viewModel.normalizationSettings.newlineHandling },
                    set: { viewModel.normalizationSettings.newlineHandling = $0 }
                )) {
                    ForEach(NormalizationSettings.NewlineHandling.allCases, id: \.self) { handling in
                        Text(handling.displayName)
                            .tag(handling)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Text Processing Options
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Remove Footnotes", isOn: Binding(
                    get: { viewModel.normalizationSettings.removeFootnotes },
                    set: { viewModel.normalizationSettings.removeFootnotes = $0 }
                ))
                
                Toggle("Preserve Chapter Titles", isOn: Binding(
                    get: { viewModel.normalizationSettings.preserveChapterTitles },
                    set: { viewModel.normalizationSettings.preserveChapterTitles = $0 }
                ))
                
                Toggle("Remove Page Breaks", isOn: Binding(
                    get: { viewModel.normalizationSettings.removePageBreaks },
                    set: { viewModel.normalizationSettings.removePageBreaks = $0 }
                ))
                
                Toggle("Normalize Spacing", isOn: Binding(
                    get: { viewModel.normalizationSettings.normalizeSpacing },
                    set: { viewModel.normalizationSettings.normalizeSpacing = $0 }
                ))
                
                Toggle("Remove Special Characters", isOn: Binding(
                    get: { viewModel.normalizationSettings.removeSpecialCharacters },
                    set: { viewModel.normalizationSettings.removeSpecialCharacters = $0 }
                ))
            }
            
            // Custom Replacements
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Replacements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.normalizationSettings.customReplacements.isEmpty {
                    Text("No custom replacements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.normalizationSettings.customReplacements) { replacement in
                        ReplacementRowView(replacement: replacement) {
                            viewModel.normalizationSettings.customReplacements.removeAll { $0.id == replacement.id }
                        }
                    }
                }
                
                Button("Add Replacement") {
                    viewModel.normalizationSettings.customReplacements.append(
                        TextReplacement(pattern: "", replacement: "")
                    )
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }
}

struct ReplacementRowView: View {
    let replacement: TextReplacement
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(replacement.pattern)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text("→ \(replacement.replacement)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
```

### ConversionControlsView

```swift
// ConversionControlsView.swift
import SwiftUI

struct ConversionControlsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject private var conversionProgress: ConversionProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion")
                .font(.headline)
                .foregroundColor(.primary)
            
            if conversionProgress.isConverting {
                ConversionProgressView()
            } else {
                Button(action: viewModel.startConversion) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Start Conversion")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedBook == nil)
            }
            
            if let book = viewModel.selectedBook {
                let estimatedDuration = estimateConversionTime(for: book)
                Text("Estimated time: \(formatDuration(estimatedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func estimateConversionTime(for book: EPUBBook) -> TimeInterval {
        let wordsPerMinute = 150.0 // Average TTS speed
        let totalWords = book.totalWordCount
        return TimeInterval(totalWords) / wordsPerMinute * 60.0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
```

### ConversionProgressView

```swift
// ConversionProgressView.swift
import SwiftUI

struct ConversionProgressView: View {
    @EnvironmentObject private var conversionProgress: ConversionProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Converting...")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: conversionProgress.progress)
                .progressViewStyle(.linear)
            
            Text(conversionProgress.currentChapterTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(conversionProgress.currentOperation)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let estimatedTime = conversionProgress.estimatedTimeRemaining {
                Text("Remaining: \(formatDuration(estimatedTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
```

### MainConversionView

```swift
// MainConversionView.swift
import SwiftUI

struct MainConversionView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject private var conversionProgress: ConversionProgress
    
    var body: some View {
        VStack(spacing: 20) {
            if let book = viewModel.selectedBook {
                BookPreviewView(book: book)
            } else {
                WelcomeView()
            }
            
            if conversionProgress.isConverting {
                ConversionProgressView()
                    .frame(maxWidth: 400)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("EPUB to Audiobook Converter")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Convert your DRM-free EPUB files into high-quality audiobooks using advanced neural TTS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "waveform", text: "High-quality neural TTS voices")
                FeatureRow(icon: "text.alignleft", text: "Advanced text normalization")
                FeatureRow(icon: "book.pages", text: "Chapter-based M4A output")
                FeatureRow(icon: "lock.shield", text: "100% local processing")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct BookPreviewView: View {
    let book: EPUBBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Book Preview")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(book.chapters.prefix(10)) { chapter in
                        ChapterPreviewRow(chapter: chapter)
                    }
                    
                    if book.chapters.count > 10 {
                        Text("... and \(book.chapters.count - 10) more chapters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ChapterPreviewRow: View {
    let chapter: EPUBChapter
    
    var body: some View {
        HStack {
            Text("\(chapter.order)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.displayTitle)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("\(chapter.wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```

## Usage Example

The complete UI is assembled in the main app structure and provides a modern, intuitive interface for EPUB to audiobook conversion. The interface includes:

1. **Sidebar**: Book selection, voice settings, text processing options, and conversion controls
2. **Main Area**: Book preview and conversion progress
3. **Drag & Drop**: Easy EPUB file selection
4. **Real-time Progress**: Live conversion status and progress updates
5. **Settings**: Comprehensive configuration options

The UI follows macOS design guidelines with proper spacing, typography, and interaction patterns, providing a professional and user-friendly experience for audiobook conversion.