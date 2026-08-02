# Setup Guide

Step-by-step from a clean machine to Vape V4 running in Lunar Client 1.8.9 on Linux.

> Read the **Warnings** section at the bottom first. This tool injects a paid cheat client into a multiplayer game — use at your own risk.

---

## 1. Install Steam + Proton 9.0 (Beta)

```
sudo pacman -S steam        # Arch
sudo apt install steam      # Debian/Ubuntu
sudo dnf install steam      # Fedora
```

Open Steam → **Settings → Compatibility**:
- Tick **"Enable Steam Play for all other titles"**
- Compatibility tool: **Proton 9.0 (Beta)** (not Experimental, not GE)

Launch any game once so Steam downloads Proton, or verify it downloaded:

```
ls "$HOME/.steam/steam/steamapps/common/"
# should contain a "Proton 9.0 (Beta)" folder
```

No Steam game purchase is needed — the loader only uses Proton's runtime.

## 2. Install system dependencies

```
# Arch
sudo pacman -S libarchive curl python-pyqt6

# Debian/Ubuntu
sudo apt install libarchive-tools curl python3-pyqt6

# Fedora
sudo dnf install libarchive curl python3-pyqt6
```

`libarchive` provides `bsdtar` (extracts the launcher), `python-pyqt6` is only needed for the GUI loader.

## 3. Get the loader

```
git clone <this-repo-url> && cd Vapetux
```

## 4. Place your Vape DLL

You must already own Vape V4 (from vape.gg — it is paid software, this repo does not contain it). Any DLL version works.

```
# either: put it next to the scripts
# any name works - the loader auto-detects *.dll
cp VapeV4.21.dll .

# or: point the loader at it
export VAPE_DLL=/path/to/your/vape.dll
```

## 5. First run (CLI)

```
./lunar-install.sh
```

What happens on first run:
1. `lunarclient-3.4.9-x64.nsis.7z` (~105 MB) downloads from Lunar's CDN and extracts into `~/.local/share/lunar-client/pfx/drive_c/lunar-launcher/`.
2. The Lunar launcher window opens — **log in with your Lunar account** (same account you use on Windows).
3. Click **Play** on the 1.8.9 version.
4. The loader detects `javaw.exe`, kills the launcher, waits for the game to initialize, then injects Vape.
5. Output ends with `[lunar-vape] Vape DLL injected.` — in-game, open Vape with **Right Shift** (default keybind).

## 6. GUI loader (optional but recommended)

```
./install-loader.sh
```

This creates a desktop entry. Launch **"Lunar Client + Vape Loader"** from your app menu, or:

```
python3 lunar-loader.py
```

The window shows a progress bar, current stage, live log, and closes itself when the session ends.

## 7. Re-running

Everything is cached in `~/.local/share/lunar-client/pfx/` — the launcher and DLL don't re-download. Just run the loader again.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Proton 9.0 not found` | Complete step 1; Proton must be downloaded (run any Steam game once) |
| `Vape DLL not found at ...` | Step 4 — set `VAPE_DLL` or place the DLL next to the scripts |
| Launcher window never opens | Check `~/.local/share/lunar-client/pfx` exists; delete `lunar-launcher/` and re-run |
| "Waiting for the game to start..." forever | You didn't press Play in the launcher, or Steam logged you out of Proton |
| "Timed out waiting for the game to initialize" | The game crashed during boot — check `~/.local/share/lunar-client/pfx/drive_c/users/steamuser/.lunarclient/offline/multiver/logs/latest.log` |
| `LoadLibrary returned: 0` | DLL path is wrong or the DLL is not a valid Vape V4 build — re-check `VAPE_DLL` |
| Game window shows but injection failed | Run the CLI version and paste the `[injector]` lines into an issue |
| GUI won't start | `python3 -c "import PyQt6"` fails → install `python-pyqt6` |

## Clean uninstall

```
rm -rf ~/.local/share/lunar-client
```

---

## Warnings

- **This tool injects a paid cheat client (Vape V4) into Lunar Client.** You must own a Vape V4 license; the DLL is not bundled.
- **Cheating is against the ToS** of Lunar Client and most servers (Hypixel, etc.). Account bans, server bans, and hardware ID (HWID) flags are possible. **Use on an alt account and at your own risk.** This project provides no support for appeals.
- **Vape's own forums explicitly recommend Linux setups** ("Guide to run VAPE V4 on Linux"), but anti-cheat detection techniques change. Injection may stop working after any Lunar Client or Vape update.
- **Antivirus / Windows Defender false positives**: DLL injection tools are commonly flagged as malware (they use the same primitives as malware loaders). Vape V4's own official files get flagged too. Do not run this on a system where you rely on the host AV to protect you; the injection is contained to the Proton prefix.
- **HWID considerations**: Vape V4 is HWID-bound to your account. Using it on Linux through Wine/Proton may look like a new machine — re-activation may be required.
- **No redistribution of the DLL**: do not commit `VapeV4.21.dll` to any repo. It is proprietary paid software. Keep it out of git (the `.gitignore` already excludes it).
- **Only for personal, private use.** Publishing guides or tooling that facilitates cheating is not supported here beyond this personal-use loader.
