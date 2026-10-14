import Foundation

// Carpeta cuyas subcarpetas se muestran en la pestaña "Carpetas".
// Cámbiala por la tuya, por ejemplo "~/Documents/Proyectos".
enum Config {
    static let foldersPath = "~/Desktop"

    static var foldersURL: URL {
        URL(fileURLWithPath: (foldersPath as NSString).expandingTildeInPath, isDirectory: true)
    }
}
