import SwiftUI

struct ComparisonTabs: View {
    @Bindable var state: AppState
    @State private var pickerTabIndex: Int? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                tabButton(tab, index: index)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    state.addTab()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
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

                Button {
                    pickerTabIndex = index
                } label: {
                    Text(tab.model)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 1)
                        .background(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { pickerTabIndex == index },
                    set: { if !$0 { pickerTabIndex = nil } }
                ), arrowEdge: .bottom) {
                    ModelPicker(
                        state: state,
                        onSelect: { def, model in
                            state.updateTabModel(at: index, definition: def, model: model)
                            pickerTabIndex = nil
                        },
                        onDismiss: {
                            pickerTabIndex = nil
                        }
                    )
                }

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
                    .opacity(isActive ? 0.8 : 0.3)
                }
            }
            .font(.system(size: DS.Font.secondary))
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
