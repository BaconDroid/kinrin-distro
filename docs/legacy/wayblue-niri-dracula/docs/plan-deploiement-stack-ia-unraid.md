# Plan de déploiement — Stack IA locale sur Unraid

**Matériel :** i5-11500 (11e gen) · 41.6 GiB RAM libre · 870 GB SSD libre · UHD 750 (iGPU) · Arc A380 6GB (discret, usagé, retour Amazon)
**Carte mère :** MSI B560 (Click BIOS 5) — modèle exact à confirmer
**Modèle cible :** Qwen3.6-35B-A3B (MoE, 3B actifs, Q4 ~26.6GB)
**Rôle :** Orchestrator local pour IA

---

## Section 0B — Settings BIOS (MSI B560, Click BIOS 5)

⚠️ **Fais AVANT la Section 0A** — certains changements de BIOS nécessitent un reboot, et le stress test de la Section 0A ne doit tourner qu'avec la bonne config.

> Le modèle exact de ta carte mère MSI B560 n'est pas confirmé (PRO-VDH? MAG? MPG?). Les menus ci-dessous sont typiques d'un MSI B560 Click BIOS 5 — le nom exact peut varier légèrement. Entrée dans le BIOS : touche **DEL** au boot.

### GPU / PCIe (A380 + iGPU)

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **Above 4G Decoding** | **Enabled** | Prérequis pour ReBAR. Sans ça, l'A380 ne peut pas mapper sa VRAM >4GB. Se trouve sous "PCI Subsystem Settings" ou "Advanced > PCI Configuration". |
| **Re-Size BAR Support** | **Enabled** (ou Auto) | **Obligatoire pour Intel Arc.** Intel le recommande officiellement — sans ReBAR, les performances chutent drastiquement et la stabilité est compromise. N'apparaît qu'après avoir activé Above 4G Decoding. |
| **Internal Graphics (IGFX)** | **Enabled** | Garde l'iGPU UHD 750 actif en parallèle. Utile pour le display de base et en fallback. |

### Stabilité HBA (LSI 9200-8i)

> Le LSI 9200-8i (chipset SAS2308, firmware MPI v2.0) est **notoirement sensible** aux états d'économie d'énergie PCIe. Le driver Linux `mpt2sas` **force désactivé ASPM** sur ce chipset depuis 2013 (bug report #14992) à cause de crashes sous charge. Le laisser activer en BIOS peut provoquer des timeouts, des resets du HBA, et des erreurs de lecture/disque.

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **C-States (C1E, C3, C6)** | **Disabled** ou **Minimal (C1 uniquement)** | Les C-States profonds provoquent des timeouts/resets sur le HBA. Forums Unraid : le HBA empêche le système d'atteindre C2+ et les transitions D3hot→D0 sont source de crashes. |
| **ASPM (PCIe Active State Power Management)** | **Disabled** | Le driver `mpt2sas` désactive ASPM côté software, mais le BIOS peut forcer des transitions de puissance incompatibles. Désactive-le côté BIOS aussi pour être safe. Parfois sous "PCI Subsystem Settings" > "ASPM" ou "Platform Power Management". |

### Boot / UEFI

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **CSM (Compatibility Support Module)** | **Disabled** | Boot en UEFI pur. ReBAR et Above 4G Decoding nécessitent UEFI. Unraid boot en UEFI nativement. |
| **Secure Boot** | **Disabled** (sauf si tu as signé le bootloader Unraid toi-même) | Évite les problèmes de boot. Unraid utilise un bootloader non signé par défaut. |
| **Fast Boot** | **Disabled** | Évite les problèmes d'accès au BIOS après un reboot. |

### Virtualisation

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **VT-x (Intel Virtualization Technology)** | **Enabled** | Nécessaire pour Docker/containers. Normalement déjà actif. |
| **VT-d (Intel Virtualization for Directed I/O)** | **Enabled** | Améliore l'isolation IOMMU. Utile si tu veux isoler proprement la A380 ou le HBA entre containers/VMs. |
| **SR-IOV** | **Disabled** (pour l'instant) | Partage GPU entre VMs — pas utile maintenant, garder en tête pour plus tard. |

### Mémoire

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **XMP Profile** | **Profile 1** (ou le profil de ta RAM) | Active les fréquences et timings annoncés par le fabricant. Sans XMP, la RAM tourne à la vitesse JEDEC (2133/2666 MHz). Le B560 autorise l'overclocking RAM (contrairement au B460). |
| **Gear Mode (CPU IMC:DRAM Clock)** | **Gear 1** si possible | Gear 1 = IMC = fréquence RAM (latence basse). Gear 2 = IMC à moitié (latence élevée). DDR4-3200 ou moins → Gear 1. DDR4-3600+ → vérifie la stabilité. |

### Puissance / Divers

| Setting | Valeur | Pourquoi |
|---------|--------|----------|
| **Wake-on-LAN** | **Enabled** (optionnel) | Réveiller le NAS à distance. |
| **ErP Ready** | **Disabled** | Si activé, coupe l'alimentation au repos — peut empêcher le Wake-on-LAN et USB de fonctionner en veille. |
| **Audio Controller (onboard)** | **Disabled** | Inutile sur un NAS. Libère des ressources IRQ/PCI. |
| **Serial Port / Parallel Port** | **Disabled** | Inutile. Libère des IRQ. |
| **Platform Power Management** | **Disabled** | Évite les transitions de puissance PCIe qui peuvent affecter le HBA et le GPU. |

### Après changement de BIOS

```bash
# Vérifier que ReBAR est bien actif
dmesg | grep -i "resize\|LMEM BAR"
```
Si tu vois encore `Can't resize LMEM BAR - platform support is missing` malgré les bonnes options, ta carte mère MSI ne supporte pas ReBAR sur ce slot — c'est une limite plateforme, pas un défaut de la A380.

### ✅ Checkpoint BIOS
Tous les settings appliqués, reboot, `dmesg` clean → passe à la Section 0A.

---

## Section 0A — Valider l'A380 usagé AVANT tout le reste

⚠️ **Fais cette section en premier et vite** — c'est un retour Amazon, reste dans la fenêtre de retour au cas où.

### 0.1 Ajuster le BIOS (avant tout le reste)

**ReBAR / GPU (le nécessaire pour l'A380) :**
- [ ] Activer **Above 4G Decoding** (souvent un prérequis caché pour ReBAR)
- [ ] Activer **Re-Size BAR Support**
- [ ] Vérifier **Internal Graphics / IGFX = Enabled** (garder l'iGPU actif en parallèle)

**Stabilité HBA (le LSI 9200-8i est sensible à ça) :**
- [ ] Désactiver ou minimiser les **C-States** (C1E, C3, C6) — les états d'économie d'énergie profonds sont une cause classique de timeouts/resets sur les disques connectés au HBA
- [ ] Désactiver l'**ASPM** (PCIe Active State Power Management, parfois sous "PCI Subsystem Settings" ou "Power Management") — cause d'instabilités connues avec HBA et GPU sous charge

**Boot / UEFI :**
- [ ] Désactiver le **CSM (Compatibility Support Module)**, boot en UEFI pur
- [ ] Désactiver **Secure Boot** (sauf si t'as signé le bootloader Unraid toi-même)
- [ ] Désactiver **Fast Boot** si t'as de la misère à rentrer dans le BIOS après un reboot

**Virtualisation (utile même en restant 100% Docker pour l'instant) :**
- [ ] Activer **VT-d** (Intel Virtualization for Directed I/O) — améliore l'isolation IOMMU, utile si tu passthrough éventuellement le HBA ou isoles la A380 proprement
- [ ] Vérifier **VT-x** activé (normalement déjà le cas)
- [ ] **SR-IOV** si dispo et pertinent pour toi plus tard (partage GPU entre VMs/containers), sinon laisse tel quel

**Mémoire :**
- [ ] Activer **XMP/DOCP** si ta RAM a un profil et qu'il est pas déjà actif

**Divers (mineur mais gratuit) :**
- [ ] **Wake-on-LAN** activé si tu veux réveiller le NAS à distance
- [ ] Désactiver l'audio/série/parallèle onboard inutilisés — libère des ressources IRQ/PCI

- [ ] Reboot après changement de BIOS
- [ ] Après reboot, vérifie que `dmesg | grep -i "resize\|LMEM BAR"` ne montre plus `Can't resize LMEM BAR - platform support is missing`. Si le message persiste malgré les bonnes options activées, ta carte mère (MSI) ne supporte simplement pas ReBAR sur ce slot — c'est une limite plateforme, pas un défaut de la A380, continue quand même les tests ci-dessous.

### 0.2 Installation physique
- [ ] Déplacer le HBA de la 1ère slot PCIe vers une slot secondaire
- [ ] Installer l'A380 dans la 1ère slot (x16, câblée direct au CPU)
- [ ] Vérifier que les câbles SAS/SATA du HBA atteignent sa nouvelle position
- [ ] Reboot

### 0.3 Confirmer la détection
```bash
lspci -v | grep -A 10 -i "VGA\|Display"
```
Tu dois voir **deux** contrôleurs : UHD 750 (iGPU, ex. `00:02.0`) et Arc A380 DG2/G11 (discret, ex. `03:00.0`).

```bash
ls -la /sys/class/drm/ | grep card
```
Identifie quel `cardX` correspond au chemin PCI de la A380 (`.../0000:03:00.0/drm/cardX`) — tu en auras besoin pour 0.4 et 0.5.

### 0.4 Tests natifs — driver, PCIe, fréquence (zéro installation)

**Chargement driver — cherche les erreurs, pas juste la présence de la carte :**
```bash
dmesg | grep -i "arc\|dg2\|a380"
```
Signes sains : `DG2/G11 ... display version`, firmware **GuC**/**HuC** chargés, `GUC: submission enabled`, `HuC: authenticated for all workloads`. `Cannot find any crtc or sizes` est normal sur un GPU headless (pas d'écran branché).

**Hangs/resets (ignore les resets de disques/HBA `sd X:X:X:X`, ça n'a rien à voir) :**
```bash
dmesg -w | grep -i "hang\|reset\|error"
```
Laisse tourner en arrière-plan pendant le stress test (0.5) — n'importe quelle ligne qui touche `i915 0000:03:00.0` = red flag.

**Erreurs PCIe (signe classique de carte ou slot défectueux physiquement) :**
```bash
lspci -vv -s 03:00.0 | grep -i "devsta\|correctable\|uncorrectable"
```
Cherche `CorrErr-`, `NonFatalErr-`, `FatalErr-`, `UnsupReq-` (tous à `-` = clean). N'importe lequel à `+` = à surveiller de près.

**Fréquence GPU en temps réel (remplace `card1` par le numéro trouvé en 0.3) :**
```bash
watch -n1 'echo "act:"; cat /sys/class/drm/card1/gt_act_freq_mhz; echo "cur:"; cat /sys/class/drm/card1/gt_cur_freq_mhz; echo "max:"; cat /sys/class/drm/card1/gt_max_freq_mhz'
```
Garde ce terminal ouvert pendant 0.5 — la fréquence doit monter sous charge et rester stable, pas stagner près de 0 ni s'effondrer en cours de route.

### 0.5 Stress test réel (génère une charge — les tests de 0.4 ne font que surveiller)
Un défaut caché dans la VRAM ne sort que sous stress soutenu.

**Le test principal — FFmpeg/VAAPI via Docker (natif à Unraid, aucun package système à installer) :**

**Image recommandée : `linuxserver/ffmpeg`** — maintenue activement (dernière MàJ : 25.06.26), inclut les drivers Intel iHD + i965 à jour pour les Arc (DG2/Alchemist), supporte VAAPI nativement.

> **⚠️ Installation manuelle requise :** `linuxserver/ffmpeg` n'est **pas dans Community Apps**. Installe-le manuellement via Docker > Add Container :
> - Repository : `linuxserver/ffmpeg`
> - Pas besoin de port ou de volume persistant — c'est une image éphémère
> - Tu peux aussi simplement `docker pull linuxserver/ffmpeg` et lancer en CLI

```bash
docker run --rm -it --device=/dev/dri:/dev/dri linuxserver/ffmpeg \
  -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
  -f lavfi -i testsrc=size=3840x2160:rate=60 -t 3600 \
  -vf 'format=nv12,hwupload' -c:v h264_vaapi -b:v 20M -f null -
```
(vérifie que `renderD128` pointe bien vers la A380 et pas l'iGPU)

> **Note :** `spaceinvaderone/ollama-intel-gpu` (utilisé en section 1) est une image minimaliste (Ubuntu 24.04 + Ollama + drivers Intel GPU). Elle **ne contient PAS ffmpeg** et ne peut pas servir pour les tests VAAPI. Ce sont deux images complètement séparées.

**Identifier le bon render node avant de lancer quoi que ce soit :**
```bash
ls -la /dev/dri/by-path/ | grep 03:00.0
```
(remplace `03:00.0` par l'adresse PCI de ta A380 trouvée en 0.3) — le lien symbolique `pci-0000:03:00.0-render` te donne le vrai `renderDXXX` à utiliser dans la commande.

**Script automatisé — lance le test, valide, et te donne juste un verdict**

Pas besoin de lire `dmesg` ou les logs ffmpeg toi-même — le script fait les 4 checks (code de sortie, nombre de frames encodées, erreurs dans les logs ffmpeg, hangs/resets kernel) et affiche juste ✅ ou ❌ à la fin.

```bash
cat > /root/test-a380.sh << 'EOF'
#!/bin/bash
set -uo pipefail

RENDER_NODE="/dev/dri/renderD128"   # ajuste selon le résultat de la commande ls -la /dev/dri/by-path/
CARD_PCI="0000:03:00.0"             # ajuste selon ton lspci (section 0.3)
DURATION=1800                       # secondes ; 1800=30min, monte à 3600 pour un test plus long
FPS=60
EXPECTED_FRAMES=$((DURATION * FPS))
LOGFILE="/tmp/a380-stresstest-$(date +%Y%m%d-%H%M%S).log"

echo "=== Test de stress A380 — démarrage $(date) — durée ${DURATION}s ==="
dmesg > /tmp/dmesg-before.txt

docker run --rm --device=/dev/dri:/dev/dri linuxserver/ffmpeg \
  -hwaccel vaapi -hwaccel_device "$RENDER_NODE" -hwaccel_output_format vaapi \
  -f lavfi -i testsrc=size=3840x2160:rate=${FPS} -t ${DURATION} \
  -vf 'format=nv12,hwupload' -c:v h264_vaapi -b:v 20M -f null - \
  > "$LOGFILE" 2>&1
EXIT_CODE=$?

dmesg > /tmp/dmesg-after.txt

PASS=1
REASON=""

if [ $EXIT_CODE -ne 0 ]; then
  PASS=0
  REASON="${REASON}FFmpeg a terminé en erreur (exit code $EXIT_CODE). "
fi

ENCODED_FRAMES=$(grep -oP 'frame=\s*\K[0-9]+' "$LOGFILE" | tail -1)
ENCODED_FRAMES=${ENCODED_FRAMES:-0}
if [ "$ENCODED_FRAMES" -lt $((EXPECTED_FRAMES * 95 / 100)) ]; then
  PASS=0
  REASON="${REASON}Seulement $ENCODED_FRAMES/$EXPECTED_FRAMES frames encodées (arrêt prématuré). "
fi

if grep -qiE "error|failed|invalid|corrupt" "$LOGFILE"; then
  PASS=0
  REASON="${REASON}Erreurs trouvées dans les logs ffmpeg ($LOGFILE). "
fi

KERNEL_ISSUES=$(diff /tmp/dmesg-before.txt /tmp/dmesg-after.txt | grep -i "$CARD_PCI" | grep -iE "hang|reset|error")
if [ -n "$KERNEL_ISSUES" ]; then
  PASS=0
  REASON="${REASON}Erreurs kernel détectées sur $CARD_PCI pendant le test. "
fi

echo ""
if [ "$PASS" = "1" ]; then
  echo "✅ CARTE BONNE — $ENCODED_FRAMES frames encodées sans erreur détectée."
else
  echo "❌ CARTE SUSPECTE — $REASON"
  echo "   Détails complets dans $LOGFILE"
  echo "   → Retourne la carte sur Amazon."
fi
EOF
chmod +x /root/test-a380.sh
/root/test-a380.sh
```

Le test tourne en avant-plan (compte 30 min par défaut) et affiche le verdict à la toute fin — ✅ ou ❌, rien d'autre à interpréter. Si la connexion SSH/terminal risque de couper avant la fin, lance-le dans une session `screen` ou `tmux` (disponibles via le plugin NerdPack si pas déjà là) pour pas perdre le test en cours de route.

**Nettoyage une fois fini :**
- Le container lui-même se supprime tout seul (`--rm` dans la commande) — rien à faire de ce côté.
- Pour libérer l'espace disque de l'image téléchargée (~500MB-1GB, inclut les drivers Intel) une fois que t'as fini de tester :
```bash
docker rmi linuxserver/ffmpeg
```
- Le script et ses logs restent dans `/root/test-a380.sh` et `/tmp/a380-stresstest-*.log` — supprime-les si tu veux (`rm /root/test-a380.sh /tmp/a380-stresstest-*.log /tmp/dmesg-*.txt`), ou garde le script si tu veux re-tester plus tard.

Garde le monitoring de 0.4 (dmesg -w + fréquence) actif en parallèle du test ffmpeg.

### 0.6 Test complémentaire — Ollama (remplit la VRAM près du max)

Le test ffmpeg (0.5) stresse surtout le media engine (encodeur vidéo), pas la pleine VRAM. Comme ton usage final est justement l'inférence LLM, rouler un modèle qui remplit presque les 6GB est à la fois le test le plus représentatif de ton usage réel et le plus susceptible de sortir une puce VRAM défectueuse (résultats incohérents/garbage plutôt qu'un crash net).

> **Image réutilisée :** Utilise la même image `spaceinvaderone/ollama-intel-gpu` que la section 1 (Ollama). Pas besoin d'installer une image supplémentaire — elle inclut déjà Ollama + drivers Intel GPU pour l'Arc A380.

**Dans le container Ollama (déjà installé en section 1), pull un modèle ~4-5GB et lance-le avec un gros contexte :**
```bash
# Pull un modèle de test (choisis un modèle de ~4-5GB en Q4 pour remplir la VRAM)
ollama pull qwen2.5:7b-instruct-q4_K_M
# ou un autre modèle de cette taille selon ce qui est disponible

# Lance avec un contexte qui pousse la VRAM proche du max
ollama run qwen2.5:7b-instruct-q4_K_M
# Dans le REPL Ollama :
/set parameter num_ctx 8192
```
Puis demande une génération longue :
```
Écris un texte long et détaillé sur l'histoire de l'intelligence artificielle. Au moins 2000 tokens.
```

Le but n'est pas la vitesse ici, c'est de voir si la génération reste **cohérente** du début à la fin sur un gros run. Génère plusieurs milliers de tokens et relis la sortie:
- **Sain :** texte cohérent, pas de caractères aléatoires/symboles bizarres qui apparaissent en rafale, pas de crash du process.
- **Suspect :** garbage/symboles incohérents en plein milieu du texte, répétitions bizarres qui ressemblent à de la corruption plutôt qu'à un comportement normal du modèle, ou le process qui plante/freeze en cours de génération.

**Note :** contrairement au script ffmpeg de 0.5, valider "la sortie a du sens" demande un coup d'œil humain — plus difficile à automatiser proprement qu'un simple pass/fail. Si tu veux un signal automatique en plus du coup d'œil, garde `dmesg -w` (0.4) ouvert en parallèle: un hang/reset pendant la génération est un signal aussi fiable qu'avec ffmpeg.

### ✅ Checkpoint
Aucune erreur PCIe (0.4), aucun hang/reset lié à `i915 0000:03:00.0`, fréquence stable sous charge pendant le test ffmpeg (0.5), et sortie cohérente sur le test llama.cpp (0.6) → carte validée, continue au reste du plan. Sinon → retour Amazon, reste sur iGPU seul en attendant un remplacement.

---


## Section 1 — Ollama avec accélération Arc (SpaceinvaderOne/ollama-intel-gpu)

### 1.1 Installer le container
Apps → cherche **"ollama-intel-gpu"** (SpaceinvaderOne) → Install.
- Port : `11434`
- Appdata : `/mnt/user/appdata/ollama`
- Device : `/dev/dri`

### 1.2 Variables d'environnement
```
OLLAMA_VULKAN=1
OLLAMA_KV_CACHE_TYPE=q8_0
OLLAMA_FLASH_ATTENTION=1
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_KEEP_ALIVE=30m
OLLAMA_HOST=0.0.0.0:11434
```

### 1.3 Pull le modèle
Console du container :
```bash
ollama pull qwen3.6:35b-a3b
```
(vérifie le tag exact sur ollama.com/library avant)

### 1.4 ⚠️ Contexte — architecture hybride, calcul théorique non fiable, procéder empiriquement

**Correction importante :** Qwen3.6-35B-A3B n'est **pas** une architecture attention standard (GQA) — c'est un hybride : 40 couches en blocs de 4, où 3 couches sur 4 sont du **Gated DeltaNet** (style SSM/Mamba, mémoire à **taille fixe**, ne grandit **pas** avec le contexte) et seulement 1 couche sur 4 est de l'attention traditionnelle (KV cache qui grandit avec le contexte). Un calcul basé sur une architecture GQA classique (comme fait plus tôt) **sous-estime probablement la quantité de contexte réellement jouable** — un rapport terrain rapporte 262K de contexte natif logé dans 21 GiB de KV total, nettement plus favorable qu'une architecture attention pure à cette taille.

**Verdict : impossible de calculer ça à l'avance de façon fiable pour ce modèle. Tester empiriquement, en descendant par paliers si ça OOM.**

**Cible : 128K (le max), avec paliers de repli si ça charge pas.**

```bash
ollama run qwen3.6:35b-a3b
/set parameter num_ctx 131072
/save qwen3.6:35b-a3b
```

**Si erreur OOM au chargement (llama.cpp échoue proprement, pas de crash silencieux) — descendre dans cet ordre :**

| Palier | num_ctx | Commande |
|---|---|---|
| 1 | 128K | `/set parameter num_ctx 131072` |
| 2 | 120K | `/set parameter num_ctx 122880` |
| 3 | 112K | `/set parameter num_ctx 114688` |
| 4 | 96K | `/set parameter num_ctx 98304` |
| 5 | 80K | `/set parameter num_ctx 81920` |
| 6 | 64K | `/set parameter num_ctx 65536` |

Dès qu'un palier charge et tourne sans erreur → `/save qwen3.6:35b-a3b` pour fixer ce contexte, arrêter là.

### 1.5 Offload MoE hybride (le vrai gain de vitesse)

**Status :** Le flag `--n-cpu-moe` existe dans llama.cpp (PR #15077) et **Ollama 0.30.0+ l'expose** via :
- **Env var (servant tous les modèles) :** `LLAMA_ARG_CPU_MOE=1` + `num_gpu=99` (force tout sur GPU sauf les experts MoE)
- **Par modèle (API/Modelfile) :** `{"options": {"num_cpu_moe": N}}` ou `PARAMETER num_cpu_moe N` dans un Modelfile

**⚠️ Attention :** Le PR #16688 (num_cpu_moe) a été supplanté par le PR #16958 qui corrige la cause racine (mauvais estimé KV cache pour les modèles SWA). Si tu utilises une version récente d'Ollama (0.31+), l'auto-placement devrait fonctionner correctement sans flag manuel.

**Approche recommandée :**
1. Essai **d'abord sans flag** — laisse l'heuristique auto-placement d'Ollama faire son travail (elle est corrigée dans les versions récentes)
2. Si le modèle OOM ou n'utilise pas toute la VRAM disponible, utilise :
   - `LLAMA_ARG_CPU_MOE=1` comme variable d'environnement du container Ollama (section 1)
   - Ou crée un Modelfile dédié :
     ```
     FROM qwen3.6:35b-a3b
     PARAMETER num_cpu_moe 24
     ```
3. Ajuste `num_cpu_moe` à la baisse tant que ça rentre en VRAM (6GB étant limité, attends-toi à devoir garder ce chiffre assez haut)

**Règle d'or :** Le but est de trouver le **plus petit N** où le modèle tient en VRAM sans overcommit. Au-delà, chaque couche supplémentaire sur CPU = perte de perf (les poids experts traversent le PCIe). Commence à 0, augmente jusqu'à ce que ça charge proprement, puis arrête.

### 1.6 Test de vitesse
```bash
ollama run qwen3.6:35b-a3b --verbose
```
Note le **eval rate** (tokens/s génération). Objectif réaliste avec 6GB : ~10-15 tok/s, net mieux que les 6.6 tok/s en CPU pur.

### ✅ Checkpoint
Modèle qui répond, `eval rate` amélioré vs le baseline CPU (6.6-6.76 tok/s) → continue.

---

## Section 2 — SearXNG (backend de recherche partagé)

### 2.1 Installer
Apps → **"SearXNG"** (Official Container) → Install.
Note l'URL : `http://IP-NAS:8080` (ou le port choisi)

C'est le point central que **MCP-Searxng** et **LocalDeepResearch** vont tous les deux réutiliser — un seul SearXNG pour tout le stack.

---

## Section 3 - LocalDeepResearch

### 3.1 Installer
Apps -> **"LocalDeepResearch"** (Official Container) -> Install.

### 3.2 Configurer
- Pointe vers le SearXNG de la section 2 (même instance, pas de doublon)
- Pointe vers ton Ollama (section 1) pour le LLM
- Ouvre le web UI, configure le modèle (`qwen3.6:35b-a3b` ou un modèle plus léger si tu veux des recherches plus rapides)

---

## Section 4 - mem0-aio (mémoire persistante des agents)

### 5.1 Installer
Apps → **"mem0-aio"** (JSONbored) → Install.
⚠️ **Port par défaut 3000 — va entrer en conflit avec Open WebUI (section 6). Change-le à 3001 ici.**

> **⚠️ Si mem0-aio n'est pas dans Community Apps** : installe manuellement via Docker > Add Container avec l'image `ghcr.io/mem0ai/mem0:latest` (ou l'image spécifique JSONbored si disponible). Vérifie la documentation mem0 pour l'image Docker officielle.

### 4.2 Configurer

**Pré-requis :** Pull un modèle d'embedding sur Ollama AVANT de configurer mem0 :
```bash
ollama pull nomic-embed-text
```
(`nomic-embed-text` — 274MB, 768 dimensions, le modèle recommandé par défaut par mem0 pour Ollama. Alternatives : `mxbai-embed-large` plus gros mais plus précis.)

Variables d'environnement pour mem0-aio :
```
OLLAMA_BASE_URL=http://IP-NAS:11434
LLM_PROVIDER=ollama
LLM_MODEL=qwen3.6:35b-a3b
EMBEDDER_PROVIDER=ollama
EMBEDDER_MODEL=nomic-embed-text
```
Laisse `OPENAI_API_KEY` vide — tu restes 100% local via Ollama.

### 4.3 Accès
`http://IP-NAS:3001`

---

## Section 5 - Open WebUI (interface de chat/test)

### 5.1 Pré-requis sur le container Ollama
Retourne dans le container Ollama (section 1) et ajoute :
```
OLLAMA_ORIGINS=*
```
Sinon Open WebUI ne pourra pas s'y connecter.

### 5.2 Installer
Apps → **"open-webui"** → Install.
- Port hôte : `3000`
- Container path `/app/backend/data` → persiste vers `/mnt/user/appdata/open-webui`
- Fixe un `WEBUI_SECRET_KEY` stable (évite de perdre les sessions à chaque recreate)

### 5.3 Configurer
- Admin Settings → Connections → vérifie l'endpoint Ollama
- Admin Settings → Web Search → active SearXNG, pointe vers l'URL de la section 2

### 5.4 Accès
`http://IP-NAS:3000`

---

## Section 6 - Plugin de monitoring Ollama/llama.cpp

### 6.1 Installer
Settings → Plugins (ou Apps si listé comme container) → cherche un plugin de monitoring LLM local (Ollama/llama.cpp) pour le dashboard Unraid.
> Le nom exact n'était pas confirmé au moment d'écrire ce plan — cherche "ollama" ou "llm" directement dans Apps/Plugins sur ton serveur pour trouver la fiche à jour.

### 6.2 Bénéfice
Remplace le besoin de faire `docker logs` / `xpu-smi diag` manuellement à chaque fois — état visible direct sur le dashboard Unraid.

---

## Architecture finale

```
┌---------------┐
| Ollama (A380) |
| Qwen3.6-35B   |
| (orchestrator)|
└-------┬-------┘
        |
        ├------------------┐
        v                  v
┌---------------┐  ┌--------------┐
|  Open WebUI   |  |   SearXNG    |
|  (chat/test)  |  └------┬------┘
└---------------┘         |
        |                 |
        v                 v
┌---------------┐  ┌--------------┐
|   mem0-aio    |  |LocalDeep-    |
|  (mémoire)    |  |Research      |
└---------------┘  └--------------┘
```

---

## Ordre d'exécution recommandé
1. **Section 0B** (BIOS) - Configure le BIOS AVANT tout. **Priorité absolue.**
2. **Section 0A** (validation A380) - Teste la carte usagée dans la fenêtre de retour Amazon.
3. Section 1 (Ollama + modèle)
4. Section 2 (SearXNG)
5. Section 3 (LocalDeepResearch)
6. Section 4 -> 5 (mem0-aio -> Open WebUI, attention au conflit de port)
7. Section 6 (monitoring)

## Notes de vigilance générales
- **BIOS d'abord** — Ne lance aucun stress test tant que le BIOS n'est pas configuré. ReBAR, C-States, ASPM sont critiques pour la stabilité du HBA et des performances de la A380.
- Contexte 128K = perte de l'accélération GPU sur le KV cache avec seulement 6GB VRAM. Reste à 64K si la vitesse prime.
- Conflit de port 3000 entre mem0-aio et Open WebUI — changé pour mem0-aio à 3001 dans ce plan.
- **Image ffmpeg** : `linuxserver/ffmpeg`. Maintenue, drivers Intel à jour pour Arc. **⚠️ Pas dans CA — installation manuelle Docker.**
- **SpaceinvaderOne ollama-intel-gpu** : image minimaliste Ollama + drivers Intel GPU. **Ne contient PAS ffmpeg** (pas pour les tests VAAPI). Par contre, c'est l'image Ollama optimisée pour Intel Arc — elle sert pour **la section 1 (inférence) ET la section 0.6 (stress test VRAM)**. Une seule image pour tout.
- **Ollama MoE** : `--n-cpu-moe` existe et fonctionne (Ollama 0.30.0+), mais les versions récentes gèrent l'auto-placement. Essai sans flag d'abord.
- **mem0-aio** : Nécessite `nomic-embed-text` (ou équivalent) pull sur Ollama. Prévois ~274MB de stockage. **⚠️ Vérifier disponibilité CA — sinon installation manuelle.**
- Si le stress test A380 (section 0.4) échoue, retourne la carte avant de continuer les sections suivantes — tout le reste du plan dépend d'un GPU fonctionnel.

### Disponibilité Community Apps (CA)

| Application | Source | Dans CA ? | Installation |
|---|---|---|---|
| ollama-intel-gpu | SpaceinvaderOne | ✅ Oui | Apps → chercher "ollama-intel-gpu" |
| SearXNG | Kilrah | ✅ Oui | Apps → chercher "SearXNG" |
| MCP-Searxng | Cyberschorsch | ✅ Oui | Apps → chercher "MCP-Searxng" |
| LocalDeepResearch | Selfhosters | ✅ Oui | Apps → chercher "LocalDeepResearch" |
| open-webui | joly0 | ✅ Oui | Apps → chercher "open-webui" |
| linuxserver/ffmpeg | LinuxServer | ❌ Non | Installation manuelle Docker |
| mem0-aio | JSONbored | ❌ Non | Installation manuelle Docker |
