import AVFoundation
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @State private var voices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
  @State private var advanced = false
  @State private var navigating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Voice", selection: Binding(
        get: { appState.settings.voiceID ?? voices.first?.identifier },
        set: { appState.settings.voiceID = $0 }
      )) {
        ForEach(voices, id: \.identifier) { v in
          Text("\(v.name) — \(v.language)").tag(Optional(v.identifier))
        }
      }

      HStack {
        Text("Rate")
        Slider(value: Binding(
          get: { Double(appState.settings.rate) },
          set: { appState.settings.rate = Float($0) }
        ), in: 0.5...1.5)
        Text(String(format: "%.2f", appState.settings.rate)).monospacedDigit()
      }

      HStack {
        Text("Pitch")
        Slider(value: Binding(
          get: { Double(appState.settings.pitch) },
          set: { appState.settings.pitch = Float($0) }
        ), in: 0.5...1.5)
        Text(String(format: "%.2f", appState.settings.pitch)).monospacedDigit()
      }

      DisclosureGroup(isExpanded: $advanced) {
        HStack {
          Text("Chunk Size (chars)")
          Slider(value: Binding(
            get: { Double(appState.settings.chunkChars) },
            set: { appState.settings.chunkChars = Int($0) }
          ), in: 600...2400, step: 100)
          Text("\(appState.settings.chunkChars)").monospacedDigit()
        }
      } label: {
        Text("Advanced")
      }

      HStack {
        Spacer()
        Button("Convert…") { navigating = true }
      }
    }
    .padding(20)
    .frame(minWidth: 640)
    .sheet(isPresented: $navigating) {
      ConvertView()
        .environmentObject(appState)
    }
  }
}
