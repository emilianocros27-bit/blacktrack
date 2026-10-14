# Instrucciones para Claude: instalar blacktrack en esta Mac

Este repositorio es una app de macOS (Swift Package, SwiftUI + AppKit). El objetivo es dejarla compilada, instalada y funcionando en la Mac de la persona que te pasó este repo.

## Texto para pegar en tu Claude

> Clona este repositorio `<URL-DE-ESTE-REPO>`, lee `README.md` y `CLAUDE.md`, y déjame blacktrack instalada y funcionando en mi Mac. Avísame antes de hacer algo que cambie mi sistema (licencia de Xcode, copiar a Aplicaciones, activar inicio automático). Háblame en español, paso a paso, y dime qué debo ver en pantalla en cada etapa.

## Qué debes hacer

1. Comprobar que es macOS 13+ (`sw_vers`) y que hay Xcode (`xcodebuild -version`). Si falta la licencia, pedirle a la persona que ejecute `sudo xcodebuild -license accept` (necesita su contraseña; no la pidas en el chat).
2. Preguntar qué carpeta quiere ver en la pestaña "Carpetas" (por defecto `~/Desktop`) y, si es otra, cambiar `foldersPath` en `Sources/LemiShelf/Config.swift`.
3. Ejecutar `bash build.sh` desde la raíz del repo. Si compila, se abre sola la caja negra arriba al centro.
4. Si hay errores de compilación, corregirlos en los archivos de `Sources/LemiShelf/` con ediciones puntuales y repetir el paso 3.
5. Verificar con la persona (que confirme visualmente): la caja aparece arriba al centro; el switch la contrae a una línea y la vuelve a expandir; arrastrar un archivo a la pestaña Archivos lo guarda.
6. Música: con Spotify abierto y sonando, abrir la pestaña de la nota musical. Si macOS pide permiso para controlar Spotify, pedir que pulse Permitir. Si no aparece nada, revisar Ajustes del Sistema → Privacidad y seguridad → Automatización.
7. Si quiere dejarla instalada: `cp -R build/blacktrack.app /Applications/`, abrirla desde ahí, y pedir que haga clic derecho sobre la caja y active "Abrir al iniciar sesión".

## Notas técnicas

- El ejecutable se llama `LemiShelf` internamente (nombre del target); el bundle final se llama `blacktrack.app`.
- No usa sandbox. Controla Spotify por AppleScript (permiso de Automatización).
- Medidas físicas: se calculan con `CGDisplayScreenSize` para que 1 cm sea 1 cm reales en cada pantalla.
- La ventana es un `NSPanel` sin activación; solo acepta teclado en la pestaña Notas para evitar el sonido de error al escribir en otras apps.
- Drag hacia afuera en la pestaña Carpetas usa `NSDraggingSource` con máscara `.copy` para no mover nunca el original.
- No se puede compilar en Linux ni en Windows: requiere macOS con Xcode.
