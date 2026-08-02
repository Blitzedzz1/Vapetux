# Vapetux

Launch Lunar Client (Windows build) on Linux through Proton 9.0 and auto-inject any Vape V4 DLL once the game has fully initialized.

## What it does

1. Downloads and installs the Windows Lunar Client launcher (v3.4.9) into a Proton prefix — no installer, no `rundll32` hang.
2. Launches it through Steam Proton 9.0 (Beta).
3. Waits for the game process (`javaw.exe`) to spawn, then kills the launcher to free RAM.
4. Waits for the game's init log line (`Lunar took Xms to initialize`) so injection only happens once the game is ready.
5. Injects the found Vape DLL (any `*.dll` next to the scripts, or `VAPE_DLL`) via `CreateRemoteThread` into `javaw.exe`.
6. Monitors the session and exits when the game closes.

Two UIs:
- **CLI**: `./lunar-install.sh` — full output on the terminal.
- **GUI**: `python3 lunar-loader.py` — progress bar + live status, auto-closes when done.

## Requirements

| Dependency | Purpose |
|---|---|
| Arch / Debian / Fedora Linux (X11 or Wayland with XWayland) | Platform |
| Steam with **Proton 9.0 (Beta)** enabled | Windows compatibility layer |
| `bsdtar` (libarchive) | Extracting the launcher payload |
| `curl` | Downloads |
| Python 3 + PyQt6 (GUI only) | GUI loader |

```
# Arch
sudo pacman -S libarchive curl python-pyqt6
# Debian/Ubuntu
sudo apt install libarchive-tools curl python3-pyqt6
# Fedora
sudo dnf install libarchive curl python3-pyqt6
```

## Setup

1. Enable **Proton 9.0 (Beta)** in Steam: Settings → Compatibility → tick "Enable Steam Play", select Proton 9.0.
2. Place any Vape V4 DLL next to the scripts — the loader auto-detects `*.dll` files (or export `VAPE_DLL=/path/to/vape.dll`).
3. Run the loader. In the Lunar launcher, log in and press Play.

You only need a Steam client with Proton installed — no Steam game is required, the prefix is created automatically.

## Usage

CLI:

```
./lunar-install.sh
```

GUI:

```
././install-loader.sh       # registers a desktop entry
python3 lunar-loader.py    # or launch "Lunar Client + Vape Loader" from your app menu
```

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `VAPE_DLL` | auto-detected | Path to the Vape DLL (any `*.dll` in the script dir is found automatically) |
| `INJECTOR_SO` | `./injector.exe.so` | Path to the Winelib injector |

## Layout

| File | Purpose |
|---|---|
| `lunar-install.sh` | Main CLI loader |
| `lunar-loader.py` | PyQt6 GUI front-end |
| `install-loader.sh` | Creates the desktop entry |
| `injector.c` | `CreateRemoteThread` injector source |
| `injector.exe` / `injector.exe.so` | Winelib build of the injector |
| `SETUP.md` | Full setup guide |

## How it avoids the usual Linux Lunar problems

- **Windows launcher, not AppImage**: the Linux launcher runs a Linux JVM against Windows natives — that hybrid is what caused render-path crashes and thousands of NPEs. Running the real Windows launcher under Proton keeps every component native to the same Windows environment.
- **No `LunarClientSetup.exe`**: the bootstrapper hangs on `rundll32 setupapi,InstallHinfSection` under Wine. The payload 7z is extracted directly.
- **Init-gated injection**: injection waits for `javaw.exe` *and* the game's init log line, with stale-log/rotation detection so a previous session's line can't trigger an early inject.

## Contributing

PRs welcome. Keep the CLI output `[lunar-vape]`-prefixed — the GUI matches on those lines.

## License

MIT — see `LICENSE`.
