import SwiftUI
import QuickLookThumbnailing

struct FilesView: View {
    @ObservedObject var shelf: ShelfStore
    private let cols = [GridItem(.adaptive(minimum: 62, maximum: 80), spacing: 8)]

    var body: some View {
        if shelf.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.doc").font(.system(size: 22))
                Text("Arrastra archivos, carpetas o capturas aquí")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white.opacity(0.45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 4) {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(shelf.items) { item in
                            ItemCell(item: item, shelf: shelf)
                        }
                    }
                }
                HStack {
                    Text("\(shelf.items.count) elementos")
                    Spacer()
                    Button("Vaciar") { shelf.clear() }.buttonStyle(.plain)
                }
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct ItemCell: View {
    let item: ShelfItem
    let shelf: ShelfStore
    @State private var hover = false

    var body: some View {
        VStack(spacing: 3) {
            ThumbView(url: item.url).frame(width: 44, height: 44)
            Text(item.name)
                .font(.system(size: 9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 62)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(hover ? 0.12 : 0)))
        .overlay(alignment: .topTrailing) {
            if hover {
                Button { shelf.remove(item) } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.85))
                .padding(1)
            }
        }
        .onHover { hover = $0 }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Abrir") { NSWorkspace.shared.open(item.url) }
            Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Quitar") { shelf.remove(item) }
        }
    }
}

struct ThumbView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Image(nsImage: image ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .onAppear(perform: load)
    }

    private func load() {
        let req = QLThumbnailGenerator.Request(fileAt: url,
                                               size: CGSize(width: 96, height: 96),
                                               scale: 2,
                                               representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            if let img = rep?.nsImage {
                DispatchQueue.main.async { image = img }
            }
        }
    }
}
