import SwiftUI

struct ComparisonTabs: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                tabButton(tab, index: index)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    state.addTab()
                }
            } label: {
                Text("+")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DS.Spacing.sm + 2)
                    .padding(.vertical, DS.Spacing.sm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tabButton(_ tab: AppState.Tab, index: Int) -> some View {
        let isActive = index == state.activeTabIndex

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                state.selectTab(index)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text("\(tab.definition.providerDisplayName) \u{00B7}")
                    .opacity(0.5)

                Text(tab.model)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 1)
                    .background(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                    .clipShape(Capsule())

                if state.tabs.count > 1 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.removeTab(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .opacity(isActive ? 1 : 0)
                }
            }
            .font(.system(size: DS.Font.secondary))
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .overlay(alignment: .bottom) {
                if isActive {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
