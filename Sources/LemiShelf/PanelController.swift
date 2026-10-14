import AppKit
import SwiftUI
import Combine

final class NotchPanel: NSPanel {
    // Solo puede recibir teclado cuando hace falta escribir (pestaña Notas).
    // Si no, cada tecla que escribes en otra app suena como error.
    var allowKey = false
    override var canBecomeKey: Bool { allowKey }
    override var canBecomeMain: Bool { false }
}

final class PanelController {
    let state = AppState()
    let shelf = ShelfStore()
    let music = MusicController()
    let clipboard = ClipboardStore()
    private var panel: NotchPanel!
    private var collapseWork: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    private var screen: NSScreen {
        NSScreen.screens.first ?? NSScreen.main!
    }

    func start() {
        updateMetrics()
        panel = NotchPanel(contentRect: frame(expanded: state.expanded),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let root = RootView(state: state, shelf: shelf, music: music, clipboard: clipboard)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host

        state.setExpandedHandler = { [weak self] in self?.setExpanded($0) }
        state.$tab
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tab in
                guard let self = self else { return }
                self.panel.allowKey = (tab == .notes)
                if tab != .notes && self.panel.isKeyWindow { self.panel.resignKey() }
            }
            .store(in: &cancellables)
        panel.setFrame(frame(expanded: state.expanded), display: true)
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.updateMetrics()
            self.panel.setFrame(self.frame(expanded: self.state.expanded), display: true)
        }
    }

    // 1 cm físico = (puntos de la pantalla / mm de la pantalla) * 10
    private func updateMetrics() {
        let scr = screen
        var pointsPerMM = 72.0 / 25.4
        if let id = scr.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            let mm = CGDisplayScreenSize(id)
            if mm.width > 0 {
                let v = Double(scr.frame.width) / Double(mm.width)
                if v > 2.0 && v < 8.0 { pointsPerMM = v }
            }
        }
        let cm = CGFloat(pointsPerMM) * 10
        state.size = CGSize(width: 7 * cm, height: 5 * cm)
        state.collapsedHeight = 1 * cm
        state.notchInset = scr.safeAreaInsets.top
    }

    private func frame(expanded: Bool) -> NSRect {
        let w = state.size.width
        let h = expanded ? state.size.height : state.collapsedHeight
        let f = screen.frame
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    // Al expandir: primero crece la ventana (transparente) y luego anima el dibujo.
    // Al contraer: primero anima el dibujo y luego encoge la ventana.
    private func setExpanded(_ value: Bool) {
        collapseWork?.cancel()
        UserDefaults.standard.set(value, forKey: "expanded")
        if value {
            panel.setFrame(frame(expanded: true), display: true)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self.state.expanded = true }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { state.expanded = false }
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, !self.state.expanded else { return }
                self.panel.setFrame(self.frame(expanded: false), display: true)
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }
}
