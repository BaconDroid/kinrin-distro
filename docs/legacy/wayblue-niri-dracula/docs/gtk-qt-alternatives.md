# GTK → Qt alternatives (per application)

Based on the toolkit inventory of this machine (43 GUI apps: 8 GTK4/libadwaita,
13 GTK3, 14 Qt6, 1 Qt5, 3 Electron, 4 custom). The current policy is Qt6 >
Qt5, KDE-first, Flatpak > dnf. Apply the Qt6 Dracula layer (Kvantum + qt6ct)
as the final post-install phase, after the selected applications are present.

## Key insight: DMS already absorbs several GTK roles

Before replacing anything, note that DMS natively provides: network controls,
Bluetooth pairing/devices, volume, brightness, battery, notifications. These
GTK tray utilities are **redundant** and can simply be dropped instead of
replaced:

| Redundant GTK app | Covered by |
|---|---|
| `nm-applet` | DMS control-center network module |
| `blueman-manager`, `blueman-adapters` | DMS Bluetooth module |

## GTK3 apps (RPM)

| App | Qt alternatives | Recommendation |
|---|---|---|
| **Thunar** (+ prefs/volman) | 1. **Dolphin** (Qt6/KDE, Flatpak) - split view, KIO network, plugins. 2. **Krusader** (Qt6/KDE). | **Dolphin installed and primary.** Thunar is base image (non-purgable); kept as fallback only. Qt theming (Kvantum + qt6ct) still required regardless of file manager choice. |
| **Disks** (`gnome-disks`) | 1. **KDE Partition Manager** — partitioning/format. 2. **gsmartcontrol** — SMART health. | Use `kde-partitionmanager` (dnf, absent Flathub); keep base gnome-disks unless it becomes a layered package. |
| **XArchiver** | 1. **Ark** (Qt6/KDE) — mature, all formats. 2. **PeaZip** (Qt) — cross-platform, many formats. | **Switch to Ark** — clean win, better maintained. |
| **firewall-config** | None mainstream (CLI: `firewall-cmd`). | Keep, or learn the CLI. |
| **Orca** (accessibility) | None. | Keep. |
| **gcr-prompter / gcr-viewer** | None — these are keyring/system prompts. | Never replace; breaking these breaks secret prompts. |
| **Disk Image Mounter** | Part of gnome-disks. | Follows Disks decision. |

## GTK4/libadwaita apps (mostly Flatpak)

| App | Qt alternatives | Recommendation |
|---|---|---|
| **pavucontrol** | 1. **pavucontrol-qt** (LXQt) — direct port, identical function. | **Switch to pavucontrol-qt** if you want Qt consistency; both are equal quality. |
| **Deja Dup Backups** | 1. **Vorta** (Qt/PySide, Borg frontend) — more powerful, manual snapshots. | Switch only if you outgrow Deja Dup's simplicity. |
| **Mission Center / Resources** | 1. **plasma-systemmonitor** (KDE) - deep metrics, heavy. 2. `btop` (CLI/TUI). | **Removed** (both Flatpaks); DMS already shows CPU/RAM/temp in the bar. |
| **Firmware** | `fwupdmgr` CLI. | Keep GUI; CLI is the only alternative. |
| **Flatseal / Warehouse / Bazaar** | None mature outside GNOME ecosystem. | Keep. |
| **Sticky Notes** | **KNotes** (KDE) — needs KDE runtime. | Keep unless deeply attached to Qt consistency. |

## Already Qt (with the KDE 6.11 exception)

Gwenview, Okular, KCalc, KClock, Kontact, KWeather, DB Browser (Qt5), and the
remaining Qt applications will pick up the Dracula Qt palette once Kvantum and
the color scheme are applied. The following KDE Flatpaks currently use runtime
6.11, where the Kvantum extension is unavailable:

| KDE Flatpak | Temporary Fedora RPM replacement |
|---|---|
| Deskflow | `deskflow` |
| Fedora Media Writer | `mediawriter` |
| Haruna | `haruna` |
| Qrca | `qrca` |
| Skanpage | `skanpage` |

Kontainer and KTailctl remain Flatpak: no Fedora RPM replacement was found.
This local deployment is staged, pending reboot and application/theme
validation; it is not a completed migration.

## Not worth converting

Firefox, Thunderbird, Discord, VS Code (self-contained toolkits), Alacritty,
imv, rofi (custom renderers) — toolkit choice is irrelevant to them.

## Bottom line

1. Run the base installer, then stage optional RPM replacements with
   `rpm-ostree`; reboot before validation.
2. Run [`scripts/apply-dracula-theme.sh`](../scripts/apply-dracula-theme.sh) as
   the final theme phase, then validate the applications.
3. Only after successful validation, remove the equivalent Flatpaks. Keep
   Flatpak as the default and use the temporary fallback only for the KDE 6.11
   gap described above. The authoritative procedure is in
   [`docs/dracula-application.md`](dracula-application.md).
4. Use dnf only for Spectacle, KDE Partition Manager and pavucontrol-qt (not
   available as Qt Flatpaks).
5. Worthwhile switches: **Thunar -> Dolphin** (done), **XArchiver -> Ark** and
   **pavucontrol -> pavucontrol-qt**.
6. Purge a GTK app only when it is a **layered** RPM and its replacement is in
   place. Keep GTK base packages and required GTK Flatpaks (Firefox).
7. **Launcher**: DMS spotlight (`Mod+Space`) is the primary Qt/QML launcher.
   fuzzel (`Mod+D`) disabled; wofi and fuzzel are base image (non-purgable).
