import SwiftUI
import AppKit

struct ConvertView: View {
  @EnvironmentObject private var appState: AppState
  @State private var log: [String] = []
  @State private var isDone = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ProgressView(value: appState.overallProgress)
      List(appState.book?.chapters ?? []) { chapter in
        HStack {
          Text(String(format: "%03d", chapter.index + 1)).monospacedDigit()
          Text(chapter.title)
          Spacer()
          if let d = chapter.duration { Text(format(duration: d)).foregroundColor(.secondary) }
        }
      }
      HStack {
        Button("Cancel") { /* hook up Task cancellation */ }
        Spacer()
        Button("Reveal Output") { revealOutput() }.disabled(!isDone)
      }
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(log.indices, id: \.self) { i in Text(log[i]).font(.caption).textSelection(.enabled) }
        }
      }.frame(maxHeight: 160)
    }
    .padding(20)
    .task { await startConversion() }
  }

  private func startConversion() async {
    guard let epub = appState.selectedEPUBURL, let dest = appState.destinationURL else { return }
    appState.isConverting = true
    do {
      let book = try await appState.engine.convert(
        epubURL: epub,
        settings: appState.settings,
        destination: dest
      ) { chapterIndex, progress, message in
        Task { @MainActor in
          appState.overallProgress = progress
          if !message.isEmpty { log.append(message) }
        }
      }
      await MainActor.run {
        appState.book = book
        isDone = true
        appState.isConverting = false
      }
    } catch {
      await MainActor.run {
        log.append("Error: \(error.localizedDescription)")
        appState.isConverting = false
      }
    }
  }

  private func revealOutput() {
    guard let dest = appState.destinationURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([dest])
  }

  private func format(duration: TimeInterval) -> String {
    let i = Int(duration)
    return String(format: "%02d:%02d:%02d", i/3600, (i/60)%60, i%60)
  }
}
