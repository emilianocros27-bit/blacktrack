# blacktrack

Caja negra flotante para macOS, pegada arriba al centro de la pantalla (como un notch). Mide 7 × 5 cm reales y se contrae a una línea de 7 × 1 cm con un switch.

**Estado:** hecha y probada en un MacBook Air (macOS 13 o superior). La última tanda de cambios (pestaña de carpetas con arrastre, curva de volumen, teclado solo en Notas) no se confirmó con una compilación completa; si algo no compila, ver "Si falla".

## Qué tiene

| Pestaña | Qué hace |
|---|---|
| Archivos | Arrastras archivos, carpetas, PDFs, imágenes y capturas, y se quedan guardados. Doble clic abre. Las capturas flotantes se copian a una carpeta propia porque macOS las borra solas. |
| Carpetas | Muestra las subcarpetas de una carpeta (por defecto el Escritorio) y se actualiza sola. Clic abre. Arrastrar una carpeta hacia afuera la **copia**, no la mueve. Soltar un archivo encima de una carpeta lo copia adentro. |
| Música | Spotify: portada, título, progreso, anterior, play/pausa, siguiente y volumen. |
| Portapapeles | Últimos 25 textos copiados (en memoria, no se guarda en disco; ignora lo que copian los gestores de contraseñas). |
| Notas | Bloc rápido que se guarda solo. Es la única pestaña que recibe teclado. |

Extras: atajo `Ctrl + Opción + Espacio` para expandir/contraer, clic derecho en la caja para "Auto-contraer", "Abrir al iniciar sesión", "Vaciar estante" y "Salir".

## Requisitos

- macOS 13 o superior.
- Xcode instalado (App Store) y su licencia aceptada: `sudo xcodebuild -license accept`.
- Spotify de escritorio (solo para la pestaña de música).

## Instalar

```bash
git clone <URL-DE-ESTE-REPO> blacktrack
cd blacktrack
bash build.sh
```

`build.sh` compila, arma `build/blacktrack.app`, la firma localmente y la abre. Para que quede instalada:

```bash
cp -R build/blacktrack.app /Applications/
```

Luego abre la app desde Aplicaciones, haz clic derecho sobre la caja y activa **Abrir al iniciar sesión**.

## Permisos que macOS va a pedir

1. **Automatización → Spotify**: pulsa Permitir cuando pregunte, o actívalo en Ajustes del Sistema → Privacidad y seguridad → Automatización.
2. **Escritorio / Documentos**: solo si la pestaña de carpetas apunta a esas carpetas.

## Cambiar la carpeta de la pestaña Carpetas

Edita `Sources/LemiShelf/Config.swift` y cambia `foldersPath` (por ejemplo `"~/Documents/Proyectos"`), y vuelve a correr `bash build.sh`.

## Cambiar tamaños

En `Sources/LemiShelf/PanelController.swift`, función `updateMetrics()`: `7 * cm` de ancho, `5 * cm` de alto y `1 * cm` para la línea contraída.

## Si falla

- `permission denied: ./build.sh` → usa `bash build.sh`.
- Error de licencia de Xcode → `sudo xcodebuild -license accept`.
- Línea con `error:` al compilar → ese es el problema; pégasela a tu Claude con el archivo al que apunta.
- La música dice que Spotify no está abierto → revisa el permiso de Automatización.

## Para pegarle esto a Claude

Mira `CLAUDE.md`: ahí está el texto exacto que puedes pegar en tu Claude para que lo instale y lo deje funcionando.
