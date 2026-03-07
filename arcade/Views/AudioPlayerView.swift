import AVFoundation
import SwiftUI

struct AudioPlayerView: View {
    let urlString: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accent)
                    .frame(width: 32, height: 32)
                    .background(Color.bg800)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.border700)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accent)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let pct = max(0, min(1, value.location.x / geo.size.width))
                            seekTo(pct)
                        }
                )
            }
            .frame(height: 32)

            // Duration
            Text(formatTime(duration * progress))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.textMuted)
                .frame(width: 36)
        }
        .padding(12)
        .background(Color.bg900.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.border700.opacity(0.3), lineWidth: 0.5)
        )
        .onAppear { setupPlayer() }
        .onDisappear { cleanup() }
    }

    private func setupPlayer() {
        let url: URL?
        if urlString.hasPrefix("data:") {
            // Data URL — write to temp file
            guard let commaIdx = urlString.firstIndex(of: ",") else { return }
            let base64 = String(urlString[urlString.index(after: commaIdx)...])
            guard let data = Data(base64Encoded: base64) else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            try? data.write(to: tempURL)
            url = tempURL
        } else {
            url = URL(string: urlString)
        }

        guard let url else { return }
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Get duration
        Task {
            if let dur = try? await avPlayer.currentItem?.asset.load(.duration) {
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(dur)
                }
            }
        }

        // Time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard duration > 0 else { return }
            progress = CMTimeGetSeconds(time) / duration
            if progress >= 1.0 {
                isPlaying = false
            }
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            if progress >= 1.0 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func seekTo(_ pct: Double) {
        guard let player, duration > 0 else { return }
        let time = CMTime(seconds: duration * pct, preferredTimescale: 600)
        player.seek(to: time)
        progress = pct
    }

    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
