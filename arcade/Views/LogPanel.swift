import SwiftUI

struct LogPanel: View {
    @Bindable var state: AppState
    @State private var panelHeight: CGFloat = 200
    @State private var expandedEntries: Set<UUID> = []

    private let minHeight: CGFloat = 120
    private let maxHeight: CGFloat = 500

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandle

            // Header
            HStack(spacing: 8) {
                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    .font(.system(size: DS.Font.secondary))
                    .foregroundStyle(.secondary)
                Text("Log")
                    .font(.system(size: DS.Font.secondary, weight: .medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                if !state.logEntries.isEmpty {
                    Text("\(state.logEntries.count)")
                        .font(.system(size: DS.Font.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quinary)
                        .clipShape(Capsule())

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            state.clearLog()
                            expandedEntries.removeAll()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: DS.Font.caption))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear log")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .background(.separator)

            // Log entries
            if state.logEntries.isEmpty {
                VStack {
                    Spacer()
                    Text("No log entries yet")
                        .font(.system(size: DS.Font.secondary))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(state.logEntries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: state.logEntries.count) {
                        if let last = state.logEntries.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: panelHeight)
        .background(.bar)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xs)
                    .fill(.separator)
                    .frame(width: 36, height: 4)
                    .offset(y: -1)
            )
            .contentShape(Rectangle().size(width: 10000, height: 12))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newHeight = panelHeight - value.translation.height
                        panelHeight = max(minHeight, min(maxHeight, newHeight))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Log Row

    private func logRow(_ entry: AppState.LogEntry) -> some View {
        let isExpanded = expandedEntries.contains(entry.id)
        let hasDetail = entry.detail != nil

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // Icon
                Text(entry.kind.symbol)
                    .font(.system(size: DS.Font.secondary))
                    .frame(width: 14)

                // Timestamp
                Text(formatTimestamp(entry.timestamp))
                    .font(.system(size: DS.Font.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                // Message
                Text(entry.message)
                    .font(.system(size: DS.Font.secondary, design: .monospaced))
                    .foregroundStyle(entry.kind.color)
                    .lineLimit(isExpanded ? nil : 1)

                Spacer()

                if hasDetail {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.Font.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture {
                guard hasDetail else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    if isExpanded {
                        expandedEntries.remove(entry.id)
                    } else {
                        expandedEntries.insert(entry.id)
                    }
                }
            }

            if isExpanded, let detail = entry.detail {
                Text(detail)
                    .font(.system(size: DS.Font.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(.horizontal, 38)
                    .padding(.vertical, 6)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quinary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private func formatTimestamp(_ date: Date) -> String {
        Self.timestampFormatter.string(from: date)
    }
}

// MARK: - LogEntry Kind Extensions

extension AppState.LogEntry.Kind {
    var symbol: String {
        switch self {
        case .request: return "→"
        case .response: return "←"
        case .polling: return "⟳"
        case .success: return "✓"
        case .error: return "✗"
        }
    }

    var color: Color {
        switch self {
        case .request: return .logRequest
        case .response: return .logResponse
        case .polling: return .secondary
        case .success: return .logResponse
        case .error: return .logError
        }
    }
}
