import SwiftUI

enum ShelfTab: String, CaseIterable {
    case files, folders, music, clipboard, notes

    var icon: String {
        switch self {
        case .files: return "tray.full"
        case .folders: return "folder"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        case .notes: return "note.text"
        }
    }
}

final class AppState: ObservableObject {
    @Published var expanded: Bool
    @Published var tab: ShelfTab = .files
    @Published var autoCollapse: Bool {
        didSet { UserDefaults.standard.set(autoCollapse, forKey: "autoCollapse") }
    }
    // Medidas (se recalculan según el tamaño físico de la pantalla)
    @Published var size = CGSize(width: 300, height: 220)
    @Published var collapsedHeight: CGFloat = 40
    @Published var notchInset: CGFloat = 0
    let cornerRadius: CGFloat = 18

    var setExpandedHandler: ((Bool) -> Void)?
    private var hoverWork: DispatchWorkItem?

    init() {
        expanded = UserDefaults.standard.object(forKey: "expanded") as? Bool ?? true
        autoCollapse = UserDefaults.standard.bool(forKey: "autoCollapse")
    }

    func setExpanded(_ value: Bool) {
        setExpandedHandler?(value)
    }

    func hoverChanged(_ inside: Bool) {
        hoverWork?.cancel()
        guard autoCollapse, expanded, !inside else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.autoCollapse, self.expanded,
                  NSEvent.pressedMouseButtons == 0 else { return }
            self.setExpanded(false)
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
