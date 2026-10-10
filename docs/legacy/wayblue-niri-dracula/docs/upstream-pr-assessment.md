# Upstream Dracula pull-request opportunities

Assessment of what we built that could be contributed upstream vs kept local.

## Already official (no PR needed)
- Dracula GTK theme: from `dracula/gtk` (official). We installed it as-is.
- Dracula SDDM theme: `dracula-qt6` (official). Applied as-is.
- Dracula wallpaper: `dracula/wallpaper` `first-collection/base.png` (official,
  SHA-256 verified identical to our asset).
- Dracula KDE/Qt color scheme + Kvantum: from `dracula/gtk` `kde/` and
  `dracula/qt5` (official).

## Local-only (candidate for sharing)
- `dracula-local-overlay.json`: a DMS theme overlay. If `dracula/dms` accepts
  community themes, this is a PR candidate. Otherwise keep local.
- `ideapad-tablet.sh` + systemd user service: generic Niri/Wayblue tablet-mode
  handler for IdeaPad Flex. Good candidate for a dotfiles/wayblue community repo
  or a small standalone project. Not Dracula-specific.
- Installer script (see `scripts/`): personal provisioning; generalize before
  sharing.

## Deferred
- Confirm with user which (if any) should be upstreamed, and under what license.
- DMS hardcoded Material-color patch (see `dms-material-patch-plan.md`) is the
  main code contribution candidate, but only after fork + validation.
