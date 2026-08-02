#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LUNAR_DIR="$HOME/.local/share/lunar-client"
WINEPREFIX="$LUNAR_DIR/pfx"
LAUNCHER_DIR="$WINEPREFIX/drive_c/lunar-launcher"
LAUNCHER_EXE_WIN="C:\\lunar-launcher\\Lunar Client.exe"
PAYLOAD_7Z="$LUNAR_DIR/lunarclient-3.4.9-x64.nsis.7z"
PAYLOAD_URL="https://launcherupdates.lunarclientcdn.com/lunarclient-3.4.9-x64.nsis.7z"
VAPE_DLL="${VAPE_DLL:-$SCRIPT_DIR/VapeV4.21.dll}"
INJECTOR_SO="${INJECTOR_SO:-$SCRIPT_DIR/injector.exe.so}"

PROTON="$(ls "$HOME/.steam/steam/steamapps/common/Proton 9.0 (Beta)/proton" \
              "$HOME/.steam/steam/steamapps/common/Proton 9.0/proton" \
              "$HOME/.steam/steam/steamapps/common/Proton Experimental/proton" 2>/dev/null | head -1)"
if [ -z "$PROTON" ]; then
    echo "Proton 9.0 not found. Enable it in Steam > Settings > Compatibility."
    exit 1
fi
WINE_BIN="$(dirname "$PROTON")/files/bin/wine"

say() { echo "[lunar-vape] $*"; }

install_launcher() {
    if [ -f "$LAUNCHER_DIR/Lunar Client.exe" ]; then
        return 0
    fi
    say "Windows Lunar Client launcher not found, installing..."
    mkdir -p "$LAUNCHER_DIR"
    if [ ! -f "$PAYLOAD_7Z" ]; then
        say "Downloading launcher payload..."
        curl -#L -o "$PAYLOAD_7Z" "$PAYLOAD_URL" || { echo "Download failed"; exit 1; }
    fi
    say "Extracting launcher..."
    rm -rf /tmp/lunar-app-extract
    mkdir -p /tmp/lunar-app-extract
    bsdtar -xf "$PAYLOAD_7Z" -C /tmp/lunar-app-extract
    cp -r /tmp/lunar-app-extract/. "$LAUNCHER_DIR/"
    say "Launcher installed to prefix."
}

setup_vape() {
    if [ ! -f "$VAPE_DLL" ]; then
        echo "ERROR: Vape DLL not found at $VAPE_DLL"
        echo "Set VAPE_DLL=/path/to/VapeV4.21.dll or place it next to this script."
        exit 1
    fi
    mkdir -p "$WINEPREFIX/drive_c"
    cp -f "$VAPE_DLL" "$WINEPREFIX/drive_c/VapeV4.21.dll"
    cp -f "$INJECTOR_SO" "$WINEPREFIX/drive_c/injector.exe.so"
    say "Vape V4.21.dll and injector staged in prefix."
}

GAME_LOG="$WINEPREFIX/drive_c/users/steamuser/.lunarclient/offline/multiver/logs/latest.log"

kill_launcher() {
    say "Killing Lunar Client launcher..."
    kill "$LAUNCHER_PID" 2>/dev/null
    pkill -f "Lunar Client.exe" 2>/dev/null
    pkill -f "lunar-launcher" 2>/dev/null
    say "Launcher killed."
}

wait_for_game_process() {
    for i in $(seq 1 600); do
        GAME_PID="$(pgrep -f "javaw.exe" | head -1)"
        if [ -n "$GAME_PID" ]; then
            say "Game process found (javaw.exe PID $GAME_PID)."
            return 0
        fi
        if [ $((i % 15)) -eq 0 ]; then
            say "Still waiting for the game to start... ($((i * 2))s elapsed)"
        fi
        sleep 2
    done
    echo "Timed out waiting for the game process to start."
    return 1
}

wait_for_game_init() {
    say "Waiting for the game to initialize..."
    LOG_SIZE=0
    LOG_INODE=""
    [ -f "$GAME_LOG" ] && LOG_SIZE=$(stat -c %s "$GAME_LOG") && LOG_INODE=$(stat -c %i "$GAME_LOG")
    for i in $(seq 1 300); do
        if [ -f "$GAME_LOG" ]; then
            CUR_INODE=$(stat -c %i "$GAME_LOG")
            CUR_SIZE=$(stat -c %s "$GAME_LOG")
            if [ -n "$LOG_INODE" ] && [ "$CUR_INODE" != "$LOG_INODE" ]; then
                LOG_INODE="$CUR_INODE"
                LOG_SIZE=0
            fi
            if [ "$CUR_SIZE" -lt "$LOG_SIZE" ]; then
                LOG_SIZE=0
            fi
            if [ "$CUR_SIZE" -gt "$LOG_SIZE" ] && \
               tail -c +$((LOG_SIZE+1)) "$GAME_LOG" | grep -qE "Lunar took .*ms to initialize"; then
                say "Game initialized."
                return 0
            fi
            LOG_SIZE="$CUR_SIZE"
        fi
        if [ $((i % 15)) -eq 0 ]; then
            say "Still waiting for the game to initialize... ($((i * 2))s elapsed)"
        fi
        sleep 2
    done
    echo "Timed out waiting for the game to initialize."
    return 1
}

inject_vape() {
    say "Injecting Vape V4 into javaw.exe..."
    export WINEPREFIX="$WINEPREFIX"
    export WINEFSYNC=1
    export WINEDLLPATH="$(dirname "$INJECTOR_SO")"
    timeout 90 "$WINE_BIN" "$INJECTOR_SO" "C:\\VapeV4.21.dll" javaw 2>&1 \
        | grep -viE "writewatch|fsync" | sed 's/^/[injector] /'
    return ${PIPESTATUS[0]}
}

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH="$LUNAR_DIR"
export WINEPREFIX="$WINEPREFIX"

install_launcher
setup_vape

say "Launching Lunar Client (Windows) through Proton 9.0..."
nohup "$PROTON" run "$LAUNCHER_EXE_WIN" > /tmp/lunar-win-launcher.log 2>&1 &
LAUNCHER_PID=$!
say "Launcher started (PID $LAUNCHER_PID)."

say "Waiting for the game to launch (log in to the launcher if prompted, then press Play)..."
if wait_for_game_process; then
    kill_launcher
    if wait_for_game_init; then
        say "Waiting 3s for safe injection..."
        sleep 3
        if inject_vape; then
            say "Vape V4 injected. Open the menu with your Vape keybind (Right Shift by default)."
        else
            echo "Injection failed (see output above)."
        fi
    fi
fi

say "Monitoring game session (Ctrl+C to stop)..."
MONITOR_SECS=0
while pgrep -f "javaw.exe" >/dev/null; do
    MONITOR_SECS=$((MONITOR_SECS + 5))
    if [ $((MONITOR_SECS % 30)) -eq 0 ]; then
        say "Game running... ($((MONITOR_SECS / 60))m $((MONITOR_SECS % 60))s)"
    fi
    sleep 5
done

say "Lunar Client closed. Exiting."
