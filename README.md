<div align="center">

<img src="icon.svg" alt="fishy" width="84" />

# fishy

An ASCII fish tank idle game for Windows that doubles as a desktop widget.

[![Release](https://img.shields.io/github/v/release/dapss/fishy?style=flat-square&color=5fb3d9)](https://github.com/dapss/fishy/releases)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org)
[![Windows x64](https://img.shields.io/badge/Windows-x64-0078d4?style=flat-square)](#download)

[Download](#download) · [Features](#features) · [How to Play](#how-to-play) · [Desktop Widget](#desktop-widget) · [Controls](#controls) · [Build from Source](#build-from-source)

</div>

## Download

Get the latest version from [Releases](https://github.com/dapss/fishy/releases/latest):

- **Installer (recommended):** run `fishy-setup-vX.Y.Z.exe`. It installs fishy for your user only (no admin prompt) into `%LOCALAPPDATA%\Programs\fishy` and adds a Start menu entry. Uninstall it from **Settings > Apps** like any other program.
- **Portable zip:** unzip `fishy-vX.Y.Z-windows.zip` anywhere and run `fishy.exe`.

Your save is stored separately (see [Saves and Backups](#saves-and-backups)), so switching between the two, updating, or uninstalling never touches your progress.

### Updates

From v0.2.0 on, fishy checks GitHub for a new version a few seconds after launch. If one is out, it shows what's new and asks first: **Update and restart** downloads the new `fishy.exe`, swaps it in and restarts, and **Later** leaves everything as is. You can also check from **Settings > Check for update**, or turn the launch check off. If you're on v0.1.0, download v0.2.0 once by hand.

> [!NOTE]
> `fishy.exe` is not code-signed, so Windows Defender SmartScreen may show a warning on first launch. Click **More info**, then **Run anyway**.

## Features

- Character-grid ASCII aquarium with animated swimming, blinking eyes, drifting bubbles, rising floating text, seaweed, snails, and a tiny castle.
- Six fish species to collect, from Guppy (`><'>`) to Shark, each with its own sprite, speed, coin interval, and XP leveling up to level 5.
- Desktop widget mode with borderless window, always-on-top pinning, experimental transparent background, size presets, and corner/edge snapping.
- Compact layout with a pop-up shop and responsive font scaling so the tank stays readable in small windows down to `360x240`.
- Code-synthesized sound effects (coins, food, splashes, level-ups, purchases, sales) with volume control and one-key mute.
- Individual fish cards for naming and inspecting fish, a fish list overlay (`L`) to jump to any fish, sell undo (`Ctrl+Z`), and lifetime stats.
- Offline earnings for up to 12 hours while closed, plus optional system tray mode, battery saver (`10` FPS unfocused), and Start with Windows.
- Automatic saving, rolling backups (last 10 kept), and save export/import built into Settings.
- One-click updates from GitHub releases (always asks first), plus a per-user installer.

## How to Play

Fish swim around the tank and drop `$` coins that sink to the sand. Click a coin, or drag across several, to collect them.

Over time, fish get hungry and show a `?` above them. Click anywhere in the water to drop food `*`. Eating gives XP and levels a fish up (max level 5), increasing the value of every coin it drops. Starving fish (`!`) stop dropping coins until fed.

Spend coins in the shop on new fish and upgrades. Right-click or double-click any fish to name it, check its stats, or sell it (you have 8 seconds to undo a sale with `Ctrl+Z`).

Your tank keeps earning while the game is closed, up to 12 hours per session. Without a snail, 15% of offline coins are collected before they disappear; owning at least one snail raises that to 85%.

<details>
<summary>Fish species (6)</summary>

| Species | Sprite | Cost | Base coin | Interval |
|---|---|---:|---:|---:|
| Guppy | `><'>` | $10 | $1 | 5s |
| Dawa | `())==D` | $75 | $5 | 7s |
| Classic | `><((((o>` | $400 | $22 | 8s |
| Angel | `><(::o>` | $2,000 | $90 | 9s |
| Puffer | `><( :: o)` | $10,000 | $400 | 10s |
| Shark | `` >=|||  o`-. `` | $60,000 | $2,200 | 12s |

</details>

<details>
<summary>Upgrades (6)</summary>

| Upgrade | Base cost | Max level | Effect |
|---|---:|---:|---|
| Snail `_@'` | $120 | 4 | Crawls the sand and collects coins for you |
| Auto-feeder | $200 | 5 | Drops food when fish get hungry, faster each level |
| Minerals | $300 | 10 | Multiplies coin value by x1.25 per level |
| Bigger tank | $150 | 8 | Adds room for 2 more fish per level |
| Seaweed `)(` | $50 | 8 | +5% coin value per plant |
| Castle `[~]` | $5,000 | 1 | +25% coin value |

</details>

## Desktop Widget

Press `Esc` (or click `[ = ]`) to configure fishy as a corner desktop companion:

1. Turn on **Borderless window** and **Always on top**.
2. Pick a **Widget size**: Tiny (`360x240`), Small (`460x300`), or Normal (`560x360`).
3. Click **Snap to left** or **Snap to right** to park the tank in a bottom corner above the taskbar, or drag the top bar to snap against any screen edge.

Optional settings for running all day:
- **Transparent background** (experimental) hides the outer frame so only the tank floats over your desktop.
- **Battery saver** drops the frame rate to `10` FPS while another window is focused.
- **Keep running when closed** minimizes to the system tray instead of quitting (hover the tray icon to see your balance, or right-click to quit).
- **Start with Windows** launches the tank automatically at login.

## Controls

### Mouse

| Action | Input |
|---|---|
| Drop food | Left-click water |
| Collect coins | Click or drag over `$` |
| Open fish card (name, stats, sell) | Right-click or double-click a fish |
| Buy as many as you can afford | `Shift` + click any shop button |
| Move window | Drag top bar, or `Alt` + drag anywhere |
| Resize borderless window | Drag bottom-right corner grip |

### Keyboard

| Key | Action |
|---|---|
| `1` to `6` | Buy fish (hold `Shift` to buy max) |
| `F` | Feed every hungry fish |
| `Space` | Collect all coins |
| `L` | Open fish list |
| `S` | Toggle shop pop-up (compact layout) |
| `C` | Toggle compact / full layout |
| `P` | Pin or unpin always on top |
| `M` | Mute or unmute sound |
| `Ctrl+Z` | Undo the last fish sale |
| `F1` or `?` | Open help card |
| `Esc` | Open settings, or close the current overlay |

## Saves and Backups

The game saves every 30 seconds and immediately after purchases, upgrades, and sales. On Windows, files are stored in:

```text
%APPDATA%\Godot\app_userdata\fishy\
```

- `fishy_save.json` holds your tank, money, upgrades, and stats.
- `settings.cfg` is stored separately so resetting a save keeps your window layout and preferences.
- `backups/` stores automatic rolling backups (taken on launch if the last one is older than 10 minutes, every 15 minutes while running, and before an update, import, or reset; the last 10 are kept).

From **Settings > Save**, you can export a save file to move it to another PC, import a save or backup, open the backups folder, or reset your progress.

## Build from Source

You need **Godot 4.7** (the project uses the `GL Compatibility` renderer).

```powershell
git clone https://github.com/dapss/fishy.git
cd fishy
godot --path .
```

You can also open `project.godot` directly in the Godot editor and press `F5`.

To export a standalone Windows binary (uses the `Windows Desktop` preset in `export_presets.cfg`, outputting `build/fishy.exe` with the PCK embedded):

```powershell
godot --headless --export-release "Windows Desktop"
```

To build the installer, install [Inno Setup 6](https://jrsoftware.org/isinfo.php) and run (outputs `build/fishy-setup-v0.2.0.exe`):

```powershell
ISCC.exe /DAppVersion=0.2.0 installer\fishy.iss
```

When publishing a release, tag it `vX.Y.Z` (matching `application/config/version` in `project.godot`) and upload the installer, the zip, and the bare `fishy.exe`. The in-game updater downloads the asset named exactly `fishy.exe`.

<details>
<summary>Project structure</summary>

All UI, gameplay, and audio are built in GDScript with no external runtime dependencies:

```text
fishy/
├── project.godot             # Godot 4.7 project config (GL Compatibility, transparent window)
├── export_presets.cfg        # Windows x64 single-exe export preset
├── main.tscn                 # Root scene entry point
├── icon.svg                  # App and tray icon
├── installer/
│   └── fishy.iss             # Inno Setup script (per-user installer)
└── scripts/
    ├── main.gd               # Game loop, HUD, shop, window/widget modes, tray, saves & backups
    ├── tank.gd               # Character-grid ASCII simulation and renderer
    ├── data.gd               # Species sprites, color masks, upgrades, formatting helpers
    ├── audio.gd              # Procedurally synthesized sound effects
    ├── settings.gd           # Preference defaults and config file persistence
    ├── settings_panel.gd     # Settings overlay UI
    ├── fish_card.gd          # Fish naming, stats, and sell modal
    ├── fish_list.gd          # Fish roster overlay
    ├── help_card.gd          # In-game help and shortcut card
    ├── info_card.gd          # Offline earnings and lifetime stats modal
    ├── updater.gd            # GitHub release check, download, and exe swap
    ├── update_card.gd        # "New version" prompt with progress
    └── resize_grip.gd        # Corner resize handle for borderless mode
```

</details>
