#!/bin/bash

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/Lunar-Vape-Loader-x86_64.AppImage"
APPDIR="/tmp/lunar-vape-loader.AppDir"
TOOL="/tmp/appimagetool"

if [ ! -f "$TOOL" ]; then
    echo "Downloading appimagetool..."
    curl -sL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$TOOL"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp "$DIR/lunar-install.sh" "$APPDIR/usr/bin/"
cp "$DIR/lunar-loader.py" "$APPDIR/usr/bin/"
cp "$DIR/injector.exe.so" "$APPDIR/usr/bin/"

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

python3 -c "import PyQt6" 2>/dev/null || {
    echo "PyQt6 is required but not installed."
    echo "  Arch:     sudo pacman -S python-pyqt6"
    echo "  Debian:   sudo apt install python3-pyqt6"
    echo "  Fedora:   sudo dnf install python3-pyqt6"
    read -r -p "Press Enter to exit..."
    exit 1
}

exec python3 "$HERE/usr/bin/lunar-loader.py"
EOF
chmod +x "$APPDIR/AppRun"

python3 - << 'PYEOF'
import struct, zlib

W = H = 256

def px(x, y):
    if y > x - 20 and y < x + 30:
        return (120, 200, 255, 255)
    if (x - 128) ** 2 + (y - 128) ** 2 < 40 ** 2:
        return (90, 160, 240, 255)
    return (25, 40, 80, 255)

raw = b""
for y in range(H):
    raw += b"\x00"
    for x in range(W):
        raw += bytes(px(x, y))

def chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw))
png += chunk(b"IEND", b"")

open("/tmp/lunar-vape-loader.AppDir/lunar-vape-loader.png", "wb").write(png)
PYEOF

cat > "$APPDIR/lunar-vape-loader.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Lunar Client + Vape Loader
Comment=Launch Lunar Client (Windows) via Proton and inject Vape V4
Exec=lunar-vape-loader
Icon=lunar-vape-loader
Terminal=false
Categories=Game;
EOF

"$TOOL" --appimage-extract-and-run --no-appstream "$APPDIR"
mv /tmp/Lunar_Client_+_Vape_Loader-x86_64.AppImage "$OUT"
echo "Built: $OUT"
