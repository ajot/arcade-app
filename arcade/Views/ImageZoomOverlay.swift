import SwiftUI
import UniformTypeIdentifiers

struct ImageZoomOverlay: View {
    @Bindable var state: AppState
    @State private var appeared = false
    @State private var showSaved = false

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Image
            if let value = state.zoomedImageValue {
                zoomedImage(value)
                    .padding(48)
            }

            // Toolbar
            VStack {
                HStack {
                    Spacer()

                    // Save button
                    Button {
                        saveZoomedImage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSaved ? "checkmark" : "arrow.down.circle")
                                .font(.system(size: 12))
                            Text(showSaved ? "Saved" : "Save")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(showSaved ? Color.success : Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                Spacer()
            }
        }
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                appeared = true
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    @ViewBuilder
    private func zoomedImage(_ value: String) -> some View {
        if value.hasPrefix("data:") {
            if let data = dataFromDataURL(value),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else if let url = URL(string: value) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                case .failure:
                    Label("Failed to load image", systemImage: "photo")
                        .foregroundStyle(Color.textMuted)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            state.zoomedImageValue = nil
        }
    }

    private func saveZoomedImage() {
        guard let value = state.zoomedImageValue else { return }

        Task {
            let imageData = await loadImageData(from: value)
            guard let data = imageData,
                  let nsImage = NSImage(data: data),
                  let tiff = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "arcade-image-\(Int(Date().timeIntervalSince1970)).png"

            if panel.runModal() == .OK, let url = panel.url {
                try? pngData.write(to: url)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSaved = true
                }
                NSSound(named: "Tink")?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showSaved = false }
                }
            }
        }
    }

    private func loadImageData(from value: String) async -> Data? {
        if value.hasPrefix("data:") {
            return dataFromDataURL(value)
        } else if let url = URL(string: value) {
            return try? await URLSession.shared.data(from: url).0
        }
        return nil
    }

    private func dataFromDataURL(_ dataURL: String) -> Data? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        return Data(base64Encoded: base64)
    }
}
