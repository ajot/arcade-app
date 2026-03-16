import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var localURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else if isLoading {
                ProgressView("Loading video...")
                    .foregroundStyle(.secondary)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: DS.Font.display))
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.system(size: DS.Font.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .task {
            await downloadAndPlay()
        }
        .onDisappear {
            player?.pause()
            player = nil
            // Clean up temp file
            if let localURL {
                try? FileManager.default.removeItem(at: localURL)
            }
        }
    }

    private func downloadAndPlay() async {
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            let httpResponse = response as? HTTPURLResponse
            let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? ""

            // Move to a named temp file with proper extension
            let ext = contentType.contains("mp4") ? "mp4" : "mp4"
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.moveItem(at: tempURL, to: destination)

            await MainActor.run {
                self.localURL = destination
                self.player = AVPlayer(url: destination)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
