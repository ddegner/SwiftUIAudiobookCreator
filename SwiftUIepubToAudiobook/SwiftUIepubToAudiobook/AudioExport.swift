import Foundation
import AVFoundation

func appendBuffersToWAV(buffers: [AVAudioPCMBuffer],
                        to wavURL: URL,
                        format: AVAudioFormat) async throws {
    try? FileManager.default.removeItem(at: wavURL)

    var settings = format.settings
    settings[AVFormatIDKey] = kAudioFormatLinearPCM
    // Match buffer format to avoid internal converter init/reuse failures
    let isFloat = (format.commonFormat == .pcmFormatFloat32 || format.commonFormat == .pcmFormatFloat64)
    settings[AVLinearPCMIsFloatKey] = isFloat
    settings[AVLinearPCMBitDepthKey] = isFloat ? 32 : 16
    settings[AVLinearPCMIsBigEndianKey] = false
    settings[AVLinearPCMIsNonInterleaved] = !format.isInterleaved

    let file = try AVAudioFile(forWriting: wavURL, settings: settings)

    for b in buffers {
        try file.write(from: b)
    }
}

func writeBuffersToWAV(_ buffers: [AVAudioPCMBuffer], to wavURL: URL) throws {
    try? FileManager.default.removeItem(at: wavURL)
    guard let fmt = buffers.first?.format else { throw NSError(domain: "Audio", code: -1) }
    var settings = fmt.settings
    settings[AVFormatIDKey] = kAudioFormatLinearPCM
    let isFloat = (fmt.commonFormat == .pcmFormatFloat32 || fmt.commonFormat == .pcmFormatFloat64)
    settings[AVLinearPCMIsFloatKey] = isFloat
    settings[AVLinearPCMBitDepthKey] = isFloat ? 32 : 16
    settings[AVLinearPCMIsBigEndianKey] = false
    settings[AVLinearPCMIsNonInterleaved] = !fmt.isInterleaved

    let file = try AVAudioFile(forWriting: wavURL, settings: settings)
    for b in buffers { try file.write(from: b) }
}

func transcodeWAVtoM4A(wavURL: URL, m4aURL: URL, metadata: [AVMetadataItem]? = nil) async throws {
    let asset = AVURLAsset(url: wavURL)
    try? FileManager.default.removeItem(at: m4aURL)

    // Use the standard AVAssetExportSession approach with proper error handling
    guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
    }
    export.outputURL = m4aURL
    export.outputFileType = .m4a
    if let metadata { export.metadata = metadata }

    await withCheckedContinuation { (resume: CheckedContinuation<Void, Never>) in
        export.exportAsynchronously {
            resume.resume()
        }
    }

    if export.status != .completed {
        throw export.error ?? NSError(domain: "Export", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
    }
}
