import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var path: String
    var added = Date()
    var owned: Bool   // true = copia que vive en la carpeta de la app

    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

final class ShelfStore: ObservableObject {
    @Published var items: [ShelfItem] = []
    private let dir: URL
    private var indexURL: URL { dir.appendingPathComponent("items.json") }
    private var filesDir: URL { dir.appendingPathComponent("files", isDirectory: true) }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("LemiShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = decoded.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: Agregar

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    } else if let ns = item as? NSURL {
                        url = ns as URL
                    }
                    if let url = url {
                        DispatchQueue.main.async { self.add(url: url) }
                    }
                }
            } else if p.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
                    if let img = obj as? NSImage {
                        DispatchQueue.main.async { self.add(image: img) }
                    }
                }
            }
        }
        return handled
    }

    func add(url: URL) {
        var finalURL = url
        var owned = false
        if isTemporary(url), let copy = copyIntoStorage(url) {
            finalURL = copy
            owned = true
        }
        guard !items.contains(where: { $0.path == finalURL.path }) else { return }
        items.insert(ShelfItem(path: finalURL.path, owned: owned), at: 0)
        save()
    }

    func add(image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let dest = uniqueDest("Imagen \(f.string(from: Date())).png")
        do {
            try png.write(to: dest)
            items.insert(ShelfItem(path: dest.path, owned: true), at: 0)
            save()
        } catch {}
    }

    // MARK: Quitar

    func remove(_ item: ShelfItem) {
        if item.owned { try? FileManager.default.removeItem(at: item.url) }
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        for i in items where i.owned { try? FileManager.default.removeItem(at: i.url) }
        items.removeAll()
        save()
    }

    // MARK: Utilidades

    // Capturas flotantes y cosas de apps suelen venir de carpetas temporales que se borran solas.
    private func isTemporary(_ url: URL) -> Bool {
        let p = url.resolvingSymlinksInPath().path
        return p.hasPrefix("/private/var/folders") || p.hasPrefix("/private/tmp")
    }

    private func copyIntoStorage(_ url: URL) -> URL? {
        let dest = uniqueDest(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    private func uniqueDest(_ name: String) -> URL {
        var dest = filesDir.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            n += 1
            dest = filesDir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
        }
        return dest
    }
}
