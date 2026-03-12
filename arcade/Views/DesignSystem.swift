import SwiftUI

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
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Text(String(displayName.prefix(1)))
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 3))
        }
    }
}
