import SwiftUI

struct BookOverviewView: View {
  @EnvironmentObject private var appState: AppState
  @State private var editedTitles: [UUID: String] = [:]
  @State private var showingSettings = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        if let cover = appState.book?.cover {
          Image(nsImage: cover)
            .resizable()
            .frame(width: 120, height: 160)
            .cornerRadius(6)
        }
        VStack(alignment: .leading) {
          Text(appState.book?.title ?? "Untitled")
            .font(.title)
          Text(appState.book?.author ?? "Unknown")
            .foregroundColor(.secondary)
        }
        Spacer()
      }

      List {
        ForEach(appState.book?.chapters ?? []) { chapter in
          HStack {
            Text(String(format: "%03d", chapter.index + 1))
              .monospacedDigit()
              .frame(width: 40, alignment: .trailing)
            TextField("Chapter Title", text: Binding(
              get: { editedTitles[chapter.id] ?? chapter.title },
              set: { editedTitles[chapter.id] = $0 }
            ))
          }
        }
      }

      HStack {
        Button("Choose Output Folder…") {
          OpenPanelHelpers.selectFolder { url in
            appState.destinationURL = url
          }
        }
        if let dest = appState.destinationURL {
          Text(dest.path)
            .foregroundColor(.secondary)
        }
        Spacer()
        Button("Next") { showingSettings = true }
          .disabled(appState.destinationURL == nil)
      }
    }
    .padding(20)
    .frame(minWidth: 720, minHeight: 520)
    .sheet(isPresented: $showingSettings) {
      SettingsView()
        .environmentObject(appState)
    }
  }
}
