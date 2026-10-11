# Customizations

## Confirmed deliberate choices

- Dracula palette and wallpaper.
- Niri 1.2 display scale on `eDP-1`.
- Roboto Serif for the UI.
- Roboto Mono for the terminal.

### Locale rule

- Prefer `en_CA.UTF-8` for UI language.
- Prefer `fr_CA.UTF-8` for numeric, date, currency, and measurement formats.
- Validate availability with `locale -a`.
- If `en_CA.UTF-8` is unavailable, fall back to `fr_CA.UTF-8` for language; if `fr_CA.UTF-8` is unavailable, fall back to `en_CA.UTF-8` for regional formats.
- The current system has both locales, so no fallback is used.

## Completed

### DankGreeter (DMS Greeter)

Replaced SDDM with DankGreeter (DMS greeter) for a consistent Dracula login screen.

**Packages layered via rpm-ostree:**
```
sudo rpm-ostree install dms-greeter greetd
```

**Config files:**
- `/etc/greetd/config.toml` — greetd daemon config
- `/etc/greetd/niri/config.kdl` — minimal niri config for greeter (`DMS_DISABLE_MATUGEN=1`, `DMS_RUN_GREETER=1`)
- `/etc/greetd/niri/dms.kdl` — DMS greeter config (auto-synced by `dms greeter sync`)
- `/etc/profile.d/greeter-locale.sh` — locale `en_CA.UTF-8` / `fr_CA_TIME=fr_CA.UTF-8`

**Permissions:**
- User `bacon` added to group `greeter` (manually added to `/etc/group` since `systemd-sysusers` creates the group but not in the file)
- ACLs set on `~/.config`, `~/.local`, `~/.cache` for `greeter` group read access
- Symlinks in `/var/cache/dms-greeter/` → user configs (settings.json, session.json, colors.json)
- Profile picture: `~/.face` = Dracula logo SVG converted to PNG (512×512)
- AccountsService icon: `/var/lib/AccountsService/icons/bacon/icon.png`

**Enable/disable:**
```bash
# Enable greetd, disable SDDM
sudo systemctl disable sddm && sudo systemctl enable greetd

# Rollback to SDDM
sudo systemctl disable greetd && sudo systemctl enable sddm
```

**Sync after changes:**
```bash
dms greeter sync
sudo systemctl restart greetd
```

**Known issues:**
- `dms greeter sync` has a bug where it can't find the `greeter` group in `/etc/group` (it's created by `systemd-sysusers` but not in the file). Workaround: manually add `greeter:x:966:bacon` to `/etc/group`.
- VT switching: greeter runs on VT1, user session on VT2. Use `Ctrl+Alt+F1`/`F2` to switch, or `chvt 2` from TTY.

### DMS Plugins

| Plugin | Status | Notes |
|--------|--------|-------|
| dankBatteryAlerts | ✅ Active | Essential for laptop |
| dankNotepadModule | ✅ Active | Darcula style matches Dracula |
| dankPomodoroTimer | ✅ Active | Productivity |
| dankLauncherKeys | ✅ Active | Keybinding help |
| dankDesktopWeather | ✅ Active | Bar weather widget |
| dankClight | ❌ Disabled | `clight` not installed |
| dankKDEConnect | ❌ Disabled | `kdeconnectd`/`valent` not installed |

## In progress or requiring verification

- A static Dracula theme for DMS uses a source-pinned local derivative of the official upstream theme; provenance and its single active deviation are recorded in `docs/upstream-dracula.md`.
- KDE Flatpaks on runtime 6.11 currently lack the Kvantum extension. Temporary Fedora Qt6 RPM replacements are staged for Deskflow, Fedora Media Writer, Haruna, Qrca, and Skanpage; reboot and application/theme validation are still pending. Kontainer and KTailctl remain Flatpak.

### Laptop lid switch and auto-rotate (IdeaPad Flex 5)

**Lid close behavior** — niri handles the lid switch natively (turns `eDP-1` off/on), but logind must not intercept it first:

- `/etc/systemd/logind.conf.d/lid.conf`:
  ```
  [Login]
  HandleLidSwitch=ignore
  HandleLidSwitchDocked=ignore
  HandleLidSwitchExternalPower=ignore
  ```
- `~/.config/niri/config.kdl` — `switch-events` block locks via DMS on lid close:
  ```kdl
  switch-events {
      lid-close {
          spawn "dms" "ipc" "call" "lock" "lock";
      }
  }
  ```
- Note: `switch-events` only supports `spawn` actions; an empty `lid-open {}` block is invalid KDL.

**Auto-rotate** — `scripts/ideapad-tablet.sh` + `scripts/ideapad-tablet.service` drive rotation from the accelerometer via `monitor-sensor` (iio-sensor-proxy, D-Bus, no root).

- The service must start **after** niri (`After=niri.service`), otherwise `NIRI_SOCKET` is not yet in the systemd user environment and `niri msg output eDP-1 transform` fails silently (`|| true`).
- The script auto-discovers the socket when `NIRI_SOCKET` is unset:
  ```bash
  if [ -z "${NIRI_SOCKET:-}" ]; then
      export NIRI_SOCKET="$(ls -t "$XDG_RUNTIME_DIR"/niri.wayland-*.sock 2>/dev/null | head -1)"
  fi
  ```
- The touchpad/keyboard are disabled by the laptop firmware when folded (tablet mode switch, `ideapad_acpi`); software does not manage this.

**Input group** — `dms doctor` warns about evdev permissions; add the user to the `input` group:
```bash
sudo usermod -a -G input $USER
```
This is for DMS's evdev manager, not for niri (niri accesses input devices via the logind seat).

Before declaring a choice complete, verify it after reboot and after an update, and document the fallback or removal procedure. Keep examples portable and use generic `$HOME` paths rather than host-specific paths.
