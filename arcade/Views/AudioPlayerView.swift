import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Model

@Observable
private class AudioPlayerModel {
    var player: AVPlayer?
    var isPlaying = false
    var progress: Double = 0
    var duration: Double = 0
    var isLoaded = false
    var loadError: String?
    var samples: [Float] = []
    var showSaved = false

    private var timeObserver: Any?
    private var tempFileURL: URL?

    func setup(urlString: String, autoplay: Bool) {
        let url: URL?

        if urlString.hasPrefix("data:") {
            guard let commaIdx = urlString.firstIndex(of: ",") else {
                loadError = "Invalid data URL"
                return
            }
            let base64 = String(urlString[urlString.index(after: commaIdx)...])
            guard let data = Data(base64Encoded: base64) else {
                loadError = "Failed to decode audio data"
                return
            }
            let ext = mimeExtension(from: urlString)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try? data.write(to: tempURL)
            self.tempFileURL = tempURL
            url = tempURL
        } else {
            url = URL(string: urlString)
        }

        guard let url else {
            loadError = "Invalid audio URL"
            return
        }

        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        Task {
            do {
                let dur = try await avPlayer.currentItem!.asset.load(.duration)
                self.duration = CMTimeGetSeconds(dur)
                self.isLoaded = true

                // Extract waveform samples
                await extractSamples(from: url)

                if autoplay {
                    avPlayer.play()
                    self.isPlaying = true
                }
            } catch {
                self.loadError = "Failed to load audio"
            }
        }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.duration > 0 else { return }
            self.progress = CMTimeGetSeconds(time) / self.duration
            if self.progress >= 1.0 {
                self.isPlaying = false
                self.progress = 1.0
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            if progress >= 1.0 {
                player.seek(to: .zero)
                progress = 0
            }
            player.play()
        }
        isPlaying.toggle()
    }

    func seekTo(_ pct: Double) {
        guard let player, duration > 0 else { return }
        let clamped = max(0, min(1, pct))
        let time = CMTime(seconds: duration * clamped, preferredTimescale: 600)
        player.seek(to: time)
        progress = clamped
    }

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil

        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
            tempFileURL = nil
        }
    }

    func save(urlString: String) {
        Task {
            let data: Data?
            if urlString.hasPrefix("data:") {
                guard let commaIdx = urlString.firstIndex(of: ",") else { return }
                let base64 = String(urlString[urlString.index(after: commaIdx)...])
                data = Data(base64Encoded: base64)
            } else if let url = URL(string: urlString) {
                data = try? await URLSession.shared.data(from: url).0
            } else {
                data = nil
            }

            guard let audioData = data else { return }

            let ext = mimeExtension(from: urlString)
            let utType = utType(for: ext)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [utType]
            panel.nameFieldStringValue = "arcade-audio-\(Int(Date().timeIntervalSince1970)).\(ext)"

            if panel.runModal() == .OK, let url = panel.url {
                try? audioData.write(to: url)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSaved = true
                }
                SoundService.confirm()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { self.showSaved = false }
                }
            }
        }
    }

    var elapsed: String {
        formatTime(duration * progress)
    }

    var total: String {
        formatTime(duration)
    }

    // MARK: - Waveform Extraction

    private func extractSamples(from url: URL) async {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }
            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let totalFrames = Int(buffer.frameLength)
            let barCount = 150
            let framesPerBar = max(1, totalFrames / barCount)

            var bars: [Float] = []
            var maxAmplitude: Float = 0.001

            for i in 0..<barCount {
                let start = i * framesPerBar
                let end = min(start + framesPerBar, totalFrames)
                var sum: Float = 0
                for j in start..<end {
                    sum += abs(channelData[j])
                }
                let avg = sum / Float(end - start)
                bars.append(avg)
                maxAmplitude = max(maxAmplitude, avg)
            }

            // Normalize
            self.samples = bars.map { $0 / maxAmplitude }
        } catch {
            // Waveform extraction failed — use empty samples (flat bar fallback)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func mimeExtension(from urlString: String) -> String {
        if urlString.hasPrefix("data:") {
            let header = String(urlString.prefix(40)).lowercased()
            if header.contains("audio/mpeg") || header.contains("audio/mp3") { return "mp3" }
            if header.contains("audio/aac") { return "aac" }
            if header.contains("audio/ogg") { return "ogg" }
            if header.contains("audio/flac") { return "flac" }
            return "wav"
        }
        if let url = URL(string: urlString) {
            let ext = url.pathExtension.lowercased()
            if !ext.isEmpty { return ext }
        }
        return "wav"
    }

    private func utType(for ext: String) -> UTType {
        switch ext {
        case "mp3": return .mp3
        case "aac": return .init("public.aac-audio") ?? .audio
        case "wav": return .wav
        case "flac": return .init("public.flac") ?? .audio
        default: return .audio
        }
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    let urlString: String
    var autoplay: Bool = true

    @State private var model = AudioPlayerModel()
    @State private var isHovering = false
    @State private var isSeeking = false
    @State private var hoverProgress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.loadError {
                // Error state
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .padding(16)
            } else if !model.isLoaded {
                // Loading state
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("Loading audio...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            } else {
                // Waveform
                waveformArea
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                // Transport
                transportBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
        .onAppear { model.setup(urlString: urlString, autoplay: autoplay) }
        .onDisappear { model.cleanup() }
    }

    // MARK: - Waveform

    private var waveformArea: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let bars = model.samples.isEmpty
                    ? Array(repeating: Float(0.15), count: 150)
                    : model.samples
                let barCount = bars.count
                let totalGap = CGFloat(barCount - 1)
                let barWidth: CGFloat = max(2, (size.width - totalGap) / CGFloat(barCount))
                let gap: CGFloat = 1
                let maxHeight = size.height
                let minHeight: CGFloat = 2

                for (i, amplitude) in bars.enumerated() {
                    let x = CGFloat(i) * (barWidth + gap)
                    let barHeight = max(minHeight, CGFloat(amplitude) * maxHeight)
                    let y = (maxHeight - barHeight) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = RoundedRectangle(cornerRadius: 1).path(in: rect)

                    let barProgress = CGFloat(i) / CGFloat(barCount)
                    let isPlayed = barProgress <= model.progress
                    let isHovered = isHovering && barProgress <= hoverProgress && !isPlayed

                    let color: Color
                    if isPlayed {
                        color = .accentColor
                    } else if isHovered {
                        color = .accentColor.opacity(0.3)
                    } else {
                        color = Color(nsColor: .separatorColor)
                    }

                    context.fill(path, with: .color(color))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isSeeking = true
                        let pct = value.location.x / geo.size.width
                        model.seekTo(pct)
                    }
                    .onEnded { _ in
                        isSeeking = false
                    }
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverProgress = location.x / geo.size.width
                case .ended:
                    isHovering = false
                }
            }
        }
        .frame(height: 48)
    }

    // MARK: - Transport

    private var transportBar: some View {
        HStack(spacing: 10) {
            // Play/Pause
            Button {
                model.togglePlayback()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(.quinary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Time
            HStack(spacing: 0) {
                Text(model.elapsed)
                    .foregroundStyle(.tertiary)
                Text(" / ")
                    .foregroundStyle(.secondary)
                Text(model.total)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 10, design: .monospaced))

            Spacer()

            // Save
            Button {
                model.save(urlString: urlString)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: model.showSaved ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 10))
                    Text(model.showSaved ? "Saved" : "Save")
                        .font(.system(size: 12))
                }
                .foregroundStyle(model.showSaved ? Color.green : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
