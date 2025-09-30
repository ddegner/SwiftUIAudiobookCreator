import AVFoundation
import Foundation

final class TTSWriter: ChapterSynthesizing {
  func synthesize(
    chunks: [String],
    voiceID: String?,
    rate: Float,
    pitch: Float,
    to outURL: URL
  ) async throws -> TimeInterval {
    let targetSampleRate: Double = 44100
    let targetFormat = AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: 1)!

    // Temp PCM container
    let tmpPCM = outURL.deletingPathExtension().appendingPathExtension("caf")
    if FileManager.default.fileExists(atPath: tmpPCM.path) {
      try FileManager.default.removeItem(at: tmpPCM)
    }
    guard let audioFile = try? AVAudioFile(forWriting: tmpPCM, settings: targetFormat.settings) else {
      throw NSError(domain: "TTSWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open temp audio file"])
    }

    let synthesizer = AVSpeechSynthesizer()
    let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
    var totalFrames: AVAudioFramePosition = 0
    var converter = ConverterCache(targetFormat: targetFormat)
    let writeQueue = DispatchQueue(label: "tts.writer.write")

    let delegate = SynthDelegate()
    synthesizer.delegate = delegate

    for text in chunks where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      try Task.checkCancellation()

      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
      utterance.pitchMultiplier = pitch

      let semaphore = DispatchSemaphore(value: 0)
      delegate.onFinish = { semaphore.signal() }

      synthesizer.write(utterance) { buffer in
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        writeQueue.sync {
          do {
            let converted = try converter.convert(buffer: pcm)
            try audioFile.write(from: converted)
            totalFrames += AVAudioFramePosition(converted.frameLength)
          } catch {
            // Intentionally ignore per-buffer errors; fail at export if critical
          }
        }
      }

      _ = semaphore.wait(timeout: .now() + 600)
    }

    // Export PCM to M4A
    do {
      try await exportCAFToM4A(cafURL: tmpPCM, m4aURL: outURL)
      let duration = Double(totalFrames) / targetSampleRate
      try? FileManager.default.removeItem(at: tmpPCM)
      return duration
    } catch {
      try? FileManager.default.removeItem(at: tmpPCM)
      throw error
    }
  }
}

private final class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate {
  var onFinish: (() -> Void)?
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    onFinish?()
  }
}

private struct ConverterCache {
  let targetFormat: AVAudioFormat
  private var converter: AVAudioConverter?

  init(targetFormat: AVAudioFormat) { self.targetFormat = targetFormat }

  mutating func convert(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
    if converter == nil {
      converter = AVAudioConverter(from: buffer.format, to: targetFormat)
    }
    guard let converter else {
      throw NSError(domain: "TTSWriter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Converter init failed"]) }

    let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate) + 1024
    guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
      throw NSError(domain: "TTSWriter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Out buffer alloc failed"]) }

    var error: NSError?
    let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
      outStatus.pointee = .haveData
      return buffer
    }
    if status == .error { throw error ?? NSError(domain: "TTSWriter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Conversion error"]) }
    return outBuffer
  }
}

private func exportCAFToM4A(cafURL: URL, m4aURL: URL) async throws {
  if FileManager.default.fileExists(atPath: m4aURL.path) { try FileManager.default.removeItem(at: m4aURL) }
  let asset = AVAsset(url: cafURL)
  guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
    throw NSError(domain: "TTSWriter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Export session failed"]) }
  exporter.outputURL = m4aURL
  exporter.outputFileType = .m4a
  await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
    exporter.exportAsynchronously { cont.resume() }
  }
  if let error = exporter.error { throw error }
}
