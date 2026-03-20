import SwiftUI

struct StampView: View {
    let icon: String
    let label: String
    let value: String
    let isFast: Bool
    let rotation: Double

    init(icon: String, label: String, value: String, isFast: Bool = false, rotation: Double = 0) {
        self.icon = icon
        self.label = label
        self.value = value
        self.isFast = isFast
        self.rotation = rotation
    }

    private var stampColor: Color {
        isFast ? .green : Color.accentColor
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(icon)
                .font(.system(size: DS.Stamp.fontSize))
                .opacity(0.8)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: DS.Stamp.labelFontSize, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .opacity(0.6)

                Text(value)
                    .font(.system(size: DS.Stamp.valueFontSize, weight: .semibold, design: .monospaced))
            }
        }
        .padding(.horizontal, DS.Stamp.padding)
        .padding(.vertical, DS.Stamp.verticalPadding)
        .foregroundStyle(stampColor)
        .background(stampColor.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Stamp.cornerRadius)
                .strokeBorder(stampColor, style: StrokeStyle(lineWidth: DS.Stamp.borderWidth, dash: [4, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Stamp.cornerRadius))
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
        HStack(spacing: DS.Spacing.sm + 2) {
            if let ttft {
                StampView(icon: "⏱", label: "TTFT", value: ttft, isFast: ttftFast, rotation: -1.5)
                    .stampAppear(delay: 0)
            }
            if let speed {
                StampView(icon: "⚡", label: "Speed", value: speed, isFast: speedFast, rotation: 1.0)
                    .stampAppear(delay: 0.08)
            }
            if let tokens {
                StampView(icon: "🎯", label: "Tokens", value: tokens, rotation: -0.8)
                    .stampAppear(delay: 0.16)
            }
            if let total {
                StampView(icon: "⏲", label: "Total", value: total, rotation: 1.8)
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
    }
}

extension View {
    func stampAppear(delay: Double = 0) -> some View {
        modifier(StampAppearModifier(delay: delay))
    }
}
