#!/usr/bin/env bash
# Apply Dracula after post-install packages are present and rpm-ostree has rebooted.
# It never installs unpinned upstream assets; it applies validated assets already
# staged in the user configuration and themes compatible Flatpak KDE runtimes.
set -Eeuo pipefail

DRY_RUN=0
ROLLBACK=0
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wayblue-dracula-theme"
STATE_FILE="$STATE_DIR/flatpaks"
BACKUP_DIR="$STATE_DIR/backups"
KVANTUM_DIR="$HOME/.config/Kvantum"
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
QT_ENV="$HOME/.config/environment.d/91-qt-theme.conf"
GTK_THEME_DIR="$HOME/.local/share/themes/Dracula"
DMS_OVERLAY="$HOME/.config/DankMaterialShell/themes/dracula-local-overlay.json"

log() { printf '[dracula] %s\n' "$*"; }
warn() { printf '[dracula][warn] %s\n' "$*" >&2; }

run() {
  if (( DRY_RUN )); then
    printf '  (dry-run)'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

backup_once() {
  local source="$1" name="$2"
  local target="$BACKUP_DIR/$name"
  [[ -e "$source" && ! -e "$target" ]] || return 0
  (( DRY_RUN )) || { mkdir -p "$BACKUP_DIR"; cp -a "$source" "$target"; }
}

record_once() {
  local record="$1"
  (( DRY_RUN )) && return 0
  mkdir -p "$STATE_DIR"
  grep -qxF "$record" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$record" >> "$STATE_FILE"
}

write_file() {
  local destination="$1" content="$2"
  if (( DRY_RUN )); then
    log "would write $destination"
  else
    mkdir -p "$(dirname "$destination")"
    printf '%s' "$content" > "$destination"
  fi
}

restore_backup() {
  local name="$1" destination="$2"
  local backup="$BACKUP_DIR/$name"
  [[ -e "$backup" ]] || return 0
  run mkdir -p "$(dirname "$destination")"
  run cp -a "$backup" "$destination"
}

apply_host_qt() {
  if [[ ! -d "$KVANTUM_DIR/Dracula" || ! -f "$QT6CT_CONF" ]]; then
    warn "Kvantum Dracula or qt6ct config missing; stage pinned host assets before applying"
    return 0
  fi
  backup_once "$QT_ENV" qt-theme.conf
  write_file "$QT_ENV" $'QT_QPA_PLATFORMTHEME=qt6ct\n'
  log "host Qt6 uses Kvantum Dracula + qt6ct"
}

apply_dms() {
  [[ -x "$(command -v dms 2>/dev/null || true)" ]] || { warn "DMS absent; skipping"; return 0; }
  if [[ ! -e "$DMS_OVERLAY" ]]; then
    write_file "$DMS_OVERLAY" $'{\n  "name": "Dracula Local Overlay",\n  "colors": { "success": "#50FA7B" }\n}\n'
  fi
  if (( DRY_RUN )); then
    run dms ipc call theme set custom "$DMS_OVERLAY"
  else
    dms ipc call theme set custom "$DMS_OVERLAY" || warn "DMS session unavailable; apply the overlay after login"
  fi
}

apply_gtk_residual() {
  if command -v gsettings >/dev/null 2>&1; then
    (( DRY_RUN )) || {
      gsettings get org.gnome.desktop.interface color-scheme > "$STATE_DIR/gsettings-color-scheme" 2>/dev/null || true
      [[ -d "$GTK_THEME_DIR" ]] && gsettings get org.gnome.desktop.interface gtk-theme > "$STATE_DIR/gsettings-gtk-theme" 2>/dev/null || true
    }
    run gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    [[ -d "$GTK_THEME_DIR" ]] && run gsettings set org.gnome.desktop.interface gtk-theme Dracula || warn "host Dracula GTK theme absent; keeping current GTK theme"
  fi

  if flatpak info org.mozilla.firefox >/dev/null 2>&1; then
    run flatpak override --user \
      --filesystem=xdg-config/gtk-3.0:ro \
      --filesystem=xdg-config/gtk-4.0:ro \
      --filesystem=xdg-data/themes:ro \
      org.mozilla.firefox
    record_once firefox
    log "Firefox kept as GTK Flatpak; no global GTK_THEME override applied"
  fi
}

apply_kde_flatpaks() {
  command -v flatpak >/dev/null 2>&1 || return 0
  local app runtime branch extension
  local -A extension_checked=()
  while IFS=$'\t' read -r app runtime; do
    [[ "$runtime" =~ ^org\.kde\.Platform/[^/]+/ ]] || continue
    branch="${runtime##*/}"
    extension="org.kde.KStyle.Kvantum//$branch"
    if [[ -z "${extension_checked[$branch]:-}" ]]; then
      if flatpak remote-info flathub "$extension" >/dev/null 2>&1; then
        run flatpak install --noninteractive flathub "$extension"
        extension_checked[$branch]=available
      else
        extension_checked[$branch]=missing
        warn "Kvantum extension unavailable for KDE runtime $branch; keeping its apps on Breeze"
      fi
    fi
    [[ "${extension_checked[$branch]}" == available ]] || continue
    run flatpak override --user \
      --env=QT_STYLE_OVERRIDE=kvantum \
      --filesystem=xdg-config/Kvantum:ro \
      "$app"
    record_once "flatpak=$app"
  done < <(flatpak list --app --columns=application,runtime 2>/dev/null)
}

rollback() {
  [[ -f "$STATE_FILE" ]] || { warn "no theme state recorded"; return 0; }
  local record app
  while IFS= read -r record; do
    case "$record" in
      flatpak=*)
        app="${record#flatpak=}"
        run flatpak override --user --unset-env=QT_STYLE_OVERRIDE --nofilesystem=xdg-config/Kvantum:ro "$app" || true
        ;;
      firefox)
        run flatpak override --user --nofilesystem=xdg-config/gtk-3.0:ro --nofilesystem=xdg-config/gtk-4.0:ro --nofilesystem=xdg-data/themes:ro org.mozilla.firefox || true
        ;;
    esac
  done < "$STATE_FILE"
  restore_backup qt-theme.conf "$QT_ENV"
  [[ -f "$STATE_DIR/gsettings-color-scheme" ]] && run gsettings set org.gnome.desktop.interface color-scheme "$(<"$STATE_DIR/gsettings-color-scheme")" || true
  [[ -f "$STATE_DIR/gsettings-gtk-theme" ]] && run gsettings set org.gnome.desktop.interface gtk-theme "$(<"$STATE_DIR/gsettings-gtk-theme")" || true
  (( DRY_RUN )) || rm -f "$STATE_FILE"
}

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --rollback) ROLLBACK=1 ;;
    *) warn "unknown argument: $1"; exit 2 ;;
  esac
  shift
done

if (( ROLLBACK )); then
  rollback
  exit 0
fi

(( DRY_RUN )) || mkdir -p "$STATE_DIR"
apply_host_qt
apply_dms
apply_gtk_residual
apply_kde_flatpaks
log "done; restart affected Flatpaks. RPM apps require the post-layer reboot first."
