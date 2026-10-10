#!/usr/bin/env bash
# Wayblue/Niri + DMS + Dracula provisioning script (idempotent, reversible).
#
# Encodes the setup performed manually on the IdeaPad Flex 5 15ALC05.
# Safe to re-run: every mutating step checks a state marker first.
# Rollback restores the Niri config backup and removes created user files;
# system-level changes (locale, SDDM, rpm-ostree layers) are flagged for
# manual review.
#
# Usage:
#   ./install-wayblue-niri-dracula.sh            # apply (prompts for sudo parts)
#   ./install-wayblue-niri-dracula.sh --dry-run  # print actions, change nothing
#   ./install-wayblue-niri-dracula.sh --rollback # revert user-level changes

set -u
IFS=$' \n\t'

DRY_RUN=0
ROLLBACK=0
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="$STATE_DIR/wayblue-dracula-install.state"
NIRI_CONFIG="$HOME/.config/niri/config.kdl"
NIRI_BACKUP="$NIRI_CONFIG.pre-dms-$(date +%Y%m%d-%H%M%S).bak"
THEME_DIR="$HOME/.local/share/themes/Dracula"
OVERLAY="$HOME/.config/DankMaterialShell/themes/dracula-local-overlay.json"
WALLPAPER="$HOME/.local/share/wallpapers/dracula-base.png"
IDEPAD_SCRIPT="$HOME/.local/bin/ideapad-tablet.sh"
IDEPAD_SVC="$HOME/.config/systemd/user/ideapad-tablet.service"
DRACULA_GTK_REV="71640b9456110f3bac2130d0b387a3154a9fb4d2"
DRACULA_QT5_REV="7b25ee305365f6e62efb2c7aca3b4635622b778c"

log()  { echo "[install] $*"; }
warn() { echo "[install][warn] $*" >&2; }
die()  { echo "[install][error] $*" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  (dry-run) $*"
    else
        eval "$@"
    fi
}

marked() { [ -f "$STATE_FILE" ] && grep -qx "$1" "$STATE_FILE"; }
mark()   { [ "$DRY_RUN" -eq 0 ] && mkdir -p "$STATE_DIR" && echo "$1" >> "$STATE_FILE"; }

# ---------------------------------------------------------------------------
backup_niri() {
    [ -f "$NIRI_CONFIG" ] || die "Niri config not found: $NIRI_CONFIG"
    if marked niri_backed_up; then
        log "niri already backed up, skipping"
        return 0
    fi
    run "cp -f '$NIRI_CONFIG' '$NIRI_BACKUP'"
    mark niri_backed_up
    log "niri config backed up to $NIRI_BACKUP"
}

# ---------------------------------------------------------------------------
integrate_dms() {
    # Disable waybar/swaybg and ensure DMS starts via niri (already done
    # manually). This step only verifies the integration is present.
    if grep -q 'dms run --session' "$NIRI_CONFIG" 2>/dev/null; then
        log "DMS startup already present in niri config"
    else
        warn "DMS startup line not found in $NIRI_CONFIG; add: spawn-at-startup \"dms run --session\""
    fi
    if command -v dms >/dev/null 2>&1; then
        log "dms binary present: $(dms --version 2>/dev/null | head -1)"
    else
        warn "dms not installed; layer it from the avengemedia COPR first"
    fi
    mark dms_integrated
}

# ---------------------------------------------------------------------------
apply_theme() {
    mkdir -p "$(dirname "$OVERLAY")"
    if [ ! -f "$OVERLAY" ]; then
        run "cat > '$OVERLAY' <<'JSON'
{
  \"name\": \"Dracula Local Overlay\",
  \"colors\": {
    \"success\": \"#50FA7B\"
  }
}
JSON"
        log "wrote $OVERLAY (success: #50FA7B added to official Dracula base)"
    else
        log "overlay already exists: $OVERLAY"
    fi
    run "dms ipc call theme set custom '$OVERLAY' >/dev/null 2>&1 || true"
    mark theme_applied
}

# ---------------------------------------------------------------------------
set_fonts() {
    # Roboto Serif Condensed (UI) + Fira Code (monospace) are already chosen.
    # Roboto Serif must be installed user-local; Fira Code is bundled in DMS.
    if fc-match 'Roboto Serif' | grep -qi 'roboto serif'; then
        log "Roboto Serif available"
    else
        warn "Roboto Serif not installed; install to ~/.local/share/fonts (user-local)"
    fi
    run "dms ipc call settings set fontFamily 'Roboto Serif Condensed' >/dev/null 2>&1 || true"
    run "dms ipc call settings set monoFontFamily 'Fira Code' >/dev/null 2>&1 || true"
    run "dms ipc call settings set fontScale 1.2 >/dev/null 2>&1 || true"
    mark fonts_set
}

# ---------------------------------------------------------------------------
set_wallpaper() {
    if [ ! -f "$WALLPAPER" ]; then
        warn "wallpaper asset missing: $WALLPAPER (download from dracula/wallpaper first-collection/base.png)"
        return 0
    fi
    run "dms ipc call wallpaper set '$WALLPAPER' >/dev/null 2>&1 || true"
    mark wallpaper_set
}

# ---------------------------------------------------------------------------
install_gtk_theme() {
    if [ -d "$THEME_DIR" ]; then
        log "Dracula GTK theme already installed: $THEME_DIR"
    else
        warn "Dracula GTK theme not installed; clone dracula/gtk to $THEME_DIR"
    fi
    run "gsettings set org.gnome.desktop.interface gtk-theme 'Dracula' 2>/dev/null || true"
    run "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true"
    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        mkdir -p "$(dirname "$ini")"
        if ! grep -q '^gtk-theme-name=Dracula' "$ini" 2>/dev/null; then
            run "echo 'gtk-theme-name=Dracula' >> '$ini'"
        fi
    done
    mark gtk_theme_set
}

# ---------------------------------------------------------------------------
stage_qt_theme() {
    # User-local Kvantum theme + qt6ct Dracula palette. Host Qt5 theming is
    # deliberately not configured; packages (kvantum, qt6ct) need one reboot.
    if marked qt_theme_staged; then log "Qt Dracula layer already staged"; return 0; fi
    local tmp="/tmp/dracula-gtk"
    run "git clone --depth 1 https://github.com/dracula/gtk.git '$tmp' 2>/dev/null || true"
    if [ "$DRY_RUN" -eq 0 ] && [ -d "$tmp/.git" ] && \
       [ "$(git -C "$tmp" rev-parse HEAD)" != "$DRACULA_GTK_REV" ]; then
        die "dracula/gtk revision changed; review and update DRACULA_GTK_REV before applying"
    fi
    [ -d "$tmp/kde/kvantum/Dracula" ] || die "could not fetch dracula/gtk Kvantum theme"
    mkdir -p "$HOME/.config/Kvantum" "$HOME/.config/qt6ct/colors"
    run "rm -rf '$HOME/.config/Kvantum/Dracula'"
    run "cp -r '$tmp/kde/kvantum/Dracula' '$HOME/.config/Kvantum/Dracula'"
    run "curl -fsSL https://raw.githubusercontent.com/dracula/qt5/$DRACULA_QT5_REV/Dracula.conf -o '$HOME/.config/qt6ct/colors/Dracula.conf'"
    run "printf '[General]\ntheme=Dracula\n' > '$HOME/.config/Kvantum/kvantum.kvconfig'"
    run "printf '[Appearance]\nstyle=kvantum\ncolor_scheme_path=%s/.config/qt6ct/colors/Dracula.conf\ncustom_palette=true\nicon_theme=breeze-dark\nstandard_dialogs=xdgdesktopportal\n' \"\$HOME\" > \"\$HOME/.config/qt6ct/qt6ct.conf\""
    mkdir -p "$HOME/.config/environment.d"
    run "printf 'QT_QPA_PLATFORMTHEME=qt6ct\n' > '$HOME/.config/environment.d/91-qt-theme.conf'"
    warn "packages still needed (sudo+reboot): rpm-ostree install kvantum qt6ct"
    mark qt_theme_staged
}

# ---------------------------------------------------------------------------
set_locale() {
    # Requires sudo. Sets en_CA UI + fr_CA regional formats.
    if marked locale_set; then log "locale already set"; return 0; fi
    warn "locale step needs sudo: localectl set-locale LANG=en_CA.UTF-8 LC_NUMERIC=fr_CA.UTF-8 LC_TIME=fr_CA.UTF-8 LC_MONETARY=fr_CA.UTF-8 LC_MEASUREMENT=fr_CA.UTF-8 LC_PAPER=fr_CA.UTF-8"
    if [ "$DRY_RUN" -eq 0 ]; then
        sudo localectl set-locale \
            LANG=en_CA.UTF-8 \
            LC_NUMERIC=fr_CA.UTF-8 LC_TIME=fr_CA.UTF-8 \
            LC_MONETARY=fr_CA.UTF-8 LC_MEASUREMENT=fr_CA.UTF-8 LC_PAPER=fr_CA.UTF-8 \
            && mark locale_set || warn "locale set failed (sudo needed)"
    fi
}

# ---------------------------------------------------------------------------
set_sddm() {
    # Requires sudo. Selects dracula-qt6 and forces the greeter locale.
    if marked sddm_set; then log "sddm already configured"; return 0; fi
    warn "sddm step needs sudo (select dracula-qt6 + GreeterEnvironment)"
    if [ "$DRY_RUN" -eq 0 ]; then
        sudo mkdir -p /etc/sddm.conf.d
        sudo tee /etc/sddm.conf.d/z-dracula-qt6.conf >/dev/null <<'EOF'
[Theme]
ThemeDir=/etc/sddm/themes
Current=dracula-qt6
EOF
        sudo tee /etc/sddm.conf.d/90-greeter-locale.conf >/dev/null <<'EOF'
[General]
GreeterEnvironment=LANG=en_CA.UTF-8,LC_NUMERIC=fr_CA.UTF-8,LC_TIME=fr_CA.UTF-8,LC_MONETARY=fr_CA.UTF-8,LC_MEASUREMENT=fr_CA.UTF-8,LC_PAPER=fr_CA.UTF-8
EOF
        # Remove any competing theme selection (e.g. maldives) if present.
        if [ -f /etc/sddm.conf.d/theme.conf ]; then
            sudo mv -f /etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf.disabled
        fi
        mark sddm_set || warn "sddm config failed (sudo needed)"
    fi
}

# ---------------------------------------------------------------------------
install_ideapad() {
    # Requires sudo for rpm-ostree install (one reboot).
    # Accelerometer auto-rotate — no evtest, no input-group needed for the
    # script itself (monitor-sensor reads the sensor over D-Bus). The `input`
    # group is still recommended for DMS evdev manager (see dms doctor).
    if marked ideapad_installed; then log "ideapad handler already installed"; return 0; fi
    warn "ideapad step needs sudo + reboot: rpm-ostree install iio-sensor-proxy"
    if [ "$DRY_RUN" -eq 0 ]; then
        sudo rpm-ostree install iio-sensor-proxy
        # Copy script + service from the repo if missing at the live paths.
        local repo_dir
        repo_dir="$(cd "$(dirname "$0")" && pwd)"
        if [ ! -f "$IDEPAD_SCRIPT" ]; then
            mkdir -p "$(dirname "$IDEPAD_SCRIPT")"
            run "cp -f '$repo_dir/ideapad-tablet.sh' '$IDEPAD_SCRIPT'"
            run "chmod +x '$IDEPAD_SCRIPT'"
            log "installed $IDEPAD_SCRIPT from repo"
        fi
        if [ ! -f "$IDEPAD_SVC" ]; then
            mkdir -p "$(dirname "$IDEPAD_SVC")"
            run "cp -f '$repo_dir/ideapad-tablet.service' '$IDEPAD_SVC'"
            log "installed $IDEPAD_SVC from repo"
        fi
        systemctl --user enable --now ideapad-tablet.service 2>/dev/null || \
            warn "enable ideapad-tablet.service after reboot+login"
        mark ideapad_installed || warn "ideapad install incomplete (sudo/reboot needed)"
    fi
}

# ---------------------------------------------------------------------------
rollback() {
    log "rolling back user-level changes"
    if [ -f "$NIRI_BACKUP" ]; then
        run "mv -f '$NIRI_BACKUP' '$NIRI_CONFIG'"
        log "restored niri config from backup"
    fi
    for f in "$OVERLAY" "$IDEPAD_SCRIPT" "$IDEPAD_SVC"; do
        [ -f "$f" ] && run "rm -f '$f'" && log "removed $f"
    done
    warn "system-level changes (locale, sddm, rpm-ostree layers) are NOT auto-rolled-back; review manually"
    rm -f "$STATE_FILE"
}

# ---------------------------------------------------------------------------
main() {
    mkdir -p "$STATE_DIR"
    if [ "$ROLLBACK" -eq 1 ]; then rollback; return 0; fi
    log "applying Wayblue/Niri + DMS + Dracula setup"
    backup_niri
    integrate_dms
    set_fonts
    set_wallpaper
    set_locale
    set_sddm
    install_ideapad
    # The theme is deliberately last: apps/layers first, then Dracula.
    apply_theme
    install_gtk_theme
    stage_qt_theme
    warn "after the reboot, run scripts/apply-dracula-theme.sh to theme detected Flatpaks"
    log "done. Reboot once for rpm-ostree changes to take effect."
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --rollback) ROLLBACK=1 ;;
        *) die "unknown arg: $1" ;;
    esac
    shift
done

main
