import Foundation
import AVFoundation
// App-level voice selection used regardless of KokoroSwift availability
enum KokoroVoice {
    case afHeart
    case bmGeorge
}

// App-level language selection decoupled from KokoroSwift
enum TTSLanguage {
    case enUS
}

#if canImport(KokoroSwift)
import KokoroSwift

// Simple wrapper around KokoroSwift's TTS
final class TTSService {
    private let tts: KokoroTTS
    var limitHits: Int = 0

    init(modelURL: URL) {
        self.tts = KokoroTTS(modelPath: modelURL, g2p: .misaki)
    }

    // Convert KokoroSwift's float samples to an AVAudioPCMBuffer (mono, 24 kHz)
    func synthesize(_ text: String, voice: KokoroVoice = .afHeart, language: TTSLanguage = .enUS) throws -> AVAudioPCMBuffer {
        // Generate raw audio samples from Kokoro
        let samples: [Float] = try tts.generateAudio(voice: voice.kokoroSwiftVoice, language: language.kokoroSwiftLanguage, text: text)

        // Assume 24 kHz mono output; adjust if your model differs
        let sampleRate: Double = 24_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw NSError(domain: "TTS", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"]) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NSError(domain: "TTS", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate audio buffer"]) }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let dst = buffer.floatChannelData?[0] {
            samples.withUnsafeBufferPointer { src in
                dst.initialize(from: src.baseAddress!, count: samples.count)
            }
        } else {
            throw NSError(domain: "TTS", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing channel data"]) }

        return buffer
    }

    // Adaptive fallback that splits text when the Kokoro token limit is exceeded
    func synthesizeWithFallback(_ text: String,
                                voice: KokoroVoice = .afHeart,
                                language: TTSLanguage = .enUS) throws -> [AVAudioPCMBuffer] {
        // Fast path: try a single pass
        do {
            let buf = try synthesize(text, voice: voice, language: language)
            return [buf]
        } catch let err as KokoroTTS.KokoroTTSError {
            switch err {
            case .tooManyTokens:
                // Log and split adaptively
                limitHits += 1
                print("Kokoro token limit hit (chars: \(text.count)). Splitting and retrying…")
                let (left, right) = splitTextForFallback(text)
                let leftBuffers = try synthesizeWithFallback(left, voice: voice, language: language)
                let rightBuffers = try synthesizeWithFallback(right, voice: voice, language: language)
                return leftBuffers + rightBuffers
            }
        } catch {
            throw error
        }
    }

    // Try to split near a sentence boundary; otherwise split at midpoint
    private func splitTextForFallback(_ text: String) -> (String, String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return (trimmed, "") }

        let punctuation: Set<Character> = [".", "!", "?", "\n"]
        let midOffset = trimmed.count / 2
        let midIndex = trimmed.index(trimmed.startIndex, offsetBy: midOffset)

        // Search left from midpoint for a punctuation boundary
        var splitIndex: String.Index? = nil
        var i = midIndex
        while i > trimmed.startIndex {
            if punctuation.contains(trimmed[i]) {
                splitIndex = trimmed.index(after: i)
                break
            }
            i = trimmed.index(before: i)
        }

        // If not found to the left, search right from midpoint
        if splitIndex == nil {
            i = midIndex
            while i < trimmed.index(before: trimmed.endIndex) {
                if punctuation.contains(trimmed[i]) {
                    splitIndex = trimmed.index(after: i)
                    break
                }
                i = trimmed.index(after: i)
            }
        }

        // Fallback: split at the midpoint
        let idx = splitIndex ?? midIndex
        let left = String(trimmed[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let right = String(trimmed[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure we return two non-empty parts; if one is empty, split roughly in half
        if left.isEmpty || right.isEmpty {
            let halfIdx = trimmed.index(trimmed.startIndex, offsetBy: max(1, trimmed.count / 2))
            let l = String(trimmed[..<halfIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let r = String(trimmed[halfIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (l.isEmpty ? String(trimmed.prefix(1)) : l,
                    r.isEmpty ? String(trimmed.suffix(1)) : r)
        }

        return (left, right)
    }
}
#else
// Fallback TTSService that builds without KokoroSwift but throws at runtime.
final class TTSService {
    init(modelURL: URL) {}

    var limitHits: Int = 0

    func synthesize(_ text: String, voice: KokoroVoice = .afHeart, language: TTSLanguage = .enUS) throws -> AVAudioPCMBuffer {
        throw NSError(
            domain: "TTS",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "KokoroSwift not found. Add the KokoroSwift package and model to enable speech synthesis."]
        )
    }

    func synthesizeWithFallback(_ text: String, voice: KokoroVoice = .afHeart, language: TTSLanguage = .enUS) throws -> [AVAudioPCMBuffer] {
        throw NSError(
            domain: "TTS",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "KokoroSwift not found. Add the KokoroSwift package and model to enable speech synthesis."]
        )
    }
}
#endif

// Chunk long text for stable synthesis and progress updates
func chunkText(_ text: String, maxLen: Int = 1000) -> [String] {
    var out: [String] = []
    var cur = ""
    for s in text.split(separator: " ") {
        if cur.count + s.count + 1 > maxLen {
            if !cur.isEmpty { out.append(cur) }
            cur = ""
        }
        cur += (cur.isEmpty ? "" : " ") + s
    }
    if !cur.isEmpty { out.append(cur) }
    return out
}
