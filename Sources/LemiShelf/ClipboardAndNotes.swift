import SwiftUI
import AppKit

struct ClipEntry: Identifiable {
    let id = UUID()
    let text: String
    let date: Date
}

// Historial en memoria (no se guarda en disco, por privacidad).
final class ClipboardStore: ObservableObject {
    @Published var entries: [ClipEntry] = []
    private var last = NSPasteboard.general.changeCount
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in self?.check() }
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != last else { return }
        last = pb.changeCount
        let types = pb.types?.map { $0.rawValue } ?? []
        // Gestores de contraseñas marcan lo que copian como oculto/transitorio.
        if types.contains("org.nspasteboard.ConcealedType") || types.contains("org.nspasteboard.TransientType") { return }
        guard let s = pb.string(forType: .string),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        insert(s)
    }

    private func insert(_ s: String) {
        entries.removeAll { $0.text == s }
        entries.insert(ClipEntry(text: s, date: Date()), at: 0)
        if entries.count > 25 { entries.removeLast(entries.count - 25) }
    }

    func copy(_ e: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(e.text, forType: .string)
        last = pb.changeCount
        insert(e.text)
    }
}

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardStore
    @State private var flashed: UUID?

    var body: some View {
        if clipboard.entries.isEmpty {
            Text("Lo que copies aparecerá aquí")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(clipboard.entries) { e in
                        Button {
                            clipboard.copy(e)
                            flashed = e.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { flashed = nil }
                        } label: {
                            HStack {
                                Text(e.text)
                                    .font(.system(size: 10))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                if flashed == e.id {
                                    Image(systemName: "checkmark").font(.system(size: 9))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct NotesView: View {
    @AppStorage("lemi.notes") private var notes = ""

    var body: some View {
        TextEditor(text: $notes)
            .font(.system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
