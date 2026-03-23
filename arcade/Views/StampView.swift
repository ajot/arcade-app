import SwiftUI

struct StampView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let rotation: Double

    init(icon: String, label: String, value: String, color: Color = .accentColor, rotation: Double = 0) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
        self.rotation = rotation
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(-0.3)
                    .lineLimit(1)

                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .opacity(0.5)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .foregroundStyle(color)
        .background(color.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm + 4, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 4, style: .continuous))
        .rotationEffect(.degrees(rotation))
    }
}

struct StampsRow: View {
    let ttft: String?
    let speed: String?
    let tokens: String?
    let total: String?
    let ttftFast: Bool
    let speedFast: Bool

    init(ttft: String? = nil, speed: String? = nil, tokens: String? = nil, total: String? = nil,
         ttftFast: Bool = false, speedFast: Bool = false) {
        self.ttft = ttft
        self.speed = speed
        self.tokens = tokens
        self.total = total
        self.ttftFast = ttftFast
        self.speedFast = speedFast
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if let ttft {
                StampView(icon: "⏱", label: "TTFT", value: ttft, color: .purple, rotation: -1)
                    .stampAppear(delay: 0)
            }
            if let speed {
                StampView(icon: "⚡", label: "Speed", value: speed, color: .green, rotation: 0.5)
                    .stampAppear(delay: 0.08)
            }
            if let tokens {
                StampView(icon: "#", label: "Tokens", value: tokens, color: .orange, rotation: -0.5)
                    .stampAppear(delay: 0.16)
            }
            if let total {
                StampView(icon: "⏳", label: "Total", value: total, color: .blue, rotation: 1)
                    .stampAppear(delay: 0.24)
            }
        }
    }
}

struct StampAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 1.4)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(delay)) {
                    appeared = true
                }
            }
            .onDisappear {
                appeared = false
            }
    }
}

extension View {
    func stampAppear(delay: Double = 0) -> some View {
        modifier(StampAppearModifier(delay: delay))
    }
}
