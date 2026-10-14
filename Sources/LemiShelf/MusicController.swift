import AppKit

struct MusicState {
    var running = false
    var playing = false
    var title = ""
    var artist = ""
    var position = 0      // segundos
    var duration = 0      // milisegundos
    var volume = 50
    var needsPermission = false
    var error = ""
}

final class MusicController: ObservableObject {
    @Published var state = MusicState()
    @Published var artwork: NSImage?
    @Published var commandError = ""
    private var lastVolSent = -100
    private var lastVolTime = Date.distantPast

    private let queue = DispatchQueue(label: "lemi.music")
    private var timer: Timer?
    private var artworkURL = ""
    private var compiled: NSAppleScript?

    private static let statusScript = """
    set sep to (ASCII character 9)
    if application "Spotify" is running then
        try
            tell application "Spotify"
                set stateText to "paused"
                if player state is playing then
                    set stateText to "playing"
                end if
                if player state is stopped then
                    set stateText to "stopped"
                end if
                set volNum to sound volume
                if stateText is "stopped" then
                    return "R" & sep & stateText & sep & (volNum as text)
                end if
                set trk to current track
                set artText to ""
                try
                    set artText to artwork url of trk
                end try
                set trackName to name of trk
                set trackArtist to artist of trk
                set posNum to (player position) as integer
                set durNum to duration of trk
                return "R" & sep & stateText & sep & (volNum as text) & sep & trackName & sep & trackArtist & sep & (posNum as text) & sep & (durNum as text) & sep & artText
            end tell
        on error errMsg number errNum
            return "E" & sep & (errNum as text) & sep & errMsg
        end try
    else
        return "N"
    end if
    """

    init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
    }

    func poll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.compiled == nil { self.compiled = NSAppleScript(source: Self.statusScript) }
            var err: NSDictionary?
            let out = self.compiled?.executeAndReturnError(&err)
            var st = MusicState()
            var art = ""
            if let err = err {
                let n = err["NSAppleScriptErrorNumber"] as? Int ?? 0
                st.needsPermission = n == -1743
                st.error = "\(n) \(err["NSAppleScriptErrorMessage"] as? String ?? "")"
            } else if let s = out?.stringValue {
                let f = s.components(separatedBy: "\t")
                if f.first == "E" {
                    st.needsPermission = f.count > 1 && f[1] == "-1743"
                    st.error = f.dropFirst().joined(separator: " ")
                }
                if f.first == "R" {
                    st.running = true
                    if f.count >= 3 {
                        st.playing = f[1] == "playing"
                        st.volume = Int(f[2]) ?? 50
                    }
                    if f.count >= 8 {
                        st.title = f[3]
                        st.artist = f[4]
                        st.position = Int(f[5]) ?? 0
                        st.duration = Int(f[6]) ?? 0
                        art = f[7]
                    }
                }
            }
            if !st.running && st.error.isEmpty {
                st.error = "v2 raw: \(out?.stringValue ?? "nil")"
            }
            DispatchQueue.main.async { self.apply(st, art: art) }
        }
    }

    private func apply(_ st: MusicState, art: String) {
        state = st
        if art != artworkURL {
            artworkURL = art
            if art.isEmpty {
                artwork = nil
            } else if let url = URL(string: art) {
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let data = data, let img = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if self?.artworkURL == art { self?.artwork = img }
                    }
                }.resume()
            }
        }
    }

    // MARK: Controles

    private func send(_ cmd: String) {
        queue.async { [weak self] in
            var err: NSDictionary?
            let src = "if application \"Spotify\" is running then tell application \"Spotify\" to \(cmd)"
            _ = NSAppleScript(source: src)?.executeAndReturnError(&err)
            let msg = err == nil ? "" : "\(err?["NSAppleScriptErrorNumber"] ?? "") \(err?["NSAppleScriptErrorMessage"] ?? "")"
            DispatchQueue.main.async {
                self?.commandError = msg
                self?.poll()
            }
        }
    }

    func playPause() {
        state.playing.toggle()
        send("playpause")
    }
    func next() { send("next track") }
    func previous() { send("previous track") }
    func setVolume(_ v: Int) {
        lastVolSent = v
        lastVolTime = Date()
        send("set sound volume to \(max(0, min(100, v)))")
    }
    // Mientras arrastras el slider: manda el volumen cada ~0.15 s
    func setVolumeLive(_ v: Int) {
        guard abs(v - lastVolSent) >= 2, Date().timeIntervalSince(lastVolTime) > 0.15 else { return }
        setVolume(v)
    }
    func seek(_ seconds: Int) { send("set player position to \(max(0, seconds))") }

    func openSpotify() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }
}
