import SwiftUI
import UniformTypeIdentifiers

struct FolderEntry: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
}

final class FoldersModel: ObservableObject {
    @Published var entries: [FolderEntry] = []
    let root = Config.foldersURL
    private var watcher: DispatchSourceFileSystemObject?

    init() {
        reload()
        startWatching()
    }

    deinit { watcher?.cancel() }

    // Se actualiza solo cuando algo entra, sale o cambia de nombre en la carpeta.
    private func startWatching() {
        let fd = open(root.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                            eventMask: [.write, .delete, .rename, .link],
                                                            queue: .main)
        src.setEventHandler { [weak self] in self?.reload() }
        src.setCancelHandler { close(fd) }
        src.resume()
        watcher = src
    }

    func reload() {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let items = (try? FileManager.default.contentsOfDirectory(at: root,
                                                                  includingPropertiesForKeys: keys,
                                                                  options: [.skipsHiddenFiles])) ?? []
        entries = items
            .filter {
                let v = try? $0.resourceValues(forKeys: Set(keys))
                return v?.isDirectory == true && v?.isPackage != true
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { FolderEntry(url: $0) }
    }

    // Copia (no mueve) el archivo soltado dentro de la carpeta.
    func copy(_ file: URL, into folder: URL) {
        let fm = FileManager.default
        var dest = folder.appendingPathComponent(file.lastPathComponent)
        let base = (file.lastPathComponent as NSString).deletingPathExtension
        let ext = (file.lastPathComponent as NSString).pathExtension
        var n = 1
        while fm.fileExists(atPath: dest.path) {
            n += 1
            dest = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
        }
        try? fm.copyItem(at: file, to: dest)
    }
}

struct FoldersView: View {
    @StateObject private var model = FoldersModel()
    private let cols = [GridItem(.adaptive(minimum: 62, maximum: 80), spacing: 8)]

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button { NSWorkspace.shared.open(model.root) } label: {
                    Label(model.root.lastPathComponent, systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
            }
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.7))

            if model.entries.isEmpty {
                Text("No hay carpetas aquí (o falta permiso de acceso)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(model.entries) { e in
                            FolderCell(entry: e, model: model)
                        }
                    }
                }
            }
        }
        .onAppear { model.reload() }
    }
}

struct FolderCell: View {
    let entry: FolderEntry
    let model: FoldersModel
    @State private var targeted = false
    @State private var hover = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            Text(entry.name)
                .font(.system(size: 9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 62)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(targeted ? 0.3 : (hover ? 0.12 : 0))))
        .onHover { hover = $0 }
        .overlay(CopyDragSource(url: entry.url, onClick: { NSWorkspace.shared.open(entry.url) }))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            for p in providers {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let u = item as? URL { url = u }
                    if let url = url { DispatchQueue.main.async { model.copy(url, into: entry.url) } }
                }
            }
            return true
        }
    }
}

// Arrastrar hacia afuera = COPIA (nunca mueve el original). Un clic sin arrastrar = abrir.
struct CopyDragSource: NSViewRepresentable {
    let url: URL
    var onClick: () -> Void

    func makeNSView(context: Context) -> DragNSView {
        let v = DragNSView()
        v.url = url
        v.onClick = onClick
        return v
    }

    func updateNSView(_ v: DragNSView, context: Context) {
        v.url = url
        v.onClick = onClick
    }
}

final class DragNSView: NSView, NSDraggingSource {
    var url: URL?
    var onClick: (() -> Void)?
    private var downPoint: NSPoint?
    private var dragStarted = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted, let url = url, let start = downPoint else { return }
        let p = event.locationInWindow
        if hypot(p.x - start.x, p.y - start.y) < 4 { return }
        dragStarted = true
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let local = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(NSRect(x: local.x - 24, y: local.y - 24, width: 48, height: 48), contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !dragStarted { onClick?() }
        downPoint = nil
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
