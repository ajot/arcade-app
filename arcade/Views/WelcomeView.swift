import SwiftUI

struct WelcomeView: View {
    @Bindable var state: AppState
    @State private var appeared = false
    @State private var letterOffsets: [CGSize] = Array(repeating: .zero, count: 6)
    @State private var letterVelocities: [CGSize] = Array(repeating: .zero, count: 6)
    @State private var hoveredLetter: Int?
    @State private var waveTriggered = false

    private let letters = Array("arcade")
    private let springResponse: Double = 0.4
    private let springDamping: Double = 0.5

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Fidgetable title
                HStack(spacing: 2) {
                    ForEach(0..<letters.count, id: \.self) { index in
                        Text(String(letters[index]))
                            .font(.brandLarge)
                            .fontWeight(.bold)
                            .foregroundStyle(hoveredLetter == index ? Color.accent : Color.textPrimary)
                            .offset(letterOffsets[index])
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        letterOffsets[index] = value.translation
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                                            letterOffsets[index] = .zero
                                        }
                                        playBounceSound()
                                    }
                            )
                            .onHover { hovering in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hoveredLetter = hovering ? index : nil
                                }
                                if hovering {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                                        letterOffsets[index] = CGSize(width: 0, height: -4)
                                    }
                                } else {
                                    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                                        letterOffsets[index] = .zero
                                    }
                                }
                            }
                            .scaleEffect(hoveredLetter == index ? 1.08 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: hoveredLetter)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                // Subtitle
                Text("An AI playground for every provider")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textTertiary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                // CTA Button
                Button {
                    state.showCommandPalette = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                        Text("Select an endpoint...")
                            .font(.system(size: 13))
                        Spacer()
                        Text("\u{2318}K")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.bg800)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: 320)
                    .background(Color.bg900)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.border700, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // Stats
                Text("\(state.definitionLoader.endpointCount) endpoints \u{00B7} \(state.definitionLoader.providerCount) providers")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 4)

                // Recent bookmarks
                if !state.bookmarkStore.recentBookmarks.isEmpty {
                    recentBookmarks
                        .padding(.top, 12)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 4)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
            // Wave animation after fade-in
            if !waveTriggered {
                waveTriggered = true
                for i in 0..<letters.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.08) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            letterOffsets[i] = CGSize(width: 0, height: -12)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                                letterOffsets[i] = .zero
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Bookmarks

    @State private var hoveredBookmark: UUID?

    private var recentBookmarks: some View {
        VStack(spacing: 8) {
            Text("Recent Bookmarks")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 10) {
                ForEach(Array(state.bookmarkStore.recentBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    let isHovered = hoveredBookmark == bookmark.id
                    let tilt = cardTilt(for: index)
                    let definition = state.definitionLoader.sortedDefinitions.first { $0.id == bookmark.definitionId }

                    Button {
                        state.loadBookmark(bookmark)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: definition?.outputType.iconName ?? "text.alignleft")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.accent)
                                Text(bookmark.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                            }

                            if let def = definition {
                                Text(def.providerDisplayName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.textMuted)
                                    .lineLimit(1)
                            }

                            Text(timeAgo(bookmark.createdAt))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.textMuted.opacity(0.7))
                        }
                        .frame(width: 130, alignment: .leading)
                        .padding(10)
                        .background(Color.bg900)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isHovered ? Color.accent.opacity(0.4) : Color.border700.opacity(0.5), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(isHovered ? 0.3 : 0.1), radius: isHovered ? 8 : 2, y: isHovered ? 4 : 1)
                        .rotationEffect(.degrees(isHovered ? 0 : tilt))
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                        .offset(y: isHovered ? -3 : 0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            hoveredBookmark = hovering ? bookmark.id : nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private func cardTilt(for index: Int) -> Double {
        let tilts = [-2.0, 1.5, -1.0]
        return tilts[index % tilts.count]
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "yesterday" }
        if days < 30 { return "\(days)d ago" }
        return "\(days / 30)mo ago"
    }

    private func playBounceSound() {
        SoundService.fidget()
    }
}
