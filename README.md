<div align="center">

<img src="icon.svg" alt="fishy" width="84" />

# fishy

An ASCII fish tank idle game for Windows that doubles as a desktop widget.

[![Release](https://img.shields.io/github/v/release/dapss/fishy?style=flat-square&color=5fb3d9)](https://github.com/dapss/fishy/releases)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org)
[![Windows x64](https://img.shields.io/badge/Windows-x64-0078d4?style=flat-square)](#download)

[Download](#download) · [Features](#features) · [How to Play](#how-to-play) · [Dirty Tanks](#dirty-tanks) · [Desktop Widget](#desktop-widget) · [Controls](#controls) · [Build from Source](#build-from-source)

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
- Eight fish species to collect, from Guppy (`><'>`) to Jellyfish, each with its own sprite, speed, coin interval, and XP leveling up to level 5. Sharks hunt guppies instead of eating pellets, and algae eaters graze grime off the glass.
- Desktop widget mode with borderless window, always-on-top pinning, experimental transparent background, size presets, and corner/edge snapping.
- Compact layout with a pop-up shop and responsive font scaling so the tank stays readable in small windows down to `360x240`.
- Code-synthesized sound effects (coins, food, splashes, level-ups, purchases, sales) with volume control and one-key mute.
- Individual fish cards for naming and inspecting fish, a fish list overlay (`L`) to jump to any fish, sell undo (`Ctrl+Z`), and lifetime stats.
- Offline earnings for up to 12 hours while closed, plus optional system tray mode, battery saver (`10` FPS unfocused), and Start with Windows.
- Automatic saving, rolling backups (last 10 kept), and save export/import built into Settings.
- Food that matters: every fish eats only its own kind (free flakes, or pellets, shrimp and plankton from the shop), the auto-feeder draws from your stock, and the Dawa wants pats instead of food.
- Dirty tanks: grime grows on the glass in random algae patches, and you scrub it off by hand in clean mode, with sponge physics (stroke speed, smearing, a sponge that fills up and needs rinsing).
- Dirty water has consequences: fewer coins, sick fish, lost levels and, if left fully covered, dead fish you can revive with Fish Medicine or flush.
- One-click updates from GitHub releases (always asks first), a per-user installer, and a "What's new" card after each update.

## How to Play

Fish swim around the tank and drop `$` coins that sink to the sand. Click a coin, or drag across several, to collect them.

Over time, fish get hungry and show a `?` above them. Click anywhere in the water to drop food. Eating gives XP and levels a fish up (max level 5), increasing the value of every coin it drops. Starving fish (`!`) stop dropping coins until fed.

Each fish eats only its own food (see [Food](#food)).

Spend coins in the shop on new fish and upgrades. Right-click or double-click any fish to name it, check its stats, or sell it (you have 8 seconds to undo a sale with `Ctrl+Z`).

Keep the glass clean (see [Dirty Tanks](#dirty-tanks)).

Your tank keeps earning while the game is closed, up to 12 hours per session. Without a snail, 15% of offline coins are collected before they disappear; owning at least one snail raises that to 85%.

<details>
<summary>Fish species (8)</summary>

| Species | Sprite | Cost | Base coin | Interval |
|---|---|---:|---:|---:|
| Guppy | `><'>` | $10 | $1 | 5s |
| Dawa | `())==D` | $75 | $5 | 7s |
| Classic | `><((((o>` | $400 | $22 | 8s |
| Angel | `><(::o>` | $2,000 | $90 | 9s |
| Puffer | `><( :: o)` | $10,000 | $400 | 10s |
| Shark | `` >=|||  o`-. `` | $60,000 | $2,200 | 12s |
| Jellyfish | `(o.o)` | $350,000 | $10,000 | 14s |
| Algae eater | `=<(##)o` | $400 | $3 | 8s |

Each species unlocks once you buy the one before it. The algae eater is always in the shop while dirt is on.

**Sharks** don't eat pellets: a hungry shark chases the nearest guppy and eats it, and nearby guppies try to dart away. Named guppies are never eaten. With no guppies, a shark goes hungry and stops dropping coins when starving. The auto-feeder doesn't feed sharks.

**Jellyfish** don't swim: they pulse up in quick squeezes and sink slowly in between, drifting toward food rather than chasing it.

**Algae eaters** swim to the dirtiest parts of the glass and graze the grime off as they go. Grime is the only thing they eat: in a spotless tank they go hungry.

</details>

## Food

| Food | Glyph | Eaten by | Price |
|---|---|---|---|
| Flakes | `*` | Guppy | Free |
| Pellets | `•` | Classic, Angel | Packs of 20, $30 each |
| Shrimp | `c` | Puffer | Packs of 10, $500 each |
| Plankton | `°` | Jellyfish | Packs of 10, $8,000 each |

Prices grow with your coin multiplier (Minerals, Seaweed, Castle), so food stays about a fifth of what a fish earns between meals. Fish ignore food that isn't theirs. The first fish that needs a new food comes with a free pack.

- A click drops whatever the hungriest fish nearby eats. The food bar next to the info line (or `Q`) picks a food yourself.
- The auto-feeder drops each hungry fish's own food from your stock, also while the game is closed. When a food runs out, those fish go hungry and stop making coins (they don't die).
- You can store 100 of each food; the **Food hopper** upgrade raises that to 250, 500 and 1,000.
- The **Dawa** doesn't eat. When it's lonely (`...`), move the mouse back and forth over it to pat it: pats cheer it up and teach it like meals do. A lonely Dawa droops, its head curving down, and a neglected one sulks (`:(`) and stops making coins. Keep patting a Dawa that's already fully happy and it overloads: a white flash, fireworks, and it's **super happy** for a minute, dropping coins twice as often (once every 5 minutes at most).
- **Algae eaters** eat only grime, **sharks** only guppies.
- **Treats**, priced at two minutes of your income: Gourmet treat (double XP for 10 minutes) and Golden flakes (coins x1.5 for 5 minutes).

<details>
<summary>Upgrades (10)</summary>

| Upgrade | Base cost | Max level | Effect |
|---|---:|---:|---|
| Snail `_@'` | $120 | 4 | Crawls the sand and collects coins for you |
| Auto-feeder | $200 | 5 | Drops food when fish get hungry, faster each level |
| Minerals | $300 | 10 | Multiplies coin value by x1.25 per level |
| Bigger tank | $150 | 8 | Adds room for 2 more fish per level |
| Seaweed `)(` | $50 | 8 | +5% coin value per plant |
| Castle `[~]` | $5,000 | 1 | +25% coin value |
| Big sponge | $150 | 3 | +20% reach, +10% scrubbing strength and +50% grime held per level |
| Food hopper | $500 | 3 | Stores more food: 100, 250, 500, 1,000 of each kind |
| Filter `[=]` | $250 | 3 | Grime builds up 12% slower per level |
| UV lamp | $25,000 | 1 | Grime builds up 20% slower |

Filter and UV lamp together slow grime by at most 50%. **Fish Medicine** is a consumable in the same shop, priced at about a third of your best fish.

</details>

## Dirty Tanks

Grime slowly builds up on the glass: it starts at random spots, spreads like algae, and favours the sand, the sides and the waterline. From spotless to fully covered takes about 1.7 hours of play.

| Dirt | What happens |
|---|---|
| 0-30% | Up to -10% coins |
| 30-60% | Down to -30% coins; food that lands in grime is lost, snails skip buried coins |
| 60-85% | Down to -60% coins; fish get sick (`~`): slow, no XP, half the benefit from food; snails crawl at half speed |
| 85-100% | Down to -90% coins; sick fish drop a level every 2.5 minutes |
| Fully covered for 10 min | The weakest sick fish dies, then another every 3 minutes (never your last fish) |

**Cleaning.** Press `W` (or click `[ clean ]`), hold the left button and scrub. Slow, steady strokes clean best; fast ones mostly smear the grime ahead. The sponge fills up as it works and cleans worse: right-click to rinse it, or lift it out of the water for a moment. Old grime gets stubborn and takes more passes. Scrub the tank spotless for +25% coins for 3 minutes.

**Dead fish** float belly-up with a revive countdown (5 minutes, counted only while the game is open). Right-click one to revive it with Fish Medicine (the tank must be below 60%; it comes back one level lower) or flush it for a small refund. Too late and it turns to bones, which can only be flushed. Dead fish left in the tank make grime grow faster. Medicine also cures sick fish.

While the game is closed, grime only grows to 85% and nothing gets sick or dies. Don't want any of this? Turn off **Tank gets dirty** or **Fish can die from dirt** in settings.

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
| Open fish card (name, stats, sell, cure, revive, flush) | Right-click or double-click a fish |
| Scrub the glass (clean mode) | Hold left and drag |
| Rinse the sponge (clean mode) | Right-click |
| Buy as many as you can afford | `Shift` + click any shop button |
| Move window | Drag top bar, or `Alt` + drag anywhere |
| Resize borderless window | Drag bottom-right corner grip |

### Keyboard

| Key | Action |
|---|---|
| `1` to `8` | Buy fish (hold `Shift` to buy max) |
| `F` | Feed every hungry fish |
| `W` | Clean mode on / off |
| `Q` | What a click drops: auto, or a food |
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
    ├── data.gd               # Species sprites, color masks, upgrades, tuning, formatting helpers
    ├── dirt.gd               # Grime grid: algae growth, sponge wiping, save format
    ├── changelog.gd          # Release notes for the "What's new" card
    ├── audio.gd              # Procedurally synthesized sound effects
    ├── settings.gd           # Preference defaults and config file persistence
    ├── settings_panel.gd     # Settings overlay UI
    ├── fish_card.gd          # Fish naming, stats, sell / cure / revive / flush modal
    ├── fish_list.gd          # Fish roster overlay
    ├── help_card.gd          # In-game help and shortcut card
    ├── info_card.gd          # Offline earnings and lifetime stats modal
    ├── updater.gd            # GitHub release check, download, and exe swap
    ├── update_card.gd        # "New version" prompt with progress
    └── resize_grip.gd        # Corner resize handle for borderless mode
```

</details>
