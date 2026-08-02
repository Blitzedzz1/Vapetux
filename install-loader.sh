#!/bin/bash

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN_SCRIPT="$DIR/lunar-install.sh"
LOADER="$DIR/lunar-loader.py"

if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "ERROR: lunar-install.sh not found next to this installer."
    exit 1
fi
chmod +x "$MAIN_SCRIPT"

python3 -c "import PyQt6" 2>/dev/null || {
    echo "ERROR: PyQt6 not installed. Install it:"
    echo "  sudo pacman -S python-pyqt6"
    echo "  sudo apt install python3-pyqt6"
    exit 1
}

echo "Loader: $LOADER"
echo "Run:    python3 $LOADER"

DESKTOP="$HOME/.local/share/applications/lunar-vape-loader.desktop"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" << EOF
[Desktop Entry]
Type=Application
Name=Lunar Client + Vape Loader
Comment=Launch Lunar Client (Windows) via Proton and inject Vape V4
Exec=python3 $LOADER
Icon=applications-games
Terminal=false
Categories=Game;
EOF
echo "Desktop entry: $DESKTOP"
