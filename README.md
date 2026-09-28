<div align="center">
  <img src="AppUninstaller/welcome.png" alt="MacOptimizer Hero" width="180" />

  # MacOptimizer

  **A macOS cleaner, optimizer and system monitor that lives in your menu bar**

  **English** · [Tiếng Việt](README.vi.md)

  <p>
    <img src="https://img.shields.io/badge/macOS-13%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13+">
    <img src="https://img.shields.io/badge/Swift-5.9-F97316?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9">
    <img src="https://img.shields.io/badge/Version-4.0.9-2563EB?style=for-the-badge" alt="Version 4.0.9">
    <img src="https://img.shields.io/badge/UI-Vi%E1%BB%87t%20Nam%20%2F%20English-059669?style=for-the-badge" alt="UI Vietnamese / English">
    <img src="https://img.shields.io/badge/Menu%20Bar-GPU%20%2F%20CPU%20%2F%20DISK%20%2F%20RAM-7C3AED?style=for-the-badge" alt="Menu bar metrics">
  </p>
</div>

---

## Overview

MacOptimizer is a SwiftUI macOS utility that lives in the menu bar and focuses on four jobs:

- cleaning system junk, caches, logs and large files,
- uninstalling apps together with their leftover files,
- monitoring your Mac in real time from the menu bar,
- managing local AI models (Ollama, LM Studio) and Docker images to reclaim disk space.

The UI ships in **Vietnamese and English** — on first launch the app follows your system language, and you can switch any time in Settings. Adding another language is just one JSON file (see [Languages](#languages)).

The app runs as an accessory utility (`LSUIElement`): no Dock icon, everything happens from the menu bar, with a main window for detailed cleaning and admin flows.

---

## Features

### Menu bar dashboard

- A popup dashboard right under the status item: a **system health score** ring (weighted CPU/RAM/disk load), compact metric tiles, tappable disk and network strips.
- Live status item metrics: `GPU`, `CPU`, `DISK`, `RAM`, `Network`, `Battery` — toggle each one, reorder, use display presets and sampling profiles.
- **5 banner themes** for the menu bar strip: Dark, Light, Mono, Accent, Minimal.
- **RAM alerts** based on a system-wide threshold (configurable 60–95%), naming the heaviest app with a confirm-before-force-quit flow.
- A **WidgetKit widget** (Small/Medium) showing the health score, CPU/RAM/disk gauges and uptime. *(Known issue: on macOS 27.0 the widget process crashes inside Apple's ExtensionFoundation bootstrap before our code runs — affects hand-built SPM appex; works on macOS 26.)*
- Per-metric detail windows (CPU, RAM, storage, network, battery, force-quit apps) open from the dashboard.
- Launch at login, optional app icon on the status item.

### Real-time protection

- **Ad block & anti-tracking** via `/etc/hosts` (curated hostname lists, automatic backup & restore, clearly marked sections).
- **Malware / adware scan** for common threat patterns.
- **Privacy**: scan and clean browsing history, cookies, download history and developer traces.

### Cleaning & optimization toolkit

| Module | Purpose |
| --- | --- |
| Smart Clean | Quick scan of the groups that usually need cleaning |
| Junk Cleaner | Clean caches, logs and system junk |
| Deep Clean | Deeper sweep for leftovers and redundant files |
| Large Files | Find big, old and space-hungry files |
| Duplicates / Similar photos | Find duplicate files and similar images |
| Trash | Inspect and empty the Trash |
| File Explorer | Browse the file system with quick actions |
| Space Lens | Visual disk usage map |
| Shredder | Securely erase files |
| Maintenance | System upkeep (Spotlight, DNS, Time Machine snapshots...) |
| Optimizer | Tune system state and startup items |
| Background Services | Audit & disable third-party LaunchAgents/LaunchDaemons |
| AI Models | Manage local Ollama / LM Studio models |
| Docker | Inspect and prune Docker images |
| App Updater | Check for app updates |
| Uninstaller | Remove apps with their related files |

### App uninstaller

- scans installed apps,
- lists related files such as `Preferences`, `Caches`, `Logs`, `Application Support`,
- selective removal,
- Trash-first for safer deletes.

---

## Languages

- **Vietnamese** (source language) and **English** ship built-in; switch instantly in **Settings → Language** — the whole app re-renders without a restart.
- On first launch the app auto-detects your system language and uses it if a translation exists (English system → English UI), otherwise Vietnamese.
- Adding a language requires **no code changes**: drop a `AppUninstaller/Languages/<code>.json` file (keys are the original Vietnamese strings) and rebuild. See [docs/LOCALIZATION.md](docs/LOCALIZATION.md); verify with `python3 scripts/validate_localizations.py`.

---

## Screenshots

### Menu bar & dashboard

<p align="center">
  <img src="AppUninstaller/system_clean_menu.png" alt="Menu bar monitoring" width="31%" />
  <img src="AppUninstaller/yibiaopan_2026.png" alt="Dashboard monitoring" width="31%" />
  <img src="AppUninstaller/yinpan_2026.png" alt="Disk cleanup module" width="31%" />
</p>

### Cleaning & optimization

<p align="center">
  <img src="AppUninstaller/smart-scan.2f4ddf59.png" alt="Smart Scan" width="31%" />
  <img src="AppUninstaller/shenduqingli.png" alt="Deep Clean" width="31%" />
  <img src="AppUninstaller/youhua.png" alt="Optimizer" width="31%" />
</p>

### Privacy & protection

<p align="center">
  <img src="AppUninstaller/yinsi.png" alt="Privacy" width="31%" />
  <img src="AppUninstaller/zhiwendunpai_2026.png" alt="Protection" width="31%" />
  <img src="AppUninstaller/malware@2x.png" alt="Malware scan" width="31%" />
</p>

### App management

<p align="center">
  <img src="AppUninstaller/Uninstaller@2x.jpg" alt="Uninstaller" width="31%" />
  <img src="AppUninstaller/clean-up.866fafd0.png" alt="Cleanup results" width="31%" />
  <img src="AppUninstaller/welcome.png" alt="Welcome screen" width="31%" />
</p>

---

## Build from source

### Requirements

- macOS 13 or later
- Swift 5.9
- Xcode or matching Command Line Tools

### Quick build

```bash
git clone git@github.com:TGalioAutomation/MacOptimizervn.git
cd MacOptimizervn
./build.sh
```

Build artifacts:

- `build/MacOptimizer.app`
- `build/MacOptimizer.dmg`

Run it:

```bash
open build/MacOptimizer.app
```

### Dual-architecture release package

```bash
./build_dual_dmg.sh
```

Build artifacts:

- `build_release/MacOptimizer_v4.0.9_AppleSilicon.dmg`
- `build_release/MacOptimizer_v4.0.9_Intel.dmg`

### Package check

```bash
swift build
```

### Regenerate the app icon (.icns)

```bash
./scripts/generate_app_icon.sh
```

Master icon source: `AppUninstaller/BrandAssets/AppIcon-master-1024.png`.

---

## Repository layout

```text
MacOptimizervn/
├── AppUninstaller/             # macOS app sources
│   ├── AppDelegate.swift       # Accessory-utility startup & menu bar
│   ├── AppUninstallerApp.swift
│   ├── ContentView.swift
│   ├── Languages/              # JSON translations (vi, en) — add languages here
│   ├── MenuBar/                # Menu bar popup, details, customization, themes
│   ├── SystemMonitorService.swift
│   ├── SmartCleanerService.swift
│   ├── PrivacyScannerService.swift
│   ├── MalwareScanner.swift
│   ├── BrandAssets/            # Master brand/icon assets
│   └── ...
├── WidgetExtension/            # WidgetKit widget (health score)
├── Sources/                    # Shared SPM modules (AIModelKit, verify tool)
├── Tests/                      # Unit tests
├── contracts/                  # Work contracts & checklists
├── docs/                       # Technical docs (LOCALIZATION.md, audits...)
├── scripts/                    # Utility scripts (icon, translation validator...)
├── build.sh                    # Local build + DMG
├── build_dual_dmg.sh           # Apple Silicon + Intel DMGs
└── README.md
```

---

## Related docs

- [docs/LOCALIZATION.md](docs/LOCALIZATION.md) — localization guide
- [CHANGELOG_v4.0.8.md](CHANGELOG_v4.0.8.md)
- [CHANGELOG_v4.0.7.md](CHANGELOG_v4.0.7.md)
- [CHANGELOG_v4.0.6.md](CHANGELOG_v4.0.6.md)
- [docs/audit-2026-04-06.md](docs/audit-2026-04-06.md)

---

## Operating notes

- The experience is menu-bar-first; the main window is for detailed cleaning and admin flows.
- `GPU` usage depends on what macOS reports; detail levels vary between machines.
- Some features need permissions: **Full Disk Access** (deep scans), **Location** (Wi-Fi name), an admin password (editing `/etc/hosts`, cleaning system files).
- For sensitive cleanup, review the file list before bulk-deleting and prefer Trash over permanent deletion; back up important data before deep cleaning on a work machine.
- Ad block / anti-tracking edits `/etc/hosts` (auto-backed up at `/etc/hosts.macoptimizer.bak`) — turning the feature off restores the original.

---

<div align="center">
  <strong>MacOptimizer</strong><br/>
  Lean, fast, always watching from the menu bar.
</div>
