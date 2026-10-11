# Plan de migration GTK → Qt (wayblue/niri — Fedora Atomic)

> **But de ce document** : être un plan **explicite et consommable par un AI** pour
> générer un script post-install, en appliquant les règles ci-dessous. L'image de base
> (wayblue) peut changer entre versions → le script doit être (re)généré à partir de
> l'état réel de la cible, pas d'une liste figée.

## Règles de décision (priorité stricte, ordonnée)
1. **Qt6 > Qt5** — choisir Qt6 sauf si aucun équivalent Qt6 n'existe.
2. **KDE en priorité** — parmi les remplaçants Qt, préférer une app KDE, tant qu'elle
   ne tire **pas** tout l'environnement Plasma (vérifier l'absence de dépendance `plasma-*`).
3. **Flatpak > dnf** — pour toute app (KDE ou non-KDE), préférer le Flatpak si dispo sur Flathub.
4. **dnf en dernier recours** — `rpm-ostree install` seulement pour ce qui n'est pas sur Flathub.
5. **Atomic : ne jamais purger le stack GTK de base** — gtk3/gtk4/webkit2gtk/libadwaita/stack
   XFCE sont cuits dans l'image ; on ne les retire pas (fragile + ré-ajoutés au upgrade).
   **Mais** si un paquet GTK est **layered** (ajouté par `rpm-ostree install`) et a un
   remplaçant Qt → on le **purge** (`rpm-ostree uninstall`) après installation du remplaçant,
   pour garder le système propre.
   **Exception** : les apps GTK en **Flatpak** (ex. Firefox) ne sont pas remplaçables
   proprement → on les garde.

## Contraintes environnement
- Fedora Atomic (wayblue/niri, Wayland). Base immuable → Flatpak = mécanisme d'app recommandé
  (base propre, runtimes Qt6/KF6 auto-bundlés, marche hors Plasma).
- Seuls les paquets *layered* se retirent proprement (`rpm-ostree uninstall`).
- `rpm-ostree install` = nouveau déploiement → **reboot requis** pour appliquer.

## Mapping GTK → Qt (par fonction)
| Fonction | App GTK | Remplaçant Qt | Source | Note |
|---|---|---|---|---|
| Fichiers | Thunar | Dolphin | Flatpak `org.kde.dolphin` | KDE, autonome |
| Archives | xarchiver | Ark | Flatpak `org.kde.ark` | KDE, autonome |
| Captures | (outil GTK) | Spectacle | dnf `spectacle` | absent Flathub, KDE, pas de `plasma-*` |
| Son (volume) | pavucontrol | pavucontrol-qt | dnf `pavucontrol-qt` | pas de Flatpak Qt (celui de Flathub est GTK) |
| Disques/partitions | gnome-disk-utility | kde-partitionmanager (+ gsmartcontrol opt.) | dnf `kde-partitionmanager` | absent Flathub |
| Trousseau | gcr3 / gnome-keyring UI | kwalletmanager | Flatpak `org.kde.kwalletmanager` | KDE, autonome |
| Images | viewer GTK | Gwenview | Flatpak `org.kde.gwenview` | déjà installé |
| PDF | viewer GTK | Okular | Flatpak `org.kde.okular` | déjà installé |
| Éditeur texte | GTK | Kate | Flatpak `org.kde.kate` | KDE, autonome |
| Terminal | GTK | Konsole | Flatpak `org.kde.konsole` | KDE, autonome |
| Calculatrice | — | KCalc | Flatpak `org.kde.kcalc` | déjà installé |
| Navigateur | Firefox | gardé (Flatpak GTK) | Flatpak | pas d'équivalent Qt mature préféré ici |
| Barre statut | waybar | — | — | **bloqué** : pas de barre Qt6 drop-in |
| Bluetooth | blueman | — | — | **bloqué** : pas de GUI Qt autonome |
| Firewall | firewall-config | — | — | **bloqué** : pas d'équivalent Qt autonome |
| Réseau | network-manager-applet | — | — | **partiel** : pas de GUI Qt packagée (nm-tray absent Fedora) |
| Lanceur | wofi, fuzzel | DMS spotlight | intégré DMS (Qt/QML) | **résolu** : DMS spotlight (`Mod+Space`) est le lanceur principal. fuzzel (`Mod+D`) désactivé. wofi/fuzzel sont de base (non purgable). |

## Spécification de génération de script (post-install)
Le script doit être **généré dynamiquement** à partir de l'état réel de la cible :

1. **Découverte** des apps GTK installées :
   `dnf repoquery --installed --whatrequires gtk3 gtk4` puis filtrer les apps
   user-facing (exclure les libs / paquets de base).
2. **Pour chaque app GTK**, appliquer l'ordre de règles pour choisir le remplaçant :
   Qt6 > Qt5 → KDE > non-KDE → Flatpak > dnf → sinon conserver.
   Si aucun remplaçant Qt packagé → marquer « bloqué », ne rien faire.
3. **Émission des commandes** :
   - Flatpaks : `flatpak install --noninteractive flathub <app-id>` (regrouper).
   - dnf : un seul `rpm-ostree install <pkgs...>` groupé (reboot requis après).
4. **Purge sélective** : pour chaque app GTK **layered** ayant un remplaçant Qt installé,
   émettre `rpm-ostree uninstall <gtk-pkg>` (propre car layered). Ne jamais tenter de
   retirer un paquet GTK de **base** (échouerait / ré-ajouté au upgrade). Les apps GTK en
   **Flatpak** (Firefox) sont ignorées (gardées).

## Commandes finales (concètes, référence)
```bash
# Flatpak (KDE)
flatpak install --noninteractive flathub org.kde.dolphin org.kde.ark org.kde.kate \
  org.kde.konsole org.kde.kwalletmanager
# déjà installés : org.kde.gwenview, org.kde.okular, org.kde.kcalc

# dnf layered (hors-Flathub)
rpm-ostree install spectacle kde-partitionmanager pavucontrol-qt
# puis : systemctl reboot
```

## Vérifications établies
- `spectacle` et `kde-partitionmanager` : **aucune** dépendance `plasma-*` (que KF6/Qt6)
  → install dnf safe (ne tire pas Plasma).
- Sur Flathub : dolphin, ark, gwenview, kate, kcalc, konsole, kwalletmanager, okular.
  **Absents** de Flathub : spectacle, kde-partitionmanager.
- `pavucontrol-qt` non dispo en Flatpak (le Flatpak « Volume Control » est le pavucontrol
  **GTK**) → reste en dnf pour rester en Qt.
- Nom Fedora correct de Partition Manager = **`kde-partitionmanager`** (pas `partitionmanager`).
