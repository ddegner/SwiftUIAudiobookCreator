import Foundation
import AVFoundation

public enum TTSWriterError: Error {
    case cannotCreateFile
}

public final class TTSWriter: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var isCancelled = false

    public override init() {
        super.init()
    }

    public func availableVoices(includeEnhanced: Bool = true) -> [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        guard includeEnhanced else { return all }
        return all.sorted { ($0.quality.rawValue) > ($1.quality.rawValue) }
    }

    public func writeChapter(
        chapter: Chapter,
        voiceConfig: TTSVoiceConfig,
        outputURL: URL,
        progress: @Sendable @escaping (Double) -> Void,
        completion: @Sendable @escaping (Result<URL, Error>) -> Void
    ) {
        isCancelled = false
        let utterances = makeUtterances(for: chapter, voiceConfig: voiceConfig)
        // Write PCM to a temp CAF, then export to M4A (AAC)
        let tempCAF = outputURL.deletingPathExtension().appendingPathExtension("caf")
        let pcmSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let audioFile = try AVAudioFile(forWriting: tempCAF, settings: pcmSettings)
            var totalUtterances = utterances.count
            var processedUtterances = 0

            synthesizer.write(AVSpeechUtterance(string: "")) { _ in }

            var iterator = utterances.makeIterator()
            func writeNext() {
                if isCancelled {
                    completion(.failure(NSError(domain: "DeepWikiTTS", code: -999, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])));
                    return
                }
                guard let next = iterator.next() else {
                    // Export to M4A (AAC)
                    exportCAFToM4A(inputURL: tempCAF, outputURL: outputURL) { exportResult in
                        switch exportResult {
                        case .success(let finalURL):
                            completion(.success(finalURL))
                        case .failure(let err):
                            completion(.failure(err))
                        }
                    }
                    return
                }
                self.synthesizer.write(next) { buffer in
                    if self.isCancelled {
                        completion(.failure(NSError(domain: "DeepWikiTTS", code: -999, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])));
                        return
                    }
                    if let pcmBuffer = buffer as? AVAudioPCMBuffer {
                        do {
                            try audioFile.write(from: pcmBuffer)
                        } catch {
                            completion(.failure(error))
                        }
                    } else if buffer is AVAudioCompressedBuffer {
                        // AVSpeechSynthesizer provides PCM buffers. Ignore otherwise.
                    }
                    if buffer.audioBufferList.pointee.mNumberBuffers == 0 {
                        processedUtterances += 1
                        progress(min(0.95, Double(processedUtterances) / Double(max(totalUtterances, 1))))
                        writeNext()
                    }
                }
            }
            writeNext()
        } catch {
            completion(.failure(TTSWriterError.cannotCreateFile))
        }
    }

    public func cancel() {
        isCancelled = true
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func exportCAFToM4A(inputURL: URL, outputURL: URL, completion: @Sendable @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: inputURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(NSError(domain: "DeepWikiTTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create exporter"])));
            return
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? NSError(domain: "DeepWikiTTS", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])) )
            default:
                break
            }
        }
    }

    private func makeUtterances(for chapter: Chapter, voiceConfig: TTSVoiceConfig) -> [AVSpeechUtterance] {
        let paragraphs = chapter.text.components(separatedBy: /\n{2,}/)
        var result: [AVSpeechUtterance] = []
        // pre-chapter pause
        let pre = AVSpeechUtterance(string: "")
        pre.preUtteranceDelay = voiceConfig.preUtteranceDelay
        result.append(pre)
        for para in paragraphs where !para.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let u = AVSpeechUtterance(string: para)
            if let identifier = voiceConfig.identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                u.voice = voice
            }
            u.rate = Float(voiceConfig.rate)
            u.pitchMultiplier = Float(voiceConfig.pitch)
            u.preUtteranceDelay = 0
            u.postUtteranceDelay = 0
            result.append(u)
        }
        // post-chapter pause
        let post = AVSpeechUtterance(string: "")
        post.postUtteranceDelay = voiceConfig.postUtteranceDelay
        result.append(post)
        return result
    }
}

