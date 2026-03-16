import SwiftUI

struct WelcomeView: View {
    @Bindable var state: AppState
    @State private var appeared = false
    @State private var letterOffsets: [CGSize] = Array(repeating: .zero, count: 6)
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
                            .font(.largeTitle.bold())
                            .fontWeight(.bold)
                            .foregroundStyle(hoveredLetter == index ? Color.accentColor : Color.primary)
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
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
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
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quinary)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: 320)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)

                // Stats
                Text("\(state.definitionLoader.endpointCount) endpoints \u{00B7} \(state.definitionLoader.providerCount) providers")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 4)

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

    private func playBounceSound() {
        SoundService.fidget()
    }
}
