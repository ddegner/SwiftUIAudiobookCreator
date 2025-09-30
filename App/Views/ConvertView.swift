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
          if let d = chapter.duration {
            Text(format(duration: d)).foregroundColor(.secondary)
          } else {
            if appState.isConverting { Text("Processing…").foregroundColor(.secondary) }
          }
        }
      }
      HStack {
        Button("Cancel") { appState.conversionTask?.cancel() }
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
    appState.conversionTask = Task { @MainActor in
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
        appState.book = book
        isDone = true
        appState.isConverting = false
      } catch {
        log.append("Error: \(error.localizedDescription)")
        appState.isConverting = false
      }
    }
  }

  private func revealOutput() {
    guard let book = appState.book, let dest = appState.destinationURL else { return }
    let folderName = "\(book.title) (\(book.author))"
      .replacingOccurrences(of: "[/\\:?*\"<>|]", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let outDir = dest.appendingPathComponent(folderName, isDirectory: true)
    NSWorkspace.shared.activateFileViewerSelecting([outDir])
  }

  private func format(duration: TimeInterval) -> String {
    let i = Int(duration)
    return String(format: "%02d:%02d:%02d", i/3600, (i/60)%60, i%60)
  }
}
