#!/bin/bash
set -e
cd "$(dirname "$0")"
pkill -x LemiShelf 2>/dev/null || true
swift build -c release
APP="build/blacktrack.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LemiShelf "$APP/Contents/MacOS/LemiShelf"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "Listo: $APP"
open "$APP"
