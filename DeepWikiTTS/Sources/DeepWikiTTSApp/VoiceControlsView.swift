import SwiftUI
import AVFoundation
import DeepWikiTTS

struct VoiceControlsView: View {
    @Binding var voiceConfig: TTSVoiceConfig
    @State private var voices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Voice", selection: bindingVoiceId) {
                Text("System Default").tag("")
                ForEach(voices, id: \.identifier) { v in
                    Text("\(v.name) (\(v.language))").tag(v.identifier)
                }
            }
            HStack {
                Text("Rate")
                Slider(value: bindingRate, in: 0.1...0.9)
                Text(String(format: "%.2f", voiceConfig.rate)).frame(width: 44)
            }
            HStack {
                Text("Pitch")
                Slider(value: bindingPitch, in: 0.5...2.0)
                Text(String(format: "%.2f", voiceConfig.pitch)).frame(width: 44)
            }
        }
        .onAppear { voices = AVSpeechSynthesisVoice.speechVoices() }
    }

    private var bindingVoiceId: Binding<String> {
        Binding<String>(
            get: { voiceConfig.identifier ?? "" },
            set: { id in voiceConfig = TTSVoiceConfig(identifier: id.isEmpty ? nil : id, rate: voiceConfig.rate, pitch: voiceConfig.pitch, preUtteranceDelay: voiceConfig.preUtteranceDelay, postUtteranceDelay: voiceConfig.postUtteranceDelay) }
        )
    }

    private var bindingRate: Binding<Double> {
        Binding<Double>(
            get: { voiceConfig.rate },
            set: { r in voiceConfig = TTSVoiceConfig(identifier: voiceConfig.identifier, rate: r, pitch: voiceConfig.pitch, preUtteranceDelay: voiceConfig.preUtteranceDelay, postUtteranceDelay: voiceConfig.postUtteranceDelay) }
        )
    }

    private var bindingPitch: Binding<Double> {
        Binding<Double>(
            get: { voiceConfig.pitch },
            set: { p in voiceConfig = TTSVoiceConfig(identifier: voiceConfig.identifier, rate: voiceConfig.rate, pitch: p, preUtteranceDelay: voiceConfig.preUtteranceDelay, postUtteranceDelay: voiceConfig.postUtteranceDelay) }
        )
    }
}

