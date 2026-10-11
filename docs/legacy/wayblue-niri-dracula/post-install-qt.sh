#!/usr/bin/env bash
#
# post-install-qt.sh — migration GTK -> Qt selon le plan QT_MIGRATION.md
# Regles: Qt6>Qt5, KDE>non-KDE, Flatpak>dnf, purge du GTK *layered* remplacable,
#         garde les apps GTK en Flatpak (ex. Firefox).
# Dynamique: inspecte l'etat reel de la cible (wayblue evolue entre versions).
set -euo pipefail

echo "==> Migration GTK -> Qt (plan QT_MIGRATION.md)"

# 1. Paquets LAYERED (on ne purge QUE ceux-la, jamais la base image)
layered=$(rpm-ostree status --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    dep = d.get('deployments', [{}])[0]
    print(' '.join(dep.get('layered-packages', [])))
except Exception:
    pass
")
is_layered() { echo " $layered " | grep -q " $1 "; }

# 2. Decouverte des apps GTK installees (rpm uniquement, pas les Flatpaks)
gtk_apps=$(dnf repoquery --installed --qf '%{name}' --whatrequires gtk3 gtk4 2>/dev/null | sort -u)

flatpak_install=()
dnf_install=()
purge_list=()

for app in $gtk_apps; do
  case "$app" in
    Thunar)                  flatpak_install+=(org.kde.dolphin);      purge_list+=("$app");;
    xarchiver)               flatpak_install+=(org.kde.ark);         purge_list+=("$app");;
    gnome-disk-utility)      dnf_install+=(kde-partitionmanager);    purge_list+=("$app");;
    gcr3|libgnome-keyring|gnome-keyring) flatpak_install+=(org.kde.kwalletmanager);;
    pavucontrol)             dnf_install+=(pavucontrol-qt);          purge_list+=("$app");;
    *) ;; # non mappe / bloque : on garde
  esac
done

# 3. Installation des remplacants Qt
if [ ${#flatpak_install[@]} -gt 0 ]; then
  echo "==> Flatpaks: ${flatpak_install[*]}"
  flatpak install --noninteractive flathub "${flatpak_install[@]}"
fi
if [ ${#dnf_install[@]} -gt 0 ]; then
  echo "==> rpm-ostree install: ${dnf_install[*]}"
  rpm-ostree install "${dnf_install[@]}"
fi

# 4. Purge selective des GTK LAYERED remplacables (jamais la base)
purge=()
for p in "${purge_list[@]:-}"; do
  [ -n "$p" ] || continue
  is_layered "$p" && purge+=("$p")
done
if [ ${#purge[@]} -gt 0 ]; then
  echo "==> Purge GTK layered remplacable: ${purge[*]}"
  rpm-ostree uninstall "${purge[@]}" || echo "  (purge ignoree: $p non layered?)"
fi

echo "==> Fait. Reboot requis pour appliquer rpm-ostree: systemctl reboot"
echo "    Firefox (Flatpak GTK) et apps bloquees sont volontairement conservees."
