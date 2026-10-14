import SwiftUI
import ServiceManagement

struct RootView: View {
    @ObservedObject var state: AppState
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var music: MusicController
    @ObservedObject var clipboard: ClipboardStore
    @State private var targeted = false

    var body: some View {
        box
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
    }

    private var box: some View {
        VStack(spacing: 0) {
            if state.expanded {
                expandedContent.transition(.opacity)
            } else {
                collapsedContent.transition(.opacity)
            }
        }
        .frame(width: state.size.width,
               height: state.expanded ? state.size.height : state.collapsedHeight,
               alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: state.cornerRadius, style: .continuous)
                .fill(Color.black)
                .padding(.top, -state.cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: state.cornerRadius, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(.top, -state.cornerRadius)
                .opacity(targeted ? 1 : 0)
        )
        .clipped()
        .foregroundColor(.white)
        .onDrop(of: [.fileURL, .image], isTargeted: $targeted) { providers in
            shelf.handleDrop(providers)
        }
        .onChange(of: targeted) { isTargeted in
            if isTargeted {
                state.tab = .files
                if !state.expanded { state.setExpanded(true) }
            }
        }
        .onHover { state.hoverChanged($0) }
        .contextMenu {
            Button(state.expanded ? "Contraer" : "Expandir") { state.setExpanded(!state.expanded) }
            Toggle("Auto-contraer al salir el mouse", isOn: $state.autoCollapse)
            Toggle("Abrir al iniciar sesión", isOn: launchAtLogin)
            Divider()
            Button("Vaciar estante") { shelf.clear() }
            Button("Salir") { NSApp.terminate(nil) }
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { on in
                if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
            }
        )
    }

    private var switchView: some View {
        Toggle("", isOn: Binding(get: { state.expanded }, set: { state.setExpanded($0) }))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
    }

    // MARK: Expandido

    private var expandedContent: some View {
        VStack(spacing: 6) {
            header
            Group {
                switch state.tab {
                case .files: FilesView(shelf: shelf)
                case .folders: FoldersView()
                case .music: MusicView(music: music)
                case .clipboard: ClipboardView(clipboard: clipboard)
                case .notes: NotesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, state.notchInset + 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var header: some View {
        HStack(spacing: 4) {
            ForEach(ShelfTab.allCases, id: \.self) { t in
                Button { state.tab = t } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 13))
                        .frame(width: 32, height: 24)
                        .background(state.tab == t ? Color.white.opacity(0.18) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(alignment: .topTrailing) {
                            if t == .files && !shelf.items.isEmpty {
                                Text("\(shelf.items.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 3)
                                    .background(Capsule().fill(Color.accentColor))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            switchView
        }
    }

    // MARK: Contraído (línea de 1 cm)

    private var collapsedContent: some View {
        HStack(spacing: 10) {
            if music.state.running {
                Button { music.playPause() } label: {
                    Image(systemName: music.state.playing ? "pause.fill" : "play.fill").font(.system(size: 10))
                }.buttonStyle(.plain)
                Button { music.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 10))
                }.buttonStyle(.plain)
            } else {
                Image(systemName: "tray.full").font(.system(size: 10)).opacity(0.5)
            }
            Spacer()
            switchView
        }
        .padding(.horizontal, 18)
        .padding(.top, state.notchInset)
        .frame(maxHeight: .infinity)
    }
}
