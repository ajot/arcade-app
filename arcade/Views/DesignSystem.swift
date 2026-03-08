import SwiftUI

// MARK: - Colors

extension Color {
    // Background hierarchy
    static let bg950 = Color(red: 0.012, green: 0.027, blue: 0.071)   // #030712
    static let bg900 = Color(red: 0.067, green: 0.094, blue: 0.153)   // #111827
    static let bg800 = Color(red: 0.122, green: 0.161, blue: 0.216)   // #1f2937

    // Border colors
    static let border700 = Color(red: 0.216, green: 0.255, blue: 0.318) // #374151
    static let border600 = Color(red: 0.294, green: 0.333, blue: 0.388) // #4b5563

    // Text hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.827, green: 0.843, blue: 0.878)   // #d1d5db gray-300
    static let textTertiary = Color(red: 0.612, green: 0.639, blue: 0.686)    // #9ca3af gray-400
    static let textMuted = Color(red: 0.420, green: 0.447, blue: 0.502)       // #6b7280 gray-500

    // Accent
    static let accent = Color(red: 0.961, green: 0.620, blue: 0.043)    // #f59e0b amber-500
    static let accentSubtle = Color(red: 0.961, green: 0.620, blue: 0.043).opacity(0.1)

    // Semantic
    static let success = Color(red: 0.086, green: 0.635, blue: 0.412)   // #16a34a green-600
    static let error = Color(red: 0.937, green: 0.267, blue: 0.267)     // #ef4444 red-500

    // Log colors
    static let logRequest = Color(red: 0.376, green: 0.647, blue: 0.980)  // #60a5fa
    static let logResponse = Color(red: 0.204, green: 0.827, blue: 0.600) // #34d399
    static let logError = Color(red: 0.973, green: 0.443, blue: 0.443)    // #f87171
}

// MARK: - Typography

extension Font {
    static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let brand = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let brandLarge = Font.system(size: 48, weight: .bold, design: .monospaced)
    static let brandSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let codeOutput = Font.system(size: 11, weight: .regular, design: .monospaced)

    static let bodyLabel = Font.system(size: 13, weight: .medium)
    static let bodySmall = Font.system(size: 12)
    static let caption = Font.system(size: 11)
    static let tiny = Font.system(size: 10)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.bg900.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.border700.opacity(0.5), lineWidth: 0.5)
            )
    }
}

struct InputFieldStyle: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 13))
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.bg900)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFocused ? Color.accent : Color.border700, lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isGenerating: Bool = false
    var glowIntensity: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isGenerating ? Color.textMuted : Color.bg950)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isGenerating ? Color.bg800 : Color.accent)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(glowIntensity * 0.15))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isGenerating
                            ? Color.accent.opacity(glowIntensity * 0.8)
                            : Color.white.opacity(glowIntensity * 0.4),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.bg800.opacity(0.5))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.border700.opacity(0.3), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func inputFieldStyle(isFocused: Bool = false) -> some View {
        modifier(InputFieldStyle(isFocused: isFocused))
    }
}

// MARK: - Output Type Icons

extension OutputType {
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Key Status Display

extension AppState.KeyStatus {
    var color: Color {
        switch self {
        case .valid: return .success
        case .invalid: return .error
        case .noKey: return .textMuted
        case .unknown: return .textTertiary
        case .checking: return .textMuted
        }
    }

    var iconName: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        case .noKey: return "key"
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.trianglehead.2.counterclockwise"
        }
    }
}
