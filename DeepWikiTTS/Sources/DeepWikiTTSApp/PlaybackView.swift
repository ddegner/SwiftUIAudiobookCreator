import SwiftUI
import AVFoundation

final class PlayerModel: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    private var player: AVPlayer?
    private var timeObserver: Any?

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        addObserver()
    }

    func playPause() {
        guard let player = player else { return }
        if isPlaying { player.pause(); isPlaying = false }
        else { player.play(); isPlaying = true }
    }

    func addObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return }
            self.progress = min(max(time.seconds / duration, 0), 1)
        }
    }
}

struct PlaybackView: View {
    @StateObject private var pm = PlayerModel()
    let fileURL: URL

    var body: some View {
        HStack(spacing: 12) {
            Button(pm.isPlaying ? "Pause" : "Play") { pm.playPause() }
            ProgressView(value: pm.progress)
        }
        .onAppear { pm.load(url: fileURL) }
    }
}

