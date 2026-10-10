# Application Dracula — phase finale post-install

> **But** : spécification destinée à un AI pour générer ou maintenir un module
> d'application Dracula. Cette phase intervient **après** l'installation des
> applications, puis après le reboot qui applique les layers `rpm-ostree`.
> Elle détecte ce qui existe réellement ; elle ne thématise pas des applications
> absentes ni ne réinstalle de paquets pour la seule apparence.

## Règles strictes

1. La phase Dracula est la **dernière** phase de post-install : applications,
   Flatpaks et layers dnf d'abord ; thème ensuite.
2. Qt6 > Qt5 ; KDE est préféré quand il est disponible sans Plasma Desktop/Shell.
3. Flatpak > dnf pour les applications, mais l'application du thème doit respecter
   le sandbox : jamais supposer que la configuration hôte est visible.
4. Consommer une source Dracula officielle et **pincée**. Conserver les écarts
   locaux dans `overlays/`, avec provenance et raison documentées.
5. Ne jamais installer ou configurer `qt5ct`. Le thème hôte Qt est
   `kvantum` (Qt6 Fedora) + `qt6ct`.
6. Conserver les applications GTK Flatpak nécessaires, notamment Firefox. Leur
   thème n'est pas un motif pour les supprimer ni pour définir `GTK_THEME`
   globalement.

## Surfaces à appliquer, dans cet ordre

### 1. DMS et SDDM

- DMS consomme l'upstream Dracula pincé ; l'overlay local ne contient que le
  rôle `success: #50FA7B`.
- SDDM reste un changement système séparé (`dracula-qt6`) et doit vérifier que
  le thème est réellement présent avant de toucher `/etc/sddm.conf.d`.

### 2. Qt6 hôte

Préconditions : `~/.config/Kvantum/Dracula/` et
`~/.config/qt6ct/qt6ct.conf` existent.

- `~/.config/Kvantum/kvantum.kvconfig` sélectionne `Dracula`.
- `qt6ct.conf` sélectionne `style=kvantum` et le palette Dracula.
- `~/.config/environment.d/91-qt-theme.conf` contient
  `QT_QPA_PLATFORMTHEME=qt6ct`.
- Les apps RPM Qt6 (Spectacle, KDE Partition Manager, pavucontrol-qt) seront
  thématisées au boot suivant si ces préconditions sont satisfaites.

### 3. Flatpaks Qt/KDE

1. Découvrir les applications et runtimes avec :
   `flatpak list --app --columns=application,runtime`.
2. Pour chaque branche `org.kde.Platform`, vérifier que
   `org.kde.KStyle.Kvantum//$BRANCH` existe sur Flathub.
3. Installer seulement les extensions disponibles.
4. Appliquer **par application** (pas globalement) :

   ```bash
   flatpak override --user \
     --env=QT_STYLE_OVERRIDE=kvantum \
     --filesystem=xdg-config/Kvantum:ro APP_ID
   ```

5. Ne pas définir `QT_QPA_PLATFORMTHEME=qt6ct` dans les sandboxes : la config
   hôte n'implique pas que le plugin `qt6ct` est présent dans leur runtime.
   Préserver l'override global existant qui le désactive.
6. Si l'extension Kvantum de la branche est absente, conserver Breeze et le
   signaler ; ne pas forcer un plugin manquant.

Observation actuelle (pas une règle intemporelle) : Flathub fournit Kvantum pour
les branches 6.10 et 5.15-25.08, pas pour 6.11.

### Repli temporaire pour Flatpak KDE 6.11

Si une application KDE 6.11 ne peut pas recevoir Kvantum et qu'un RPM Fedora
**Qt6** existe, un basculement temporaire vers dnf est permis pour maintenir
une apparence Dracula cohérente. C'est un repli visuel, pas un abandon de la
priorité Flatpak.

| Flatpak 6.11 | RPM Qt6 temporaire |
|---|---|
| Deskflow | `deskflow` |
| Fedora Media Writer | `mediawriter` |
| Haruna | `haruna` |
| Qrca | `qrca` |
| Skanpage | `skanpage` |
| Kontainer, KTailctl | aucun RPM Fedora trouvé : restent Flatpak |

Procédure sûre : (1) `rpm-ostree install` les RPM, (2) reboot, (3) vérifier
leur démarrage et le thème hôte, puis seulement (4) désinstaller les Flatpaks
équivalents. Revenir aux Flatpaks dès qu'une extension
`org.kde.KStyle.Kvantum//6.11` est publiée et validée.

### 4. GTK résiduel et Firefox

- Appliquer `prefer-dark` via GSettings et utiliser Dracula sur l'hôte seulement
  si `~/.local/share/themes/Dracula/` existe déjà.
- Pour Firefox Flatpak, donner en lecture seule accès aux fichiers GTK et aux
  thèmes XDG (`gtk-3.0`, `gtk-4.0`, `xdg-data/themes`) ; ne jamais exporter
  `GTK_THEME` globalement.
- Firefox reste Flatpak GTK : c'est une exception explicitement conservée.

## Contrat du script `scripts/apply-dracula-theme.sh`

- Idempotent, `--dry-run`, `--rollback`, sans secrets.
- Sauvegarde les fichiers utilisateur qu'il modifie.
- N'acquiert pas de thème upstream non pincé : il applique les assets déjà
  installés/validés et avertit si une précondition manque.
- Enregistre les Flatpaks qu'il modifie afin que le rollback retire uniquement
  `QT_STYLE_OVERRIDE=kvantum` et l'accès Kvantum ajoutés par le module.
- S'exécute après `post-install-qt.sh` et après le reboot des layers dnf.

## Sources

- Flatpak sandbox permissions : <https://docs.flatpak.org/en/latest/sandbox-permissions.html>
- Politique Dracula locale : [`upstream-dracula.md`](upstream-dracula.md)
  et [`theme-evaluation.md`](theme-evaluation.md)
