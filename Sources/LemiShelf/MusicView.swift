import SwiftUI

struct MusicView: View {
    @ObservedObject var music: MusicController
    @State private var seek: Double = 0
    @State private var seeking = false
    @State private var vol: Double = 50
    @State private var changingVol = false

    // Curva: el volumen de Spotify es lineal, pero el oído es logarítmico.
    // Con exponente < 1 la parte baja de la barra sí se escucha. Ajusta 0.6 si hace falta.
    private let curve = 0.6
    private func toVolume(_ slider: Double) -> Int {
        Int((100 * pow(max(0, min(100, slider)) / 100, curve)).rounded())
    }
    private func toSlider(_ volume: Int) -> Double {
        100 * pow(Double(max(0, min(100, volume))) / 100, 1 / curve)
    }

    var body: some View {
        let s = music.state
        if !s.running {
            VStack(spacing: 8) {
                Image(systemName: "music.note").font(.system(size: 22))
                Text(s.needsPermission
                     ? "Falta permiso: Ajustes del Sistema → Privacidad y seguridad → Automatización → activa Spotify para blacktrack"
                     : "Spotify no está abierto")
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                if !s.error.isEmpty {
                    Text(s.error)
                        .font(.system(size: 8))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }
                Button("Abrir Spotify") { music.openSpotify() }
                    .controlSize(.small)
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    artworkView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title.isEmpty ? "Nada sonando" : s.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        Text(s.artist)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    Text(fmt(seeking ? Int(seek) : s.position))
                    Slider(value: Binding(get: { seeking ? seek : Double(s.position) },
                                          set: { seek = $0 }),
                           in: 0...max(Double(s.duration) / 1000, 1)) { editing in
                        if editing {
                            seek = Double(music.state.position)
                            seeking = true
                        } else {
                            music.seek(Int(seek))
                            seeking = false
                        }
                    }
                    .controlSize(.mini)
                    Text(fmt(s.duration / 1000))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 22) {
                    Button { music.previous() } label: { Image(systemName: "backward.fill") }
                    Button { music.playPause() } label: {
                        Image(systemName: s.playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 30))
                    }
                    Button { music.next() } label: { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .font(.system(size: 15))

                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill").font(.system(size: 9))
                    Slider(value: Binding(get: { changingVol ? vol : toSlider(s.volume) },
                                          set: { vol = $0; music.setVolumeLive(toVolume($0)) }),
                           in: 0...100) { editing in
                        if editing {
                            vol = toSlider(music.state.volume)
                            changingVol = true
                        } else {
                            music.setVolume(toVolume(vol))
                            changingVol = false
                        }
                    }
                    .controlSize(.mini)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 9))
                }
                .foregroundColor(.white.opacity(0.6))
                if !music.commandError.isEmpty {
                    Text(music.commandError).font(.system(size: 8)).foregroundColor(.red).lineLimit(2)
                }
            }
        }
    }

    private var artworkView: some View {
        Group {
            if let img = music.artwork {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fmt(_ t: Int) -> String {
        String(format: "%d:%02d", t / 60, t % 60)
    }
}
