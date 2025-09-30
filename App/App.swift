import SwiftUI

@main
struct EpubToAudiobookApp: App {
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      ImportView()
        .environmentObject(appState)
    }
  }
}
