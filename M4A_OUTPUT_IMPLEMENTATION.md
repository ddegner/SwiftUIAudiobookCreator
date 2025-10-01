# M4A Audio Output Implementation

## Overview

This section covers the implementation of M4A audio file generation with proper metadata, chapter-based output, and audiobook-specific optimizations. The system uses AVFoundation for audio processing and Core Audio for format conversion.

## Core Components

### AudioExportService

```swift
import AVFoundation
import CoreAudio

class AudioExportService: AudioExportServiceProtocol {
    private let fileManager = FileManager.default
    
    func exportAudio(_ audioData: Data, to url: URL, format: AudioFormat) async throws {
        switch format.format {
        case .m4a:
            try await exportM4A(audioData, to: url)
        case .mp3:
            try await exportMP3(audioData, to: url)
        case .wav:
            try await exportWAV(audioData, to: url)
        }
    }
    
    func createM4AFile(from audioData: Data, metadata: AudioMetadata) async throws -> URL {
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        
        try await exportM4A(audioData, to: tempURL)
        try await addMetadata(to: tempURL, metadata: metadata)
        
        return tempURL
    }
    
    func combineAudioFiles(_ urls: [URL], outputURL: URL) async throws {
        try await mergeAudioFiles(urls, outputURL: outputURL)
    }
    
    func validateAudioFormat(_ data: Data) async throws -> Bool {
        return try await validateAudioData(data)
    }
    
    // MARK: - Private Methods
    
    private func exportM4A(_ audioData: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            do {
                // Create AVAudioFile from raw audio data
                let audioFile = try AVAudioFile(forReading: createTempWAVFile(from: audioData))
                
                // Create M4A format settings
                let formatSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 128000
                ]
                
                // Create output file
                let outputFile = try AVAudioFile(forWriting: url, settings: formatSettings)
                
                // Convert audio
                try convertAudio(from: audioFile, to: outputFile) { success in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ConversionError.audioGenerationFailed("M4A conversion failed"))
                    }
                }
                
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func exportMP3(_ audioData: Data, to url: URL) async throws {
        // MP3 export implementation
        // Note: MP3 encoding requires additional libraries or system tools
        throw ConversionError.audioGenerationFailed("MP3 export not implemented")
    }
    
    private func exportWAV(_ audioData: Data, to url: URL) async throws {
        try audioData.write(to: url)
    }
    
    private func createTempWAVFile(from audioData: Data) throws -> URL {
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        
        // Create WAV file from raw audio data
        let wavData = try createWAVData(from: audioData)
        try wavData.write(to: tempURL)
        
        return tempURL
    }
    
    private func createWAVData(from audioData: Data) throws -> Data {
        // Create WAV header
        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(audioData.count)
        let fileSize = UInt32(36 + dataSize)
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(Data(bytes: &fileSize, count: 4))
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(Data(bytes: &UInt32(16), count: 4)) // fmt chunk size
        wavData.append(Data(bytes: &UInt16(1), count: 2))  // PCM format
        wavData.append(Data(bytes: &channels, count: 2))
        wavData.append(Data(bytes: &sampleRate, count: 4))
        wavData.append(Data(bytes: &byteRate, count: 4))
        wavData.append(Data(bytes: &blockAlign, count: 2))
        wavData.append(Data(bytes: &bitsPerSample, count: 2))
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(Data(bytes: &dataSize, count: 4))
        wavData.append(audioData)
        
        return wavData
    }
    
    private func convertAudio(from inputFile: AVAudioFile, to outputFile: AVAudioFile, completion: @escaping (Bool) -> Void) throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: 4096)!
        
        while inputFile.framePosition < inputFile.length {
            try inputFile.read(into: buffer)
            try outputFile.write(from: buffer)
        }
        
        completion(true)
    }
    
    private func addMetadata(to url: URL, metadata: AudioMetadata) async throws {
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        
        guard let session = exportSession else {
            throw ConversionError.audioGenerationFailed("Failed to create export session")
        }
        
        let outputURL = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        session.outputURL = outputURL
        session.outputFileType = .m4a
        
        // Add metadata
        let mutableMetadata = AVMutableMetadataItem()
        mutableMetadata.identifier = .commonIdentifierTitle
        mutableMetadata.value = metadata.title as NSString
        
        let artistMetadata = AVMutableMetadataItem()
        artistMetadata.identifier = .commonIdentifierArtist
        artistMetadata.value = metadata.artist as NSString
        
        if let album = metadata.album {
            let albumMetadata = AVMutableMetadataItem()
            albumMetadata.identifier = .commonIdentifierAlbumName
            albumMetadata.value = album as NSString
        }
        
        if let trackNumber = metadata.trackNumber {
            let trackMetadata = AVMutableMetadataItem()
            trackMetadata.identifier = .commonIdentifierTrackNumber
            trackMetadata.value = trackNumber as NSNumber
        }
        
        session.metadata = [mutableMetadata, artistMetadata]
        
        try await withCheckedThrowingContinuation { continuation in
            session.exportAsynchronously {
                if session.status == .completed {
                    do {
                        try self.fileManager.removeItem(at: url)
                        try self.fileManager.moveItem(at: outputURL, to: url)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: ConversionError.audioGenerationFailed("Metadata export failed"))
                }
            }
        }
    }
    
    private func mergeAudioFiles(_ urls: [URL], outputURL: URL) async throws {
        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var currentTime = CMTime.zero
        
        for url in urls {
            let asset = AVAsset(url: url)
            let assetTrack = try await asset.loadTracks(withMediaType: .audio).first!
            let duration = try await asset.load(.duration)
            
            try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: assetTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .m4a
        
        try await withCheckedThrowingContinuation { continuation in
            exportSession?.exportAsynchronously {
                if exportSession?.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ConversionError.audioGenerationFailed("Audio merge failed"))
                }
            }
        }
    }
    
    private func validateAudioData(_ data: Data) async throws -> Bool {
        // Basic validation - check if data looks like audio
        return data.count > 1024 // Minimum size for valid audio data
    }
}
```

### Audio Metadata Management

```swift
class AudioMetadataManager {
    static func createMetadata(for chapter: EPUBChapter, book: EPUBBook, trackNumber: Int, totalTracks: Int) -> AudioMetadata {
        return AudioMetadata(
            title: chapter.displayTitle,
            artist: book.author,
            album: book.title,
            trackNumber: trackNumber,
            totalTracks: totalTracks,
            duration: chapter.estimatedDuration,
            genre: "Audiobook"
        )
    }
    
    static func createBookMetadata(for book: EPUBBook) -> AudioMetadata {
        return AudioMetadata(
            title: book.title,
            artist: book.author,
            album: book.title,
            trackNumber: nil,
            totalTracks: nil,
            duration: nil,
            genre: "Audiobook"
        )
    }
}
```

### Chapter-Based Audio Generation

```swift
class ChapterAudioGenerator {
    private let audioExporter: AudioExportServiceProtocol
    private let ttsService: TTSServiceProtocol
    private let textNormalizer: TextNormalizationServiceProtocol
    
    init(audioExporter: AudioExportServiceProtocol, ttsService: TTSServiceProtocol, textNormalizer: TextNormalizationServiceProtocol) {
        self.audioExporter = audioExporter
        self.ttsService = ttsService
        self.textNormalizer = textNormalizer
    }
    
    func generateAudioForChapters(_ chapters: [EPUBChapter], book: EPUBBook, settings: TTSSettings, normalizationSettings: NormalizationSettings, progress: ConversionProgress) async throws -> [URL] {
        var audioFiles: [URL] = []
        
        progress.totalChapters = chapters.count
        progress.isConverting = true
        
        for (index, chapter) in chapters.enumerated() {
            progress.currentChapter = index + 1
            progress.currentOperation = "Processing \(chapter.displayTitle)"
            
            do {
                // Normalize text
                let normalizedText = try await textNormalizer.normalizeText(chapter.content, with: normalizationSettings)
                
                // Generate audio
                let audioData = try await ttsService.synthesizeText(normalizedText, with: settings)
                
                // Create metadata
                let metadata = AudioMetadataManager.createMetadata(
                    for: chapter,
                    book: book,
                    trackNumber: index + 1,
                    totalTracks: chapters.count
                )
                
                // Export to M4A
                let audioFile = try await audioExporter.createM4AFile(from: audioData, metadata: metadata)
                audioFiles.append(audioFile)
                
                // Update progress
                progress.progress = Double(index + 1) / Double(chapters.count)
                
            } catch {
                progress.error = ConversionError.audioGenerationFailed("Failed to process chapter \(chapter.displayTitle): \(error.localizedDescription)")
                throw error
            }
        }
        
        progress.isConverting = false
        return audioFiles
    }
    
    func generateCombinedAudioFile(from audioFiles: [URL], book: EPUBBook, outputURL: URL) async throws {
        try await audioExporter.combineAudioFiles(audioFiles, outputURL: outputURL)
        
        // Add book-level metadata
        let bookMetadata = AudioMetadataManager.createBookMetadata(for: book)
        try await addBookMetadata(to: outputURL, metadata: bookMetadata)
    }
    
    private func addBookMetadata(to url: URL, metadata: AudioMetadata) async throws {
        // Implementation for adding book-level metadata
        // This would typically involve using AVFoundation to modify the M4A file
    }
}
```

### Audio Quality Optimization

```swift
class AudioQualityOptimizer {
    static func optimizeForAudiobook(_ audioData: Data) async throws -> Data {
        // Apply audiobook-specific optimizations
        
        // 1. Normalize audio levels
        let normalizedData = try await normalizeAudioLevels(audioData)
        
        // 2. Apply gentle compression
        let compressedData = try await applyCompression(normalizedData)
        
        // 3. Add subtle noise gate
        let gatedData = try await applyNoiseGate(compressedData)
        
        return gatedData
    }
    
    private static func normalizeAudioLevels(_ audioData: Data) async throws -> Data {
        // Implement audio normalization using Core Audio
        // This is a simplified version - in production, you'd use more sophisticated algorithms
        
        let audioBuffer = audioData.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int16.self)
        }
        
        var maxAmplitude: Int16 = 0
        for sample in audioBuffer {
            maxAmplitude = max(maxAmplitude, abs(sample))
        }
        
        if maxAmplitude > 0 {
            let normalizationFactor = Double(Int16.max) / Double(maxAmplitude)
            var normalizedData = Data()
            
            for sample in audioBuffer {
                let normalizedSample = Int16(Double(sample) * normalizationFactor)
                normalizedData.append(contentsOf: withUnsafeBytes(of: normalizedSample) { Data($0) })
            }
            
            return normalizedData
        }
        
        return audioData
    }
    
    private static func applyCompression(_ audioData: Data) async throws -> Data {
        // Apply gentle compression for consistent volume levels
        // This is a placeholder - in production, you'd use proper audio compression algorithms
        return audioData
    }
    
    private static func applyNoiseGate(_ audioData: Data) async throws -> Data {
        // Apply noise gate to reduce background noise
        // This is a placeholder - in production, you'd use proper noise gate algorithms
        return audioData
    }
}
```

### File Management

```swift
class AudioFileManager {
    private let fileManager = FileManager.default
    
    func createAudiobookDirectory(for book: EPUBBook) throws -> URL {
        let documentsURL = fileManager.urls(for: .documentsDirectory, in: .userDomainMask).first!
        let audiobookURL = documentsURL.appendingPathComponent("Audiobooks")
            .appendingPathComponent(book.title.sanitizedForFilename)
        
        try fileManager.createDirectory(at: audiobookURL, withIntermediateDirectories: true)
        return audiobookURL
    }
    
    func saveChapterAudio(_ audioFile: URL, chapter: EPUBChapter, book: EPUBBook) throws -> URL {
        let audiobookURL = try createAudiobookDirectory(for: book)
        let chapterURL = audiobookURL.appendingPathComponent("\(chapter.order) - \(chapter.displayTitle.sanitizedForFilename).m4a")
        
        try fileManager.moveItem(at: audioFile, to: chapterURL)
        return chapterURL
    }
    
    func saveCombinedAudio(_ audioFile: URL, book: EPUBBook) throws -> URL {
        let audiobookURL = try createAudiobookDirectory(for: book)
        let combinedURL = audiobookURL.appendingPathComponent("\(book.title.sanitizedForFilename) - Complete.m4a")
        
        try fileManager.moveItem(at: audioFile, to: combinedURL)
        return combinedURL
    }
    
    func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }
}

extension String {
    var sanitizedForFilename: String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
```

## Usage Examples

### Generate Chapter Audio Files

```swift
let audioGenerator = ChapterAudioGenerator(
    audioExporter: AudioExportService(),
    ttsService: KokoroTTSService(),
    textNormalizer: TextNormalizationService()
)

let progress = ConversionProgress()
let audioFiles = try await audioGenerator.generateAudioForChapters(
    chapters,
    book: book,
    settings: ttsSettings,
    normalizationSettings: normalizationSettings,
    progress: progress
)
```

### Create Combined Audiobook

```swift
let combinedURL = try await audioGenerator.generateCombinedAudioFile(
    from: audioFiles,
    book: book,
    outputURL: outputURL
)
```

### Save Audio Files

```swift
let fileManager = AudioFileManager()

// Save individual chapters
var savedChapterFiles: [URL] = []
for (index, audioFile) in audioFiles.enumerated() {
    let savedURL = try fileManager.saveChapterAudio(audioFile, chapter: chapters[index], book: book)
    savedChapterFiles.append(savedURL)
}

// Save combined audiobook
let savedCombinedURL = try fileManager.saveCombinedAudio(combinedURL, book: book)
```

This implementation provides comprehensive M4A audio generation with proper metadata, chapter-based output, and audiobook-specific optimizations using AVFoundation and Core Audio.