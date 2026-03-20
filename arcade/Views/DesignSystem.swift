import SwiftUI

// MARK: - Design Tokens

enum DS {
    // Base-4 spacing grid: 4, 8, 12, 16, 20, 24, 32, 40, 48
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // 5-tier type scale
    enum Font {
        static let caption: CGFloat = 10
        static let secondary: CGFloat = 12
        static let body: CGFloat = 13
        static let display: CGFloat = 20
        // Hero: use .largeTitle directly
    }

    // 4-tier corner radius
    enum Radius {
        static let xs: CGFloat = 2    // accent bars, tiny details
        static let sm: CGFloat = 4    // icons, small elements
        static let md: CGFloat = 6    // buttons, inputs, code blocks
        static let lg: CGFloat = 10   // cards, panels
        static let xl: CGFloat = 14   // compose box
    }

    enum Stamp {
        static let borderWidth: CGFloat = 1.5
        static let cornerRadius: CGFloat = 4
        static let fontSize: CGFloat = 10
        static let valueFontSize: CGFloat = 11
        static let labelFontSize: CGFloat = 9
        static let padding: CGFloat = 10
        static let verticalPadding: CGFloat = 4
    }
}

// MARK: - Semantic Colors

extension Color {
    // Log colors
    static let logRequest = Color.blue
    static let logResponse = Color.green
    static let logError = Color.red
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
        case .valid: return .green
        case .invalid: return .red
        case .noKey: return .red
        case .unknown: return .secondary
        case .checking: return .secondary
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

// MARK: - Provider Icon

struct ProviderIconView: View {
    let provider: String
    let displayName: String
    let iconUrl: String?
    let iconService: ProviderIconService
    var size: CGFloat = 16

    var body: some View {
        if let nsImage = iconService.icon(for: provider, iconUrl: iconUrl) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        } else {
            Text(String(displayName.prefix(1)))
                .font(.system(size: DS.Font.caption, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.quinary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}
