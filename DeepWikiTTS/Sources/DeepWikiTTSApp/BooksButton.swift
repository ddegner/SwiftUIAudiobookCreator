import SwiftUI
import DeepWikiTTS

struct BooksButton: View {
    let fileURL: URL
    @State private var failed = false

    var body: some View {
        HStack {
            Button("Open in Books") {
                let ok = BooksIntegration.openInBooks(url: fileURL)
                failed = !ok
            }
            if failed {
                Text("If not imported, open Books → File → Import…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

