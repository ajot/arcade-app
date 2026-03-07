import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onAppear {
                player = AVPlayer(url: url)
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
