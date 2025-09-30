import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
  @EnvironmentObject private var appState: AppState
  @State private var showFileImporter = false
  @State private var parseError: String?

  var body: some View {
    VStack(spacing: 16) {
      Text("EPUB → Audiobook")
        .font(.largeTitle)
      Text("Import an .epub to begin")
        .foregroundColor(.secondary)
      HStack(spacing: 12) {
        Button("Choose EPUB…") { showFileImporter = true }
        Button("Open EPUB…") {
          OpenPanelHelpers.selectEPUB { url in
            guard let url else { return }
            loadBook(from: url)
          }
        }
      }
      if let error = parseError {
        Text(error).foregroundColor(.red)
      }
    }
    .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.epub]) { result in
      switch result {
      case .success(let url):
        loadBook(from: url)
      case .failure(let error):
        parseError = error.localizedDescription
      }
    }
    .padding(40)
    .frame(minWidth: 520, minHeight: 320)
    .onChange(of: appState.book) { _, newValue in
      if newValue != nil {
        // Navigate to overview
        appState.selectedEPUBURL = appState.selectedEPUBURL
      }
    }
    .sheet(item: Binding(
      get: { appState.book },
      set: { _ in }
    )) { _ in
      BookOverviewView()
        .environmentObject(appState)
    }
  }

  private func loadBook(from url: URL) {
    appState.selectedEPUBURL = url
    Task {
      do {
        let parser = EpubParser()
        let book = try parser.parse(epubURL: url)
        await MainActor.run { appState.book = book }
      } catch {
        await MainActor.run { parseError = error.localizedDescription }
      }
    }
  }
}

// shared UTType.epub now lives in Utilities
