# Plan — KinRin
## 1. What we build

niri + DMS as the main session, Plasma as manual fallback. Wayland. KinRin, AMD and Intel.

```
greetd ──▶ dms-greeter
   │
   ├──▶ niri ──▶ DMS : bar, notifications, launcher, controller, polkit, lock screen
   │         └──▶ apps KDE (Dolphin, Konsole, Kate, Discover)
   │
   └──▶ Plasma ──▶ kwin + plasmashell          (manual fallback)
```

- niri is Wayland-only. X11 apps go through `xwayland-satellite`, declared in §4.0 redundantly as insurance: `niri` already requires it, which §4.0 verifies.
- The Plasma fallback is manual: `Ctrl+Alt+F3` then `startplasma-wayland`. Nothing switches by itself. If the greeter lists both sessions (criterion 13), that is the only other path.
- Games go through `steam` as an RPM; Proton comes from Steam itself. `gamescope` is not shipped by default, and §4.9 decides on request.

---
## 2. Rules

1. Repository order: official Fedora, then COPR, then RPM Fusion. `dms` sits on rung 2, `steam` and `discord` on rung 3 (§4.0). 2. Latest stable, never pinned. Base on `:latest`, packages from the repo, no dev builds. An RC counts as a dev build. 3. RPM only. No Flatpak app installed, no remote enabled. The `flatpak` package is the single exception, and §3.1 states it and why. 4. bootc stays: it is how the image is authored. rpm-ostree is the deployment system. 5. No layering. A layered package vanishes on `bootc switch` without a message, and `bootc upgrade` refuses a modified deployment. Rebuild the image instead (§6.1).

The base follows `:latest`, so §8 is the only guard against upstream drift. Do not pin to silence a failure.

---
## 3. The model

`FROM quay.io/fedora/fedora-kinoite:latest`, then the modules of §4.

- The base **ships a display manager, enabled**: `/etc/systemd/system/display-manager.service -> /usr/lib/systemd/system/plasmalogin.service`, verified by execution in `quay.io/fedora/fedora-kinoite:latest`. So the recipe must **repoint that alias at greetd** — two DMs both claiming `graphical.target` is a boot that never settles, and enabling greetd alone is not a fix. The module's `systemctl -f enable greetd` does exactly that repoint: it removes the `display-manager.service` link to `plasmalogin.service` and recreates it to `greetd.service`, because `greetd.service` carries `[Install] Alias=display-manager.service` and no `WantedBy=` — the alias link is its only activation. **So the recipe must NOT also list `display-manager.service` under `disabled:`**: the module runs its `enabled:` loop first and its `disabled:` loop second, so that entry would delete the symlink just created, leaving greetd `disabled` and `graphical.target` (`Wants=display-manager.service`, the only DM boot path) pointing at a name that resolves to nothing. Disabling `plasmalogin.service` is harmless and still worth declaring. The package `plasma-login-manager` ships `plasmalogin.service`, the unit the `display-manager.service` symlink points at — it is not an sddm alias — so the Plasma binaries exist either way, which is what the §1 fallback needs. `dms-greeter`'s `%post` additionally calls `systemctl set-default graphical.target`, so the order of those two steps matters; criterion 11 is the check that settles which one won.
- `/etc/os-release` carries `ID=fedora` in the base. Change it to `ID=kinrin` **and set `ID_LIKE: fedora` in the same write** — the two are one change, because an `ID` with no `ID_LIKE` declares no parent, and every third-party repo that branches on the parent ID loses that branch. Both keys go in the one `properties:` map, and the module runs **last of the eight** (§5), so the `dnf` transaction and the `dms setup` of §4.5 still read `ID=fedora` and never see `kinrin`. Nothing keys off the new `ID` where the answer would differ: `isVoidSetup()` is unchanged — only `"void"` registers `FamilyVoid` (§4.8) — and the `niri config`, the `DMS theme` and the `skel theme` of §4.5 and §4.12 are seeded by path, not by ID, so the same logic holds in both worlds.
### 3.1 RPM or Flatpak

Everything is RPM. The `flatpak` package is **verified present in the base**, its binary at `/usr/bin/flatpak` (`/usr/sbin/flatpak` is only the usrmerge symlink) — so §4.0 does not list it and §5.2's `flatpak.yaml` depends on that fact. Declare it in §4.0 anyway if you prefer not to depend on the base; the transaction is free when the package is already there. Keep the package: the installed Flatpak backend, `plasma-discover-flatpak`, `Requires: flatpak` — `plasma-discover` itself does not.

`portals.conf` still matters (§4.2): Spectacle capture, the file picker and Discord screen share go through `xdg-desktop-portal`, and the KDE backend is not selected under niri without it. Criterion 3.
### 3.2 Flatpak: package present, no remote enabled

The `flatpak` package's `%post` enables `flatpak-add-fedora-repos.service`, whose `ExecStart` lines add the `fedora` and `fedora-testing` remotes. The base also ships `/usr/lib/fedora-third-party/conf.d/fedora-flathub.flatpakrepo` — an offer shown by Discover, not an activation. `%post` only *enables* the unit, and a unit enabled during a container build does not run, so confirm rather than assume: `rpm -ql flatpak | grep -E 'systemd|flatpakrepo'` and read the unit's `ConditionPathExists` before relying on the marker alone.

The empty marker `/var/lib/flatpak/.fedora-initialized` is guarded by `ConditionPathExists=!/var/lib/flatpak/.fedora-initialized`, so it blocks any *future* add only. Delete what the transaction may have left behind as well, before the marker — and **both** deletes, or `flatpak remotes --system` is not empty:

```bash
install -d /var/lib/flatpak
# `flatpak` is captured before it is grepped, and that is load-bearing. A pipeline reports the status of its LAST command, so `flatpak remotes … | grep -qx fedora` returns grep's status: a `flatpak` that fails outright — broken binary, no D-Bus, `/var` wiped — matches nothing, the deletes are skipped, and the run still reaches the `.fedora-initialized` marker and exits 0. That is fail-open, the opposite of the `test -n` guard §4.11 uses for orca. Verified: under `set -eu`, `if false | grep -qx fedora; then :; fi; touch marker` exits 0 and creates the marker.
remotes=$(flatpak remotes --system --columns=name)
if printf '%s\n' "$remotes" | grep -qx fedora;        then flatpak remote-delete --system fedora;        fi
if printf '%s\n' "$remotes" | grep -qx fedora-testing; then flatpak remote-delete --system fedora-testing; fi
touch /var/lib/flatpak/.fedora-initialized
ln -sf /dev/null /etc/systemd/system/flatpak-add-fedora-repos.service
```

`install -d` first: `/var/lib/flatpak` does not exist in the base, so a bare `touch` of the marker fails. **But do not bet the criterion on it**: BlueBuild's `post_build.sh` is reported to `rm -rf /tmp/* /var/* /opt` after the modules run, which would delete the marker *and* make the two `remote-delete` guards moot, because whatever `%post` left in `/var/lib/flatpak` never reaches the image either (**asserted, source not pinned here** — confirm against the BlueBuild tree before relying on it). The `ln -sf` mask is the part that certainly survives, because `/etc` is versioned with the deployment, so §8's 2c is written against the mask and the empty remote list, not against the marker.

Enforce the invariant with the mask symlink, not only with the marker: the marker lives in `/var`, and bootc treats `/var` in the image like a Docker `VOLUME` — unpacked only from the *initial* image. On the `bootc switch` path §6 recommends over an existing Atomic host, `/var/lib/flatpak` already exists, is not re-initialised, the image's marker never arrives, and a pre-existing `fedora` remote survives. `systemctl mask` writes `/etc/systemd/system/<unit> → /dev/null` — verified in the base image, not `/usr/lib/systemd/system` — so the `ln -sf` above writes exactly that path by hand, and it is versioned with the deployment and three-way merged, so it is as durable as anything under `/usr`. If you want it under `/usr/lib`, ship the symlink from `files.yaml` instead.

There is no `postprocess` key in any BlueBuild module. The commands above belong to `recipes/modules/flatpak.yaml`'s `snippets:`, in that order — the marker before a delete would leave the remotes in place behind a "done" file.

User opt-in, on demand:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

Criterion 32.
### 3.3 Secure Boot — nothing to write

No kernel change, no bootloader change, no module signing. No NVIDIA in this image: no `akmods-nvidia`, no `mokutil`. AMD and Intel use in-kernel drivers only. Criterion 18 tests the base, not this image.

---
## 4. What has to be written

Use official BlueBuild modules. No hand-written shell beyond the four `type: script@v2` modules of §5.2. Of those four, two are multi-command shell steps: `flatpak.yaml`'s six ordered commands of §3.2, and the `RUN` of §4.5.

| Need | Module |
|---|---|
| COPR + packages | `type: dnf` |
| niri config (`config.kdl`, `dms/binds.kdl`) — written by `niri-config.yaml` | `type: script@v2` (see below) |
| the §4.7–§4.8 files: the four drop-ins there (`kinrin-dms`, `kinrin-xdg`, `kinrin-theme` ×2) plus §4.4's `kinrin-vrr.conf`, and §4.0's `/etc/systemd/logind.conf.d/kinrin.conf`; the `niri-vrr.service` unit (§4.4); also `portals.conf`, `/etc/environment.d/90-dms.conf` (two unrelated keys, §4.7), the greetd config, skel `local.kdl`, skel `DankMaterialShell/settings.json` (§4.12), `cli-policy.json` (§4.14) | `type: files` |
| greetd enabled at boot | `type: systemd` (`system:`) |
| Distro name and ID | `type: os-release` |

The `signing` module is referenced from the recipe (§5), not from a build step, and it is not a signing step: what it contributes to the image is a **verification policy**, and the private key never enters the image at all. Read that out of the built image rather than asserting it (§6.1).
### 4.0 Packages and repos

```yaml
- type: dnf
  repos:
    nonfree: rpmfusion
    copr:
      enable:
        - avengemedia/dms
  install:
    packages:
      - niri
      - dms
      - quickshell
      - gdb
      - dms-greeter
      - greetd
      - dolphin
      - konsole
      - kate
      - plasma-discover
      - plasma-workspace
      - plasma-workspace-common
      - kwin
      - libva-intel-media-driver
      - libva-utils
      - steam
      - steam-devices
      - discord
      - xwayland-satellite
      - jq
      - acl
      - curl
      - git
      - nodejs
      - python3
      - podman
      - gcc
      - make
      - cmake
      - rust
      - cargo
      - ripgrep
      - fish
      - zsh
      - npm
      - python3-pip
      - golang
      - git-lfs
      - rustfmt
      - rust-analyzer
      - golangci-lint
```

- The package is **`plasma-discover`**. There is no `discover` in Fedora, and the `dnf` module fails outright on a name it cannot resolve, so a literal `discover` breaks the first build.
- The base is **Kinoite, which is KDE** — verified in `quay.io/fedora/fedora-kinoite:latest`: `dolphin`, `konsole`, `plasma-workspace`, `plasma-workspace-common`, `kwin`, `spectacle`, `xdg-desktop-portal-kde`, `xdg-desktop-portal-gtk` and `plasma-discover` are all already installed. Declare them anyway, but the only genuine addition among the KDE apps is **`kate`**, and §1's diagram describes a base that mostly exists already.
- **Seventeen** of the §4.11 table's 21 packages — that table, not this `install:` list — are absent from the base, and all seventeen are declared here; the base ships the other four, each confirmed by `rpm -q` in the base image: `gdb`, `jq`, `python3`, `podman`. The seventeen are the declaration list: `nodejs`, `npm`, `git`, `git-lfs`, `rust`, `cargo`, `rustfmt`, `rust-analyzer`, `golangci-lint`, `golang`, `python3-pip`, `gcc`, `make`, `cmake`, `ripgrep`, `fish`, `zsh`. `golangci-lint` comes from **`fedora`**, not from `nonfree`, so the stanza that carries `steam` and `discord` is not involved in it.
- Ship the drop-in from the `files` module, so the decision is made in the image and not left to whoever tests it — and ship it **with its section header**, because a setting written before any header is discarded by systemd:

```ini
# /etc/systemd/logind.conf.d/kinrin.conf
[Login]
HandleLidSwitch=suspend
```

Without `[Login]`, `logind` ignores the file, lid-close keeps its default action, and a grep for the value still passes. Never edit `/etc/systemd/logind.conf` itself — §7 forbids editing a shipped file, and criterion 8b checks the drop-in, not the main config. PowerDevil's own setting must not override it; criterion 8b records which of the two actually wins.
- Verify the fallback landed rather than trusting the transaction: `ls /usr/share/wayland-sessions/` must list both `niri.desktop` and `plasma.desktop`, and `test -x /usr/bin/startplasma-wayland` must pass. `/usr/bin` is the path, not `/usr/sbin`: `plasma-workspace` installs the script in `%{_kf6_bindir}`, and the Fedora 44 primary metadata lists `/usr/bin/startplasma-wayland` in that package. Criterion 6.
- Write `repos:` as a mapping, never as a list of records: `nonfree:` and `copr` are two keys of the same level. A `- copr:` entry breaks the build.
- `dms` and `dms-cli` come from the main COPR (`dms-cli` is a hard `Requires:`, so it is always there); `dms-greeter` from the second stanza the COPR ships, `[coprdep:copr.fedorainfracloud.org:avengemedia:danklinux]` (whose own header reads `name=Copr copr.fedorainfracloud.org/avengemedia/dms runtime dependency #1 - avengemedia/danklinux`). `danksearch` is from either that stanza or Fedora — both are consistent with what was measured, and the repo that won the transaction was not recorded, so its origin is unverified. `danksearch` and `matugen` are both a `Recommends:` of the `dms` spec (`distro/fedora/dms.spec:27,28`), and weak deps are **on by default** in the `dnf` module, so nothing needs setting. If you ever set it, the key is `install-weak-deps` — hyphens, inside `install:` — not `install_weak_deps`, which is not in the schema and fails `bluebuild validate`. With weak deps off, `danksearch` is silently dropped and the greeter loses its search, and `matugen` is silently dropped and every theme of §4.12 dies.
- `quickshell` is declared explicitly in `install:` — the RPM accepts `quickshell-git` as an alternative (`Requires: (quickshell or quickshell-git)`), which would break rule 2; `dgop` arrives as a plain dependency of `dms`.
- The `nonfree: rpmfusion` key enables `rpmfusion-free-release` **and** `rpmfusion-nonfree-release`, GPG keys included. `steam` and `discord` come from `nonfree` — not Fedora, not `free`. `steam`'s 32-bit dependencies (`SDL3(x86-32)`, `mesa-dri-drivers(x86-32)`, `vulkan-loader(x86-32)`, `pipewire-libs(x86-32)`) are all Fedora packages — `SDL3(x86-32)`, not SDL2: `steam` requires SDL3, and Fedora 44 ships no `SDL2` package at all, only the separate `sdl2-compat`.
- `libva-intel-media-driver` is the only Intel media driver **in Fedora**. The name `intel-media-driver` does not exist there, but **it does resolve once `nonfree: rpmfusion` is enabled**, because rpmfusion-nonfree ships `intel-media-driver`, whose `Provides:` include `libva-intel-media-driver` — so install the exact name above and do not let the shorter one stand in for it.
- `libva-utils` and `acl` are listed for the criteria, not for the desktop: `vainfo` comes from the first and `getfacl` from the second, and criteria 14, 15 and 22 are written against them. Neither has a runtime dependency on the session — drop both and those three criteria need rewriting, not re-running.
- Declare `steam-devices` explicitly. It ships the udev rules for input and VR; without it no gamepad is recognised and criterion 22 fails.
- Declare `xwayland-satellite` explicitly. The `steam` RPM itself is 64-bit — its *dependencies* are the 32-bit part. Note that `niri-26.04` **already `Requires: xwayland-satellite >= 0.7`** — verified — so the declaration is redundant, not needed; keep it anyway, because an explicit dependency survives a future niri relaxing it. Criterion 27.
- `discord-canary` and `discord-ptb` do not exist as RPMs. No conflict with `steam`, no 32-bit dependency, no `--allowerasing` needed.
- If the first build fails on repo fetch, the COPR has moved to Pulp: `…/avengemedia/dms/repo_fedora44.xml` and `/api/coprs/…` return 404. Pin the version-parameterised form `/coprs/<owner>/<proj>/repo/fedora-<N>/<owner>-<proj>-fedora-<N>.repo`, with `<N>` read from the base image. Do not hard-code `44`: the base is `:latest`, so a frozen version breaks the build the day Fedora moves on, and that would be pinning in all but name.
### 4.1 The `greeter` account is created by the RPM, not by us

`dms-greeter` ships `/usr/lib/sysusers.d/dms-greeter.conf` (`dms-greeter.spec:77,97`):

```
u greeter - "System Greeter" /var/lib/greeter /bin/bash
```

Do **not** redeclare that line. The package also creates the group and the user in `%pre` — `groupadd -r greeter` and `useradd -r -g greeter -d /var/lib/greeter` (`dms-greeter.spec:102-108`) — so shipping our own copy means two sources of truth for one system user. The `greeter` account is a **system** user (`-r`), created by the RPM's `%pre` (`getent passwd greeter || useradd -r -g greeter …`, `dms-greeter.spec:104-107`) alongside the sysusers file — so the plan has no image-side user-creation step, not because no entry exists.

DRM access is not a group, but the two node types come from **different** rules: `SUBSYSTEM=="drm", KERNEL=="card*", TAG+="uaccess"` (`/usr/lib/udev/rules.d/70-uaccess.rules:46`) grants `/dev/dri/card*` to the active seat session, greeter included, while `/dev/dri/renderD*` is covered separately and world-accessibly by `SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0666"` (`/usr/lib/udev/rules.d/50-udev-default.rules:61`). So add no group — and do not assume one rule covers both. `input` would also allow reading `/dev/input/event*`, which the login screen never needs. If criterion 16 shows a black screen, read `journalctl -u greetd`. Do not add rights.

greetd needs one config file, `/etc/greetd/config.toml`, owned by the `files` module. Without it greetd has no session to start and nothing renders:

```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/dms-greeter --command niri"
```

- `user = "greeter"` is not decorative. greetd defaults to `greeter`, and the line makes that explicit; the RPM's `%post` also reads it back out of the config to `chown` the greeter cache, which is its second reason to exist. The `%post` writes a config that contains this line, and it touches `/etc/greetd/config.toml` on **two** branches: `:198` creates it when the file is absent, and `:211` updates one that does **not** already mention `dms-greeter` — after copying it to a timestamped backup at `:212-213`. Since this `files` module writes the file, ours is authoritative and the RPM's version is skipped — the two are never merged, so a partial file silently loses the `user` line. The block above is the spec's own template (`dms-greeter.spec:200-208`) with `COMPOSITOR_PLACEHOLDER` resolved to `niri` (`:206` is the placeholder, the `sed` that resolves it at `:208`).
- This is greetd 0.10 syntax, which is what Fedora 44 ships (greetd ≥ 0.10). `command` takes a **command line**, not a path — greetd does not look in `/usr/share/wayland-sessions/` at all, so "list the directory and copy the name" is meaningless here. Criterion 11 is the check that matters.
### 4.2 `portals.conf` — the only non-obvious file

```ini
# /etc/xdg/xdg-desktop-portal/portals.conf
[preferred]
default=kde
org.freedesktop.impl.portal.Notification=plasmanotify
org.freedesktop.impl.portal.Secret=kwallet
```

**Nothing else needs routing, and that is worth stating rather than leaving assumed.** The ten fallback interfaces fall away under `default=kde` or the explicit `Notification` line above. `Secret` is the one interface that is **not** reached without a key of its own, and it is worth tracing because the failure is silent. Only `kwallet.portal` declares it (`Interfaces=org.freedesktop.impl.portal.Secret;`); neither `kde.portal` nor `gtk.portal` does, so `default=kde` resolves to a candidate that is skipped by name. The `UseIn` fallback does not rescue it either: `kwallet.portal` carries `UseIn=kde`, which does not match `XDG_CURRENT_DESKTOP=niri`. The stock `/usr/share/xdg-desktop-portal/kde-portals.conf` *does* route it (`:4`, `org.freedesktop.impl.portal.Secret=kwallet`), but that file is never consulted: lookup is desktop-scoped, trying `{desktop}-portals.conf` then a generic `portals.conf` per directory, and `/usr/share` holds neither — only `kde-portals.conf`, whose name never matches under `niri`. So the stock file is not consulted at all, `default=` or no `default=`, and every interface has to be answered by ours. Hence the third key above, naming the same backend the stock file names. It is not a Plasma regression: this file is desktop-agnostic and is read there too, where naming `kwallet` changes nothing. Equally, do not add `Settings=kde;gtk`: `kde.portal` implements `Settings`, so the gtk half of that fallback is unreachable while kde is installed. Note the case disagreement between backends — `UseIn=KDE` in `kde.portal` against `UseIn=kde` in `kwallet.portal` and `plasmanotify.portal` — which is exactly why an explicit `portals.conf` is required rather than optional.

Those are **separate keys, not one joined value.** Each key in a `[preferred]` group takes a **semi-colon-separated** list of backend implementations, so `default=kde` is simply the one-element case — a `:` there is the `XDG_CURRENT_DESKTOP` separator and matches no backend at all. Measured on `xdg-desktop-portal-1.22.1` under `XDG_CURRENT_DESKTOP=niri`, the chooser's `Choosing …` fallbacks to `gtk.portal` are 10 with the file absent and **0** with the block above.

So the file is **not** optional. `kde.portal` declares `UseIn=KDE` and `gtk.portal` declares `UseIn=gnome`, neither of which matches `niri`; without the preference the chooser falls through to gtk for every interface, and the criterion 3 check (`desktop.kde` in the bus) fails. `kde.portal` does not implement `Notification`, which is what the second key is for — `plasmanotify` is a separate `.portal`. Keep `xdg-desktop-portal-gtk`: `xdg-desktop-portal-kde` has a hard `Requires:` on it, so it is present either way and the fallback is only reachable when this file is wrong. Criterion 3.
### 4.3 Polkit — one agent, and the identity behind `auth_admin`

Under niri the DMS agent runs, under Plasma the KDE one. Each session has its own, so there is nothing to write. **But the agent is not the whole of it: `auth_admin` is an *identity* check, and polkit's default rule for it is literally `return ["unix-group:wheel"]`** (`/usr/share/polkit-1/rules.d/50-default.rules:11`), so admin authorisation *is* wheel membership, or root. This plan writes no polkit rule, and it used to mention `wheel` nowhere else — a gap rather than a decision. The base ships `plasmalogin` enabled and §3 disables it, so no first-boot path grants the session account wheel as Fedora's own would; **§10's first-user row now carries the requirement**, so the wheel half is settled and only the choice of creation path stays open. Criterion 4 asks for prompts the user can satisfy and the USB and NetworkManager actions are `auth_admin` here, so a session user outside wheel cannot answer them. The fix belongs with the first-user decision in **§10**: land the account in `wheel`. `greeter` is unrelated — the cache access §12b needs, added by `dms-greeter sync` itself.
### 4.4 Where niri rules go

Do not write in `/etc/niri/` beyond the fallback copy of §4.5. niri reads `/etc/niri/config.kdl` only as a fallback: as soon as `~/.config/niri/config.kdl` exists all of `/etc/niri/` stops being read, and there is no system+user merge. The skel seeds the user copy, so `/etc/niri/` is the path for a home where skel did not apply, not the normal one.

**Two writers, two rules.** DMS's deployer skips any `~/.config/niri/dms/*.kdl` that already exists and is non-empty, so `dms setup` preserves what it finds. The running shell does not preserve: it rewrites `layout.kdl`, `alttab.kdl`, `cursor.kdl` and `input.kdl` on a theme change — unconditionally for all but `alttab.kdl`, whose write is content-deduped (`NiriService.qml:1298-1299`), so unchanged content is not rewritten, and `outputs.kdl` on every output or refresh-rate change. Surviving the deployer and surviving the shell are different properties, and only the first was checked.

`binds.kdl` is the only file the template includes that the shell never rewrites. So anchor one level up — the include in `binds.kdl`, the rules in a `local.kdl` of your own.

**Add to the generated file, never replace it.** The command is a **prepend** and lives only in §4.5. `binds.kdl` already carries DMS's default keybinds — `Mod+Space`, `Mod+N`, `Mod+Alt+L` — and because the deployer skips any non-empty file, seeding a `binds.kdl` holding *only* the include would permanently suppress every default bind, and criterion 2b plus the launcher in criterion 2 would fail. The command is stated in §4.5 and nowhere else; repeating it here is how the two sections would drift apart.

Then seed that complete file, defaults and all, plus the rules:

This is the whole of the authored file, and it is the only place either rule is written down:

```kdl
# /etc/skel/.config/niri/local.kdl
// VRR for Steam games — the per-window half of §4.9
window-rule {
    match app-id=r#"^steam_app_.*$"#
    variable-refresh-rate true
}

// Steam's floating notification toasts go to the bottom right
window-rule {
    match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
    default-floating-position x=10 y=10 relative-to="bottom-right"
}
```

Keep `optional=true`, per §4.6. A bare `include` here stops niri booting for any home where `local.kdl` is absent, which is the exact failure §4.6 exists to prevent. The price of `optional=true` is that deleting `local.kdl` drops the rules silently rather than loudly — the right way round. Criterion 23.

Never write in `outputs.kdl` (`dms/outputs.kdl`): quickshell rewrites it wholesale on every output change, so a rule there is destroyed silently.

DMS includes these, all `optional=true`:

```
include optional=true "dms/colors.kdl"
include optional=true "dms/layout.kdl"
include optional=true "dms/alttab.kdl"
include optional=true "dms/binds.kdl"
include optional=true "dms/outputs.kdl"
include optional=true "dms/cursor.kdl"
include optional=true "dms/input.kdl"
```

VRR goes over IPC, not in a file, so it survives `dms setup` by construction. It needs a `systemd` **user** unit, and it has to wait for niri's socket: at login that socket does not exist yet, so a one-shot `ExecStart` calling `niri msg` immediately is a coin flip that usually loses.

```ini
# /usr/lib/systemd/user/niri-vrr.service
[Unit]
Description=Enable on-demand VRR on every output
After=niri.service
PartOf=niri.service

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=infinity
ExecStart=/bin/sh -c 'until [ -n "$$(niri msg -j outputs | jq -r "keys[]")" ]; do sleep 1; done; for o in $$(niri msg -j outputs | jq -r "keys[]"); do niri msg output "$$o" vrr on --on-demand; done'
```

**No `[Install]` section, and nothing enables it.** `WantedBy=default.target` would start the unit in *every* session, Plasma included, where `niri msg` has no socket and the wait loop never returns. Activation is a `Wants=` from `niri.service` instead, so the unit starts with niri and only with niri:

```ini
# /usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf
[Unit]
Wants=niri-vrr.service
```

This is the fifth drop-in, and it is scoped exactly like `kinrin-dms.conf` of §4.8: it starts with niri and does nothing when niri stops. `systemd-user.yaml` is therefore gone from the recipe (§5.2) — it existed only to create that enable symlink.

Both files are content, so both belong to `files.yaml` (§5.2). Never enable the unit by hand, as a user or a system unit: a `systemctl --user enable niri-vrr.service` puts back a `default.target` symlink and the Plasma run it caused. The loop walks the real output names, so a two-monitor machine is covered and nothing is hardcoded; `jq` is required and is installed in §4.0. ``$$` is systemd's escape for a literal `$` (`$o` would be expanded to the empty string before `/bin/sh` runs), and it is
  used for **both** the `$o` variable and the two `$$(…)` command substitutions: `$$` always yields one literal `$`, whereas
  relying on systemd leaving an unrecognised `$(` untouched depends on a parsing detail rather than on the documented rule, which would make every call `niri msg output ""` and fail the oneshot; `TimeoutStartSec=infinity` exempts the socket-wait loop from the 90 s start timeout. The value is the only
  documented disable — `0` is **not** one: it is a zero-second budget, and this unit is `Type=oneshot`, whose
  start timeout systemd already disables by default, so writing `0` would override that default and kill the
  unit on its first `sleep 1`. Verified by running it: an identical `Type=oneshot` unit with
  `TimeoutStartSec=0` fails in 2 ms with `status=15/TERM`, while the same unit with no explicit timeout, or with
  `TimeoutStartSec=infinity`, exits 0. `infinity` is spelled out rather than relying on the oneshot default so the
  setting survives a future change of `Type=`. The call itself, with `<NAME>` a placeholder for one entry of `niri msg outputs` and never a literal:

```bash
niri msg output <NAME> vrr on --on-demand
```

The per-window `variable-refresh-rate true` rule is a real window rule, so it goes in `/etc/skel/.config/niri/local.kdl` with the Steam ones. Criterion 31.
### 4.5 `dms` refuses root, and a container build is root

```
FATAL  go: This program should not be run as root. Exiting.
```

Exit code 1 on every subcommand (`setup`, `version`, `ipc`): the build fails. Run it as a non-root user, inside a **single** `RUN`. There is no second build stage to copy from (§5), so the staged files move with `install` in the same layer:

```dockerfile
RUN dnf install -y util-linux shadow-utils \
 && useradd -m -u 2000 builder \
 && install -d -o builder -g builder /staging \
 && su - builder -c 'HOME=/staging dms setup headless --compositor niri' \
 && rpm -ql niri | grep -q '/systemd/user/niri.service' \
 && rpm -ql dms | grep -q 'dms.service' \
 && sed -i '1i include optional=true "../local.kdl"' /staging/.config/niri/dms/binds.kdl \
 && sed -i 's/spawn "ghostty"/spawn "konsole"/' /staging/.config/niri/dms/binds.kdl \
 && install -d /etc/niri/dms /etc/skel/.config/niri/dms \
 && install -m644 /staging/.config/niri/config.kdl /etc/niri/config.kdl \
 && install -m644 /staging/.config/niri/config.kdl /etc/skel/.config/niri/config.kdl \
 && install -m644 /staging/.config/niri/dms/binds.kdl /etc/niri/dms/binds.kdl \
 && install -m644 /staging/.config/niri/dms/binds.kdl /etc/skel/.config/niri/dms/binds.kdl \
 && niri validate --config /staging/.config/niri/config.kdl \
 && dnf clean all \
 && rm -rf /var/cache/dnf /var/cache/yum /staging \
 && userdel -r builder
```

- Two assertions run first, and both are hard failures: `rpm -ql niri | grep -q '/systemd/user/niri.service'` and `rpm -ql dms | grep -q 'dms.service'`. The drop-ins of §4.7 and §4.8 and criteria 2d and 26 all rest on those two **user** units existing, and nothing else in the build checks it. If `niri.service` is absent, greetd runs `niri-session` as a script, no `niri.service` ever starts, and the `Wants=dms.service` drop-in is inert — a form no human criterion can catch, since an inert drop-in and a working one look identical from a login. Documented fallback in that case — at `/usr/bin`, **not** `/usr/local/bin`: on Atomic `/usr/local` is a symlink to `/var/usrlocal`, so it is mutable machine state that a build cannot make reproducible and which the `files` module is documented not to write — not a place for versioned content (§4.9) — stop relying on the `graphical-session.target` binding and wrap `niri-session` — `/usr/bin/niri-session-kinrin` execs `niri-session` after starting `dms.service` on the user bus. Criteria 2d and 26 must then be re-derived against that shape, since neither drop-in form exists in it.
- The second `sed` is a **correction, not a preference.** `dms setup headless` picks its terminal with `parseHeadlessTerminal("")`, which returns `TerminalGhostty` (`core/cmd/dms/commands_setup_headless.go:128-131`), and the deployer maps that to `terminalCommand = "ghostty"` (`core/internal/config/deployer.go:224-225`, the `case deps.TerminalGhostty:` arm and its assignment — the `default:` arm at `:231` holds the same value, so quoting it would have pointed at the wrong branch), substituted into the shipped template's `Mod+T … { spawn "{{TERMINAL_COMMAND}}"; }` (`core/internal/config/embedded/niri-binds.kdl:8`). The image installs `konsole`, not `ghostty`, so the `Mod+T` bind we deploy to both `/etc/niri/dms/` and the skel would be dead — and no criterion catches it, because 2b only tests `Mod+Space`, `Mod+N` and `Mod+Alt+L`. The `--terminal` flag does not help: it accepts only `ghostty`, `kitty` or `alacritty` (`commands_setup_headless.go:29,132-139`, the last of them the `unknown terminal` error at `:139`). Both `install` calls below read the corrected file, so the rewrite happens once.
- `util-linux` provides `su`, `shadow-utils` provides `useradd`. The base is a full Kinoite image, so both are almost certainly already there — the `install` is a guarantee, not a dependency.
- `-u 2000` on purpose, and `userdel -r builder` at the end on purpose. Without an explicit uid, `useradd` takes the first free one, 1000, and the account would stay in the image for the first real user to collide with. Nothing else creates that first account: the base ships `plasmalogin` enabled and §3 disables it, so no first-boot session-setup path ever runs, and criteria that say "the session user" (2c, 4, 12b, 17, 23, 30, 35) need one to exist. This `RUN` deliberately does not create it either — a baked-in account is not a first user. The creation path is an open decision in **§10**: sysusers plus a first-boot service, or `dms-greeter`'s own path. Record it in `NOTES.md`; the greeter must not offer `builder`. Sysusers alone is not enough, because it creates a home **without** copying `/etc/skel` (§7) — and the skel is the only route by which the niri config and the theme reach a user.
- `--config`, not a bare path. `niri validate` takes the config through `-c`/`--config` (`src/cli.rs:51-58`); its only positional is the subcommand list, and feeding it a path makes clap fail. Same for the post-build call in §5 and criterion 28.
- The trailing `niri validate` catches the **prefix** mistake and nothing else: an `include` inside another node is a parse error (`lib.rs:301`, the `include` arm of the top-level node loop — the line is a pointer into that arm, not the loop header), so a wrong position fails the build. It cannot catch a wrong **path** — `optional=true` emits `warn!("optional include not found")` and continues (`lib.rs:427-428`), so both `local.kdl` and `../local.kdl` validate while neither file exists. The path is therefore a review obligation, not a build gate. Say so in `NOTES.md` if you change it.
- `/staging` is removed with the caches: it holds the whole `dms setup` tree, and leaving it in the published image ships a second copy of the niri config that nothing references.
- The first `sed` is what keeps DMS's default keybinds. Omit it and seed a `binds.kdl` holding *only* the include: that file is not empty, so the deployer **skips** it and never writes the defaults — `Mod+Space`, `Mod+N` and `Mod+Alt+L` are then silently gone, and criteria 2 and 2b fail. (§4.4 states the rule; the command lives here only.)
- Only `config.kdl` and `binds.kdl` are copied. The other `dms/*.kdl` files are generated per user by DMS on first start, and shipping static copies would create a second source of truth. `/etc/niri/dms/` therefore holds `binds.kdl` alone: a home where the skel did not apply boots a bare niri — no colours, no layout, no cursor, all the includes being `optional=true` (§4.6). That is the intended degradation, not an oversight. Criterion 23 covers the normal path.
- `local.kdl` is **not** produced here: it is an authored file, owned by the `files` module (§4.4). Nothing in this `RUN` writes it, and nothing else does either.
- `config.kdl` goes to the skel as well as `/etc/niri/`. An include resolves relative to the directory of the file that includes it (`niri-config/src/lib.rs:374`, and the same at the entry point `:488`), so `/etc/niri/config.kdl` reaches `/etc/niri/dms/colors.kdl` — the static file baked into the image — and never `~/.config/niri/dms/colors.kdl`, which is the only path matugen writes. A user-side `config.kdl` moves the whole resolution into the home. Without it the theming of §4.12 is invisible to niri and criterion 17 fails.
- `dms setup` on the user's machine will then refuse, because `config.kdl` already exists. That is `--skip-existing` territory, not `--force`.
- Files land in `$HOME/.config/niri/`, not `$XDG_CONFIG_HOME`.
- `--skip-existing` and `--force` are flags of the **`headless`** subcommand, not of bare `dms setup`: `dms setup headless --compositor niri --skip-existing`. And with `--skip-existing`, when `config.kdl` already exists the command returns without deploying anything — so a first-boot re-run must not expect the deployer to refresh the empty files.
- The run deploys eight files — `colors`, `layout`, `alttab`, `binds`, `input`, `outputs`, `cursor`, `windowrules`, three of them empty — and writes the `config.kdl` holding the includes. The result passes `niri validate` as-is.
- `windowrules.kdl` is deployed but never included: 0 bytes, orphaned. Never put a `window-rule` there.
### 4.6 `include` must be `optional=true`

The `config.kdl` generated by DMS uses optional includes. A bare `include` against an absent file makes niri refuse to start (`exit=1`); `include optional=true` is tolerated (`exit=0`).

A nested `include` is a **parse** error at any depth, not a missing-file error: `include` is only recognised in the `include` arm of niri's top-level node loop (`lib.rs:301`, a pointer into the arm). A *missing* file is tolerated when `optional=true`. Keep every include `optional=true` and a missing file is not a boot risk.

Resolves with the skel `config.kdl` of §4.5: includes land in `~/.config/niri/dms/`, matugen writes there, so changing the theme updates the colours live. Without the skel copy the include lands in `/etc/niri/dms/` and the change is invisible. Criterion 17.
### 4.7 DMS environment variables

Three variables are needed: `XDG_CURRENT_DESKTOP=niri`, `QT_QPA_PLATFORMTHEME=gtk3`, `QT_QPA_PLATFORMTHEME_QT6=gtk3`. **None of them may be global**: a line in `environment.d` reaches the Plasma fallback too, where the gtk3 platform theme would be forced onto KDE's own apps (§11).

`XDG_CURRENT_DESKTOP=niri` goes in a drop-in, not in `environment.d`. The `niri.kdl` that `dms setup headless` writes and that §4.5 installs to both `/etc/niri/` and the skel already contains `environment { XDG_CURRENT_DESKTOP "niri"; }` (`core/internal/config/embedded/niri.kdl:137-139`) — but that is a **different mechanism, not a substitute**: a KDL `environment {}` block applies to what niri itself spawns, while `Environment=` in a drop-in sets the systemd unit's own environment, and criterion 26 reads that unit's environment. Only the drop-in satisfies it, and only the drop-in is scoped to the niri session. A global `environment.d` line would be the one entry that leaks into the Plasma fallback, where `niri` is wrong. The key is repeated in the `dms.service` drop-in for the reason the theme variables are: `dms.service` is a **separate unit** that `niri.service` merely `Wants=`, so the `niri.service` drop-in never reaches it, and the launcher and every app it starts would otherwise see no `XDG_CURRENT_DESKTOP` at all.

```ini
# /usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf
[Service]
Environment=XDG_CURRENT_DESKTOP=niri
```

This is the same reasoning as the theme variables, one step further: a unit's `Environment=` reaches that unit and its children, which is exactly the niri session and nothing else. Criterion 26 verifies it is present in the `niri.service` environment **and** absent from the Plasma session's.

There is no global branch. The only `environment.d` file the image ships is
`/etc/environment.d/90-dms.conf`, and it carries two keys **unrelated to DMS** —
`QT_QPA_PLATFORM=wayland`, which pins Qt clients to the Wayland backend under whichever session
runs, and `ELECTRON_OZONE_PLATFORM_HINT=auto`, which lets Chromium-based clients (discord, orca) pick Wayland without being forced onto it. Both are harmless under Plasma, which is Wayland-native, and neither is one of the three variables above. It takes `KEY=VALUE`, one per line, not KDL: an `environment { … }` block there is not a valid format and yields an unreadable file. None of the three variables above ever appears in it.

The two theme variables go in **two** drop-ins, because systemd does not pass one unit's `Environment=` to a unit that it merely `Wants=` — a drop-in on `niri.service` alone would never reach DMS, nor anything DMS launches:

```ini
# /usr/lib/systemd/user/niri.service.d/kinrin-theme.conf
[Service]
Environment=QT_QPA_PLATFORMTHEME=gtk3
Environment=QT_QPA_PLATFORMTHEME_QT6=gtk3
```

```ini
# /usr/lib/systemd/user/dms.service.d/kinrin-theme.conf
[Unit]
PartOf=niri.service
After=niri.service graphical-session.target

[Service]
Environment=QT_QPA_PLATFORMTHEME=gtk3
Environment=QT_QPA_PLATFORMTHEME_QT6=gtk3
Environment=XDG_CURRENT_DESKTOP=niri
```

`PartOf=` is what actually stops DMS, and it belongs here rather than in the `Wants=` file. `Wants=` has **no stop semantics at all** (`systemd.unit(5)`): it starts `dms.service` when `niri.service` starts and does nothing when niri exits. Without `PartOf=`, DMS outlives the compositor and criterion 2d's "not at all under Plasma" guarantee does not exist. `dms.service` already carries `PartOf=graphical-session.target` and `Requisite=graphical-session.target` (`assets/systemd/dms.service`), and the upstream `niri.service` `BindsTo=`s that same target, so the end of the session already stops DMS; the drop-in makes the stop unconditional — belt-and-braces, not the only stop path. The two units stay separate for the same reason the theme variables need two drop-ins: what is set on `niri.service` never reaches `dms.service`, a unit it merely starts, and the headless path carries no `spawn-at-startup` that would merge them.

The first covers the compositor process, the second the launcher and every app started from it — which is how Dolphin, Konsole, Kate and `plasma-discover` are reached in practice. An app started outside both units inherits neither, so a hand-typed `konsole` may not pick the theme up while the same app launched from DMS does. A Plasma session started from a TTY inherits neither, which is exactly the intent. Criterion 26.

`QT_QPA_PLATFORMTHEME=gtk3` and criterion 5 contradict each other: a Qt app inheriting it cannot be in Breeze. Criterion 5 asks that the packages resolve and the apps are usable, nothing about the theme.
### 4.8 What the packages already provide

- `niri` ships `niri.desktop` at `/usr/share/wayland-sessions/niri.desktop` with `Exec=niri-session`, and `plasma-workspace` ships `plasma.desktop` beside it — not `plasma-workspace-common` — so the greeter has both to choose from. Whether it actually offers Plasma is criterion 13; `Ctrl+Alt+F3` + `startplasma-wayland` works either way. `niri-session` sets up the systemd session.
- `dms` takes `org.freedesktop.Notifications`.
- `dms.service` already exists with `WantedBy=graphical-session.target`. Bind it to niri with a drop-in — the image-level form of `systemctl --user add-wants niri.service dms`:

  ```ini
  # /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf
  [Unit]
  Wants=dms.service
  Wants=graphical-session.target
  ```

The theme variables of §4.7 need two more drop-ins, one in the same directory and one for `dms.service`, and the VRR unit of §4.4 needs a fifth. Five files in total: this one binds the unit, `kinrin-xdg.conf` carries `XDG_CURRENT_DESKTOP`, the two theme drop-ins set environments, and `kinrin-vrr.conf` starts `niri-vrr.service`. No single one of them does both jobs, and none of the five is merged with another.

  **`After=` is load-bearing, not decoration.** `Wants=` in §4.8 pulls `dms.service` in but does **not** order it: `systemd.unit(5)` says requirement dependencies "do not influence the order in which services are started… If unit foo.service pulls in unit bar.service as configured with `Wants=` and no ordering is configured with `After=` or `Before=`, then both units will be started simultaneously". Since `dms.service` carries `Requisite=graphical-session.target`, which the same man page says "should usually be combined with `After=`", the race is not cosmetic: without this line `dms` can test `Requisite` before the target is active and fail immediately, while `niri` carries on without DMS — criterion 2d stays green on "no DMS under Plasma" and the niri session still has none. The ordering is declared on the *wanted* unit, exactly as §4.4 does for `niri-vrr.service`.

**Do not `systemctl --user enable dms` instead.** `enable` starts DMS in *every* session, and §1 keeps Plasma as a fallback — DMS would then launch in the Plasma session too. `Wants=` on `niri.service` starts it when niri starts and does nothing when niri exits. The stop path is the `PartOf=niri.service` drop-in of §4.7, not this one: `dms.service` already carries `PartOf=graphical-session.target` and `niri.service` `BindsTo=`s the same target, so the end of the session already stops DMS — the drop-in makes that stop unconditional, belt-and-braces rather than the only path. The second `Wants=` is robustness, not the mechanism: the upstream `niri.service` `BindsTo=`s `graphical-session.target`, and a `BindsTo=` pulls the target in the way a `Requires=` would, so this line only covers an RPM that patches the units. `dms.service` itself carries `Requisite=graphical-session.target` and fails when the target is inactive.

  **There is no autostart to remove, and the check would be vacuous.** `dms setup headless --compositor niri` implies systemd (`headlessUseSystemd` has two exits: `noSystemd || wm == deps.WindowManagerMango` returns false, otherwise `!isVoidSetup()` — `commands_setup_headless.go:143-148`; §4.5 passes neither `--no-systemd` nor mango, and `isVoidSetup()` looks `ID` up in `distros.Registry` for `FamilyVoid` (`commands_setup.go:392-399`), a family only `"void"` registers (`distros/void.go:25-26`, the sole `Register` carrying `FamilyVoid`) — so the lookup returns false for `fedora` and equally for the `kinrin` of §5, which changes nothing here: `ID=kinrin` returns what `ID=fedora` returned, and the result is true), so `transformNiriConfigForNonSystemd` — the only code that writes `spawn-at-startup "dms" "run"` — is never reached, and `core/internal/config/embedded/niri.kdl` contains no `spawn-at-startup` at all. The `RUN` copies `config.kdl` verbatim, so nothing filters it either. The real duplicate is elsewhere: DMS itself runs `systemctl --user add-wants niri.service dms` at runtime (`core/internal/distros/base.go:574`), on top of the image drop-in. Criterion 2d checks that dependency, not a string.
- SELinux: we add no labeling step, and the RPM already did it. `dms-greeter`'s `%post` sets three fcontexts — `bin_t` on `/usr/bin/dms-greeter`, `user_home_dir_t` on `/var/lib/greeter(/.*)?`, `cache_home_t` on `/var/cache/dms-greeter(/.*)?` — then `restorecon`s them in **four** actions, the fourth being `restorecon /etc/pam.d/greetd` (`dms-greeter.spec:113-128`, the PAM line at `:127`). The whole block is guarded by `[ -x /usr/sbin/semanage ] && [ -x /usr/sbin/restorecon ]` (`dms-greeter.spec:113`), and that guard is redundant rather than a branch: the `Requires: policycoreutils-python-utils` is hard (`dms-greeter.spec:26`), so the branch without the tools is impossible. Probe that same pair at build time — `test -x /usr/sbin/semanage && test -x /usr/sbin/restorecon` — and record the answer. `dms-greeter enable` does **not** label anything — it enables greetd (`greeter_install.go:667`) and sets `graphical.target` (`:686-715`, `ensureGraphicalTarget`). `chcon` still does not work in a bootc build, and a build-time `restorecon` is undone at the next boot. What actually makes the greeter render is not a label but the logind ACL of §4.1.
- Run `dms-greeter enable` once as root after installing the RPM, before the first boot: it is the RPM's own documented step (`dms-greeter.spec:247`) and it is what sets `graphical.target`, which the `%post` also attempts. Our recipe already does the equivalent with `systemd-system.yaml`'s `system: {enabled: [greetd], disabled: [plasmalogin.service]}`, so this is a **first-boot check**: confirm `systemctl get-default` reports `graphical.target`, greetd is enabled, and both `systemctl is-enabled plasmalogin.service` and `sddm.service` report `disabled` or `not-found` — checking only the `display-manager.service` symlink passes vacuously if the base enables `plasmalogin.service` directly. Run `dms-greeter enable` only if the target or greetd is wrong.
### 4.9 Games — Steam and Proton

`steam` comes from `rpmfusion-nonfree`, enabled by the `nonfree: rpmfusion` key of §4.0.

- Install `steam` and `steam-devices` only. `wine`, `lutris`, `mangohud` and `gamemode` are available, not installed, and no criterion covers them. `mangohud` is an RC, so rule 2 forbids adding it. Decide before adding any of them.
- `gamemode` works in windowed mode: it renices and sets CPU/GPU governors per game, without a nested compositor. It is usually configured per title in the launcher, not globally.
- No `proton` package exists in Fedora or RPM Fusion. Enable Steam Play in *Steam → Settings → Compatibility*; the client installs its own Proton and picks per game. Only Proton-GE needs ProtonUp-Qt (`net.davidotek.pupgui2`), then select it in *Properties → Compatibility*.
- Gamepads: `steam-devices` provides `/usr/lib/udev/rules.d/60-steam-input.rules` and `60-steam-vr.rules`. `uinput` needs nothing written. Do not add the user to `input` — the `TAG+="uaccess"` rules already grant `/dev/uinput`, and `input` also allows reading `/dev/input/event*`.
- Criterion 22 covers the path on real hardware. Expect two limits: the gamepad does not move the pointer outside Steam, and a Steam crash on gamepad connect is unverified here. If criterion 22 reproduces the crash, load `extest` in `LD_PRELOAD` for Steam only: take `extest.c` from the fork `nmd2k/extest-steam-input-fix` (upstream is insufficient), `install -d /usr/local/lib64/extest` first — `gcc -o` does not create parent directories, and this is the only file-writing command in §4 that does not either use `install -D` or run `install -d` first — then `gcc -shared -fPIC -o /usr/local/lib64/extest/libextest.so extest.c` for **x86_64** (the source file is the `extest.c` named in the same sentence; a bare `gcc -shared -fPIC` with no input cannot run) — a 32-bit object cannot be preloaded into Fedora's 64-bit `steam` — and clone the shipped entry and edit its `Exec`, rather than writing a stub — a file without `[Desktop Entry]`, `Type` and `Name` is not a valid desktop entry and is ignored:

```bash
install -D /usr/share/applications/steam.desktop /usr/local/share/applications/steam.desktop
sed -i 's|^Exec=.*|Exec=env LD_PRELOAD=/usr/local/lib64/extest/libextest.so /usr/bin/steam %U|' /usr/local/share/applications/steam.desktop
```
(`/usr/local/share/applications` precedes `/usr/share/applications` in `$XDG_DATA_DIRS`, so the clone wins. Clone the shipped entry and edit its `Exec`, never write a stub: a file without `[Desktop Entry]`/`Type`/`Name` is ignored. **Host-side, not image content**: on Atomic `/usr/local` is a symlink to `/var/usrlocal`, so it is machine state under `/var` — the persistence §3.2 relies on — and nothing here needs redoing after a `bootc switch`. A library under `/usr/lib64` would instead be wiped with the deployment, and `/usr` is read-only on a booted host without `bootc usroverlay`. `/etc/steam.desktop` does not exist and never will: the RPM ships its launcher in `/usr/share/applications/`, and a file in `/etc` would be read by nothing. Never edit or mask the RPM's own file — `mask` is systemd vocabulary for `/dev/null`, and a package-owned file reverts on update.)
- Steam window entirely black on some machines: *Settings → Interface* → disable GPU acceleration of web views, then restart. If it is still black, note that `-system-composer` is a **gamescope** flag, not a Steam one — there is nothing to pass to Steam. With gamescope added on request (§4.9), it belongs inside the wrapper: `gamescope -system-composer -- %command%`.
- Steam notifications arrive as floating windows in the centre of the screen. Send them to the bottom right with a `notificationtoasts_*` `window-rule` — the block is in `/etc/skel/.config/niri/local.kdl`, per §4.4, which is where both rules live. The `alttab.kdl` DMS ships is rewritten on every theme change, which is why neither rule goes there.

VRR over IPC, applied by the `niri-vrr.service` unit of §4.4 rather than by a file:

```bash
niri msg output <NAME> vrr on --on-demand
```

`on-demand` limits VRR to the windows that ask for it. No file is involved, so `dms setup` cannot touch it. Read the real output name with `niri msg outputs`; `<NAME>` is a placeholder. Criterion 31.

The per-window half is the `steam_app_*` `window-rule` with `variable-refresh-rate true`, and it goes in the skel `local.kdl` with the Steam notification rule, per §4.4.

`gamescope` is not shipped by default; §4.9 decides on request. If the cursor escapes a window during a game, add it to the §4.0 package list (Fedora `updates`) and wrap the game: `gamescope -f -w 1920 -h 1080 -W 1920 -H 1080 --force-grab-cursor --backend sdl -- %command%` — those four numbers are a worked example, **not values to keep**: match `-w`/`-h` and `-W`/`-H` to the panel, or a 1440p or 4K display gets a 1080p frame scaled or letterboxed, which is functional enough that criterion 20 still passes and visibly wrong all the same. `--backend sdl` is required — the default Wayland backend does not lock the cursor. Criterion 20 covers a game without it.
### 4.10 Discord

- `discord` is in `rpmfusion-nonfree`, the same repo as `steam`. No extra COPR, no extra repo. `discord-canary` and `discord-ptb` do not exist as RPMs.
- No conflict with `steam`, no 32-bit dependency, so no `--allowerasing`.
- Its weight comes from GTK3 and X11: `atk`, `atspi`, `libXcomposite`, `libXdamage`, `libXrandr`, `libXtst`. It is a Chromium client, not a GTK one, so `QT_QPA_PLATFORMTHEME=gtk3` never reaches it: it follows its own theme and the `ELECTRON_OZONE_PLATFORM_HINT=auto` of §4.7, which is what decides Wayland vs XWayland for its window.
- If an application exists as an RPM, take the RPM, not the Flatpak.
- Screen sharing in a call goes through `ScreenCast` and `RemoteDesktop`; the §4.2 config is what makes it work. Criterion 25.
### 4.11 Development — opencode and orca

Fedora already provides the base, as official RPMs:

| Need | Packages |
|---|---|
| Node | `nodejs` — `npm` is a separate package |
| Git | `git`, `git-lfs` |
| Containers | `podman` — no `docker` |
| Rust | `rust`, `cargo`, `rustfmt`, `rust-analyzer` |
| Go | `golang`, `golangci-lint` — the binary is `go` |
| Python | `python3`, `python3-pip` |
| C/C++ | `gcc`, `make`, `cmake`, `gdb` |
| Search | `ripgrep`, `jq` — no `fd`, no `nushell` |
| Shells | `fish`, `zsh` |

opencode: no RPM, no Flatpak. The appids `dev.sst.opencode`, `com.sst.opencode`, `sst.opencode` and `dev.anomaly.opencode` are all 404 on Flathub. The only channel is the install script:

```bash
curl -fsSL https://opencode.ai/install | bash
```

It edits the user's shell files; `--no-modify-path` prevents that. Do not ship it. The user runs it once in the home. Read from the script itself (460 lines at `https://opencode.ai/install`): the install directory is **hard-coded** — `INSTALL_DIR=$HOME/.opencode/bin` at `install.sh:68` is the only assignment in the file, and the only flags are `-v/--version`, `-b/--binary` and `--no-modify-path`. There is **no** environment override, so `$OPENCODE_INSTALL_DIR`, `$XDG_BIN_DIR` and `$HOME/bin` are not consulted; the binary lands in `~/.opencode/bin` and `bootc upgrade` does not touch it.

orca: the GitHub release ships an RPM, and that is the one to take — the AppImage mounts in the home on every launch. The repository is **`stablyai/orca`**, and two reads the same day apart, `prerelease: false` both times, `v1.4.215` published 2026-09-27 and `v1.4.217` later the same day — the same shape, 21 assets, only the tag different — a snapshot of `releases/latest`, which is by construction never assumed current at build time, and not a tag this plan chose.

```
# shape only, read 2026-09-30: the tag moves, the shape holds, and the SIZES are per-release —
# a later release will carry different ones, so never carry a size forward with a tag bump
orca-ide-1.4.217.x86_64.rpm      144,5 MiB   (this release's size, not a figure to keep)
orca-ide-1.4.217.aarch64.rpm     139,9 MiB   (ditto)
orca-linux.AppImage              206,7 MiB   (do not use)
```

The RPM installs through `dnf`, so it lives in the image and updates with it. Fetch it through the API, with no version anywhere in the URL:

```bash
# ONE snippets: entry, not three: the v2 runner starts each entry in its own `/bin/sh -c 'set -eu; …'` subshell, so $url set in one entry is gone in the next. The `case` binds the URL to the one download prefix the live `releases/latest` response
# uses, so a redirected or substituted host is never handed to `dnf install`: `test -n` alone accepts any
# well-formed URL, and an empty-URL guard is not an origin check. It binds origin, it does not authenticate —
# a same-origin hostile asset would still pass, and closing that needs a signature check, which is new design
# rather than a minimal fix. No pipefail: it is not POSIX, and every failure mode here already collapses to an empty $url — curl -f unlinks its output on an HTTP error, jq reports to stderr with empty stdout, grep matches nothing. test -n is the fail-closed guard.
url=$(curl -fsSL https://api.github.com/repos/stablyai/orca/releases/latest \
  | jq -r '.assets[].browser_download_url' | grep -E 'x86_64\.rpm$' | head -n1) \
  && test -n "$url" \
  && case "$url" in https://github.com/stablyai/orca/releases/download/*) ;; *) exit 1 ;; esac \
  && dnf install -y "$url"   # dnf resolves the RPM's own dependencies
```

`releases/latest` already excludes drafts and prereleases, so nothing is pinned. The `releases/latest/download/<asset>` shortcut is **not** usable here: its path segment is the asset filename, and every orca asset name carries the version, whatever tag is current (`orca-ide-<version>.x86_64.rpm`) — using it means hard-coding whichever tag happens to be current in the recipe, which is the pin rule 2 forbids, and the build breaks the next release. The `grep` also keeps the AppImage and the `aarch64` RPM out of the candidates; the numbers in the listing are the release at build time.

Image scope ends at the base: the Node package manager, the LSP servers and `opencode.json` are user config under `$HOME/.config`, and the packages in the table above are installed in §4.0 — the seventeen the base does not ship are declared there explicitly, and `gdb`, `jq`, `python3` and `podman` are already in the base. This is the RPM list and nothing more: **`opencode` is not shipped**, because no channel exists for it in a package (see above). Two checks remain, both folded into criterion 29: that the orca RPM's dependencies resolve inside the image, and that orca coexists with the greeter.
### 4.12 Themes — Dracula over Breeze Dark, Alucard over Breeze Light

One theme file drives everything. `dark` is Dracula, `light` is Alucard. DMS picks between the two on its **own light/dark mode setting**, not on anything in the theme file: `Theme.qml:1895-1896` reads `customThemeRawData.dark` or `.light` according to the current mode. So Alucard is not a second theme to install and not a variant to pick — it is the same file, already present, reached by flipping that one toggle. Criterion 34. Colours only: matugen repaints colours and leaves widget style, icons and cursor untouched, so Breeze stays underneath and covers whatever a colour scheme does not reach. That is the fallback, and it is the mechanism's natural behaviour — the dracula repository itself has no chaining of any kind.

Ship the theme read-only in the image — **one file**, and nothing else:

```
/usr/share/dms-themes/dracula/theme.json
```

Never list a file here that no command fetches. The previews are cosmetic and their registry paths are unverified offline; if you ever want them, add the `curl` calls and the assertions together.

Take it from the DMS plugin registry, **branch `master`**:

```
https://raw.githubusercontent.com/AvengeMedia/dms-plugin-registry/master/themes/dracula/theme.json
```

Not from `dracula/dankmaterialshell`: that copy claims version `1.0.2` but is missing `surfaceContainerLowest` and `surfaceContainerLow`, which the registry copy has. `raw` cannot list a directory, so a 404 on `.../themes/dracula/` is expected, not a missing theme.

Assert the shape, do not eyeball it. Two keys at top level and one inside **each** of `dark` and `light` carry the whole of criterion 34, and the wrong copy of the file fails silently — DMS falls back to a default theme rather than erroring — so this runs in `theme.yaml`, which must be **`type: script@v2`**, not `type: files`. The `files` module only writes paths: its schema is `type, no-cache, env, secrets, files`, with no way to execute anything and no way to fetch a URL. The same script downloads the registry copy, which is the other half of why it cannot be a `files` module — nothing else in the recipe ever fetches the theme:

```bash
install -d /usr/share/dms-themes/dracula
curl -fsSL -o /usr/share/dms-themes/dracula/theme.json \
  https://raw.githubusercontent.com/AvengeMedia/dms-plugin-registry/master/themes/dracula/theme.json
jq -e 'has("dark") and has("light") and (.dark.surfaceContainerLowest | type == "string") and (.light.surfaceContainerLowest | type == "string")' \
  /usr/share/dms-themes/dracula/theme.json
install -Dm444 /usr/share/dms-themes/dracula/theme.json \
  /etc/skel/.config/DankMaterialShell/themes/dracula/theme.json
```

Any exit code but 0 fails the build. The predicate asserts the canary's **type**, not its presence: `has()` passes a payload whose keys are intact but whose values are junk, so `{"dark":{"surfaceContainerLowest":null}}` and `…:42`
both cleared the earlier `has()` form and would have installed a theme DMS cannot use — the exact silent-fallback
outcome criterion 34 exists to catch. Executed against ten shapes: the type form accepts only a real string and
rejects null, numeric, missing key, missing section, `{}`, `[]`, a bare string, a bare number and non-JSON.

Seed the per-user side from the skel:

```
/etc/skel/.config/DankMaterialShell/themes/dracula/theme.json
/etc/skel/.config/DankMaterialShell/settings.json
```

```json
{
  "configVersion": 33,
  "currentThemeName": "custom",
  "customThemeFile": "/usr/share/dms-themes/dracula/theme.json",
  "matugenTemplateQt5ct": false,
  "matugenTemplateQt6ct": false
}
```

- There is deliberately **no** `currentThemeCategory` in that file, and adding one would buy nothing: the property carries its own literal default (`Theme.qml:42`, `"generic"`) and nothing binds it to the settings file — the only write from a stored value is `applyStoredTheme`'s `Theme.currentThemeCategory = currentThemeCategory`   (`SettingsData.qml:1288`), and the `switchTheme` it then calls (`Theme.qml:1372-1409`) overwrites
it in memory; its persist at `:1402` is gated on `savePrefs` and this call passes `false`, so the skel key is shadowed, never rewritten. A save then drops any value equal to the default (`SettingsStore.js:209-211`, the default being `SettingsSpec.js:10-12`), so the grid's `=== "registry"` tests never match this theme either way.

- Two mechanisms, two different jobs — do not confuse them. `customThemeFile` is what makes Dracula **apply at first login with nothing touched**, which is what criterion 34 requires. The skel copy under `themes/dracula/` is what makes it **selectable** in the Settings → Theme grid, so the user can pick it again later. Remove `customThemeFile` and criterion 34 fails; remove the skel copy and the theme applies but is invisible in the UI.
- `configVersion` is mandatory. Omitted, DMS reads the file as version 0 — `var currentVersion = settings.configVersion || 0` (`SettingsStore.js:222`), with the early return at `:224-226` — and runs the entire migration chain over it on first start. **`33` is the value in the tree read on 2026-09-30** — `SettingsData.qml:24` carries `settingsConfigVersion: 33`, the chain tops out at `quickshell/Common/settings/SettingsStore.js:706`, and versions `31` then `33` are consecutive assignments, so an older number is a downgrade rather than a harmless default. This is a **dated reading, not a pin**: the COPR serves `dms` at `:latest` under rule 2, and if that release carries a higher number the skeleton value is a downgrade rather than an error, so re-read `SettingsData.qml:24` from the installed `dms` before each build and change this one number if it moved. The number is written into the skeleton at authoring time — the §4.5 `RUN` runs *after* `files.yaml` has already
  written this file, so it cannot inject into it — which is why the re-read is a manual step before each build rather than something the
  build does for you.
- The two `false` entries are a precaution, **not** a proven fix, and the earlier justification for them does not hold: `grep platform_theme` over the whole DMS tree — go, qml, toml, conf — returns nothing, so no template demonstrably writes that key. What is verified is only the toggle default (`SettingsSpec.js:952` for Qt5ct, `:955` for Qt6ct, both `true`); what the templates then write is not. Keep both `false` because leaving them `true` lets an unexamined template run against the `QT_QPA_PLATFORMTHEME=gtk3` of §4.7, and settle the outcome by observation, not by argument: the §4.5 `niri-config.yaml` script is the post-build inspection, and criterion 5 is the human one.
- Write only non-default **SPEC** keys; DMS drops a `SPEC` key equal to its default on its next save (`SettingsStore.js:209-211`). `configVersion` is **not** a `SPEC` key — `SettingsSpec.js:1467` lists it only inside `getValidKeys()` — and `SettingsStore.js:213` writes it unconditionally, outside that filter, which is why it is mandatory even though 33 is the current default.
- The skel copy under `themes/dracula/` is what puts Dracula in the **Settings → Theme** grid. Without it the theme still applies but is not listed anywhere.
- It will not appear under **Browse Themes** — `refreshThemes()` fills `allThemes` from `listThemes()` only (`ThemeBrowser.qml:202`, the fill at `:205-213`), so the list is the remote registry. `listInstalledThemes()` (`:216-222`) is ignored on success; it is a fallback path, not a second source. Do not add a local registry to fake it: the cache is a git clone under `$TMPDIR`, and `Pull` against a local clone is unverified.

Six toggles are verified from source, and no more: `matugenTemplateGtk` `def: true` (`SettingsSpec.js:940`), `matugenTemplateNiri` `true` (`:943`), `matugenTemplateQt5ct` `true` (`:952`), `matugenTemplateQt6ct` `true` (`:955`), `matugenTemplateKcolorscheme` `true` (`:1003`), and `matugenTemplateNeovim` `false` (`:994`) — the one `def: false` among them. DMS ships templates for further apps — terminals (`kitty`, `alacritty`, `foot`, `ghostty`, `wezterm`), browsers, editors — but no line number for any of those is recorded here, so nothing below may depend on them. What holds: terminals follow through their own templates; Qt apps follow via gtk3, which is what the two `false` entries above leave alone. It writes:

- `~/.config/niri/dms/colors.kdl` — niri, from `niri.toml`. Only visible if the skel `config.kdl` of §4.5 is in place, otherwise the include resolves into `/etc/niri/dms/` and niri never reads this file.
- `~/.local/share/color-schemes/DankMatugen{,,Light,Dark}.colors` — KDE, from `kcolorscheme.toml`

The second is what themes the Plasma fallback from the same theme file, which is why the §4.7 split works: under niri the Qt apps follow the GTK colours, under Plasma they follow Breeze with matugen colours on top.

`DMS_DISABLE_MATUGEN=1` (`Theme.qml:24`) stops generation entirely. **The greeter is not part of that question**: it does not generate anything. It reads the theme that `dms-greeter sync` symlinked into `/var/cache/dms-greeter/` from the session user's home (criterion 12b), so there is no local generation to disable and no `colors.kdl` under `/var/lib/greeter` to look for. Criterion 35 covers the session side only.
### 4.13 Licensing — the dracula repositories, and the one file we take

Checked against the GitHub API, not assumed: **`dracula/kde` does not exist** (`404`), while
`dracula/gtk` does, and `dracula/dracula-theme` ships per-app trees — `themes/gtk`,
`themes/gtksourceview`, `themes/kate`, `themes/konsole`, `themes/qt5`, `themes/qtcreator` — with no
`themes/kde` and no `metadata.desktop` anywhere in it. So "the GPL-3.0 KDE tree inside the MIT
monorepo" is a claim about a repository that is not there, and `X-KDE-PluginInfo-License=GPLv3` is not a citation we can point at. What survives: the dracula organisation is not MIT-uniform, per-app trees differ from the root, and **we install none of it either way**.

Scope was cut to DMS + matugen precisely to avoid this. What we ship from dracula is the DMS `theme.json` — a JSON colour definition, not artwork — fetched from the **DMS plugin registry** (§4.12), not from the dracula monorepo. So no GPL-3 KDE artwork enters the image, and the statement "no dracula artefact is installed" is one the build can actually check: only `theme.json` is fetched, by the assertion in §4.12. The one thing that is **not** settled is that file's own licence: the source repository declares none for it, so it cannot be folded under dracula's MIT, and it must be carried in the §10 licence decision as an unlicensed component rather than as MIT.
### 4.14 `dms` writes nothing to an immutable system unless we say so

`dms setup headless` carries `PersistentPreRunE: requireMutableSystemCommand` (`core/cmd/dms/commands_setup_headless.go:15`, the gate itself at `core/cmd/dms/immutable_policy.go:252`), and plain `dms setup` the privileged variant (`commands_setup.go:24`). The gate reads two policy files — `/usr/share/dms/cli-policy.json` first, then `/etc/dms/cli-policy.json` (`immutable_policy.go:17-18`) — and refuses only when the system reads as immutable **and** the command matches `blocked_commands`. Detection is true on this base twice over: `/run/ostree-booted` is checked first (`:167`), and `VARIANT_ID` is read at `:178` and tested against the marker list at `:197` — it carries `kinoite`, so the return at `:198-199` fires. The shipped defaults are **four explicit entries** — `greeter install`, `greeter enable`, `greeter uninstall`, `setup` — each matched exact-or-prefix rather than by equality (`immutable_policy.go:77`, `normalizedPath == spec || strings.HasPrefix(normalizedPath, spec+" ")`), so the single `setup` entry covers `setup headless …` (``core/cmd/dms/assets/cli-policy.default.json` carries all four; the in-code fallback at `immutable_policy.go:217` carries only **three**, missing `greeter uninstall`, so take the four from the JSON asset and never from the Go literal (§11).

That would make §4.5 fail. The `files` module therefore writes, before `niri-config.yaml` runs:

```
/usr/share/dms/cli-policy.json
```

```json
{"policy_version": 1, "immutable_system": false, "blocked_commands": []}
```

`sync` is deliberately **not** blocked upstream, so criterion 12b is unaffected by this file. In the override above, `immutable_system: false` is the operative key, not `blocked_commands`: the gate returns on it before it ever reaches the matching loop (`immutable_policy.go:257`, `if !policy.ImmutableSystem { return nil }`), which is why an empty `blocked_commands` list is belt-and-braces rather than what unlocks the build. The `dms` RPM installs no policy file at all — its `%files` list (`dms.spec:113-118`, and the `dms-cli` subpackage at `:120-124`) ships a quickshell data dir, `dms.service`, three desktop files and a scalable icon (`:118`), and no `/usr/share/dms/` whatsoever — so without this one the build has nothing to read. This file is therefore the **only** policy `dms` will ever read, and it is one of the two overrides the image owns for `dms`: this one for the CLI gate, the `dms.service` drop-in of §4.7 for the unit. Both are ours, neither is upstream, and both are listed in the `files.yaml` row of §5.2.

---
## 5. Recipe

The `signing` module hard-requires a **public** key file at the repository root, named exactly `cosign.pub` (`COSIGN_PUB_PATH = "./cosign.pub"`, resolved against the working directory by `has_cosign_file()` in BlueBuild's `template/src/lib.rs`). Without it the template stages no key, `modules/signing/signing.sh` prints ``Cannot find 'kinrin.pub' image key in '/etc/pki/containers/'`` and `exit 1` — at the **last** module, after the 20-minute bootc build has already run. Commit `cosign.pub` to the repository root: the public half only, never the private key, which stays in the `COSIGN_PRIVATE_KEY` secret. It is the public half of the same key pair, and it is not a secret.

Required fields: `name`, `description`, `base-image`, `image-version`, `modules`. `version` is optional — it is written below as `1` because a recipe carrying one is unambiguous, not because the schema demands it. A module is one entry of the `modules:` list: **eight** are `from-file:` entries pointing at a YAML file, and `- type: signing` is inline and gets no file. `systemd-user.yaml` was a ninth and is gone: it existed only to `enable niri-vrr.service`, and §4.4 activates that unit from a `niri.service` drop-in instead.

```yaml
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
version: 1
name: kinrin
description: Fedora Kinoite with Niri and DankMaterialShell as the primary desktop
base-image: quay.io/fedora/fedora-kinoite:latest
image-version: latest

modules:
  - from-file: modules/dnf.yaml
  - from-file: modules/flatpak.yaml
  - from-file: modules/files.yaml
  - from-file: modules/systemd-system.yaml
  - from-file: modules/niri-config.yaml
  - from-file: modules/theme.yaml
  - from-file: modules/orca.yaml
  - from-file: modules/os-release.yaml
  - type: signing
```

Every module is an official BlueBuild type, or a `from-file` pointing at one, with one exception: `niri-config.yaml` must be **`type: script@v2`**, carrying the `RUN` of §4.5 in `snippets:` — as **the shell body with the Dockerfile `RUN` verb stripped**, since a snippet is a plain `/bin/sh` command string and pasting the block verbatim gives `RUN: command not found` — the version is not optional: `script` is one of only two multi-major BlueBuild
  modules, its bare form tracks the `latest` tag, and that tag is reassigned to the highest major on every upstream
  push, so a bare `script` silently becomes `@v3` when one lands. v2 is POSIX shell with `set -eu` per entry and no
  `pipefail`; v1 is bash and accepted only as the literal `script@v1`. Every other type here is single-major, so its bare
  form is already `@v1` and cannot drift. This is a build-tooling tag, not a package pin, so rule 2 does not govern it — because that step needs root and a non-root `dms setup` in the **same** layer. It is not `type: custom`: that module's schema is `type, source, no-cache, env, secrets` with **no inline content key** — `source` is an OCI image ref. `script` runs as root in the same layer, which is exactly the need. Keep it to that single stage: no `FROM … AS`, no `COPY --from`, no second builder image. No Rust toolchain **in the build stage** — §4.0 ships one in the image — and no `containerfile_script`.

```bash
bluebuild validate  recipes/recipe.yaml            # pre-build, fails in seconds
bluebuild generate recipes/recipe.yaml -o /tmp/Containerfile
bluebuild build -vv recipes/recipe.yaml            # a bare local build tags localhost/kinrin:latest
podman run --rm localhost/kinrin:latest niri validate --config /etc/niri/config.kdl
```

Order matters: `bluebuild validate` exists to fail before a 20-minute bootc build, not after it. `niri validate` runs **inside the built image** — the binary is absent from a clean CI runner and a host-side call would not see the image's config anyway. Write the generated Containerfile to `/tmp` — outside the repository, so there is nothing to gitignore; never emit it into the repo.

With `bluebuild validate`, `niri validate` are two of the **four** checks CI runs on the whole image (criterion 28), the third being the §6.1 step that reads the signing policy out of the built image (criterion 28b) and the fourth the presence chain over the `files.yaml` destinations (criterion 28); §8 is a human list, not a gate. **That fourth check exists because nothing else can see a `files` destination go missing.** A `{source:}` entry with no `{destination:}` leaves `DEST` the literal string `null`, `cp -f` succeeds and the module exits 0 — a green build shipping an empty image. `bluebuild validate` does not catch it: the schema types the list as `Array<Record<string>> | Array<{source; destination}>`, so the destination-less form is schema-**valid** through the `Record<string>` branch, and no other gate looks at a `files.yaml` path. Thirteen `test -f` in one `&&` chain, run inside the built image: ```bash podman run --rm <image> sh -c 'test -f /etc/xdg/xdg-desktop-portal/portals.conf && test -f /etc/greetd/config.toml && test -f /etc/systemd/logind.conf.d/kinrin.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/dms.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf && test -f /usr/lib/systemd/user/niri-vrr.service && test -f /etc/environment.d/90-dms.conf && test -f /usr/share/dms/cli-policy.json && test -f /etc/skel/.config/niri/local.kdl && test -f /etc/skel/.config/DankMaterialShell/settings.json' ``` `<image>` is `localhost/kinrin:latest` for a local build and `ghcr.io/${OWNER,,}/kinrin:latest` in CI. The thirteen are the §5.2 `files.yaml` destinations and nothing else: the dracula copies come from `theme.yaml` (`curl -f` unlinks on error, and `install -Dm444` exits 1 on a missing source), `/etc/niri/*` and the skel `config.kdl`/`binds.kdl` come from §4.5's `RUN`, `/etc/os-release` and `cosign.pub` from their own modules, and each already fails closed under its own producer.

After the build, `/etc/os-release` must carry the ID `kinrin` and an `ID_LIKE` that still names `fedora`, and the post-build gate is `grep -qE '^ID="?kinrin"?$' /etc/os-release && grep -qE '^ID_LIKE="?fedora"?$' /etc/os-release` run inside the image — the `os-release` module serialises values **with quotes**, so a bare `^ID=kinrin` fails on a correct build.
### 5.1 Build traps

- Never run `dnf update` in the build: kernel and bootloader do not behave well during a build.
- Clean after installation, or the image bloats and the GHCR push times out:

  ```bash
  dnf clean all
  rm -rf /var/cache/dnf /var/cache/yum
  ```

Never `rm -rf /var/{log,cache,lib}/*`: the glob is too broad and `lib` holds `/var/lib/rpm`, the image RPM database. Losing it makes the image unverifiable.
- Free runner disk first, bootc images grow fast:

  ```yaml
  - name: Free disk space
    run: rm -rf /opt/hostedtoolcache
  ```

- `steam` pulls 1 GiB, measured in isolation from a minimal base — the packages overlap this one, so the marginal cost is lower — and the module's cleanup runs after its `install:` block, with no mechanism to interleave a cleanup between two packages.

---
### 5.2 Module contents

Every `from-file:` entry in §5 needs a file, and the recipe alone does not say what is in them. This is that list. No module invents content: each one carries text quoted from the section named.

| Module | Type | Carries |
|---|---|---|
| `dnf.yaml` | `dnf` | the `repos:` and `install:` blocks of §4.0, verbatim |
| `flatpak.yaml` | **`script@v2`** | the six-command cleanup of §3.2 in `snippets:` — it is a multi-command shell step, and it must sit **after** `dnf.yaml` because it wants `/var/lib/flatpak` still empty and no user session run yet; both binaries are already in the base (§3.1) |
| `files.yaml` | `files` | `portals.conf` (§4.2), `greetd/config.toml` (§4.1), `/etc/systemd/logind.conf.d/kinrin.conf` (§4.0), **the four §4.7–§4.8 drop-ins (`kinrin-dms`, `kinrin-xdg`, two `kinrin-theme`)**, `/etc/environment.d/90-dms.conf` with its two unrelated keys (§4.7), **`/usr/lib/systemd/user/niri-vrr.service` and its `niri.service.d/kinrin-vrr.conf` drop-in (§4.4)**, `/usr/share/dms/cli-policy.json` (§4.14), the skel `niri/local.kdl`, and the skel `DankMaterialShell/settings.json` (§4.12) — the skel `themes/dracula/theme.json` is written by `theme.yaml` itself, not by `files` This row is the authoritative list: the §5 and §6.1 presence chains must enumerate exactly these thirteen in this order. A destination added here but to neither chain ships unchecked, and a chain shortened by one path still exits 0, so neither chain can detect its own drift. |
| `systemd-system.yaml` | `systemd` | `system: {enabled: [greetd], disabled: [plasmalogin.service]}` — the base ships a DM enabled, its `display-manager.service` alias pointing at `plasmalogin.service` (verified in `quay.io/fedora/fedora-kinoite:latest`), and two DMs fight over VT1. **`display-manager.service` must NOT appear in `disabled:`**: greetd activates only through that alias (`[Install] Alias=display-manager.service`, no `WantedBy=`), the module runs `enabled:` before `disabled:`, and the `-f enable` half already repoints the alias at greetd — so disabling it would delete the symlink just created and leave greetd disabled with `graphical.target` wanting a name that resolves to nothing (§3) |
| `os-release.yaml` | `os-release` | `properties: {ID: kinrin, ID_LIKE: fedora}` — `ID_LIKE` is not optional once `ID` changes (§3), and the module runs **last of the eight**, after `dnf.yaml`, `niri-config.yaml`, `theme.yaml` and `orca.yaml`, so the `dnf` transaction and the `dms setup` inside `niri-config.yaml` still read `ID=fedora` (§5) |
| `niri-config.yaml` | **`script@v2`** | the `RUN` of §4.5 in `snippets:` — multi-command shell, so not `files` (§4.5) |
| `theme.yaml` | **`script@v2`** | the download and `jq` assertion of §4.12 |
| `orca.yaml` | **`script@v2`** | fetch the `stablyai/orca` release through the GitHub API and install the `x86_64` RPM (§4.11) — `releases/latest` piped through `jq -r '.assets[].browser_download_url'`, `grep -E 'x86_64\.rpm$'`, then a `test -n` on the result, so the AppImage and the `aarch64` RPM are never candidates and no version is written in the recipe |

Four of the eight cannot be `files`: two must fetch a URL, two are multi-command shell steps.

- `theme.yaml` and `orca.yaml` are `script@v2` because they **fetch a URL**, and no official BlueBuild module does that — `files` writes paths from the repo and has no way to download anything. `theme.yaml` also runs the `jq` shape assertion, which `files` equally cannot do.
- `flatpak.yaml` and `niri-config.yaml` are `script@v2` for the same reason as each other: ordered shell commands with dependencies between them. The **order inside** matters more than the type — the flatpak marker before a delete would leave the remotes in place behind a "done" file.

Order matters: `dnf` first, since the others install packages; `flatpak` immediately after it, while `/var/lib/flatpak` is still empty and no user session has run; `os-release` **last of the eight**, immediately before `signing`, so that the whole `dnf` transaction and the `dms setup` inside `niri-config.yaml` still see `ID=fedora`; and `signing` last, so the verification policy it installs is layered over an image that already contains everything. `files` must land before `niri-config.yaml`, which is the one module whose content depends on a file another module wrote: without §4.14's `cli-policy.json` the `dms setup` inside it refuses the immutable system.


The `files` module is the one that needs a data tree, and it is **not** the other seven modules' convention. Every entry is written as an explicit `source:`/`destination:` **pair** — never the bare single-key form: with only `source:` present, `modules/files/files.sh` takes the new-format branch with `DEST` expanding to the literal string `"null"` and copies each file to a path named `null`, which still exits 0 — and this is the `{source:}`-without-`{destination:}` case specifically, distinct from the legacy single-key `{key: value}` form, which still works, so the build goes green with an empty image and no criterion sees it. Each source lives under the repository's **top-level `files/` directory**, staged as `COPY ./files /files` and mounted at `/tmp/files`; a missing source aborts with `File or directory … does not exist in /tmp/files`. So a drop-in is committed as `files/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf` and written as:

```yaml
- source: usr/lib/systemd/user/niri.service.d/kinrin-dms.conf
  destination: /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf
```
**Asserted, source not pinned here**: the `files/` staging path and the null-destination behaviour come from the BlueBuild module script and template, which this plan has not read from a named commit — §12.1 has no row for them. Confirm both against the BlueBuild tree you build with before relying on the layout, and pin the commit in `NOTES.md`.
## 6. Publication

- Public GHCR, **two** tags — `latest` and a build-dated one computed at build time (`$(date +%F)`), never a hardcoded date. Two tags means two `skopeo copy` invocations: one copy pushes one tag, so a single copy leaves the date tag missing. The date tag is a **human-readable record of what ran when**, not an install mechanism: with a monthly schedule, `date -d yesterday` equals the build date roughly one day in thirty, and §7 is explicit that the restore path is the digest, not a tag. To roll back, read the date tag of the build you are leaving — record it in `NOTES.md` at build time — and switch by its `@sha256:` digest. Do not tag per Fedora version: the base is not pinned, so a `44` tag would name a version nothing guarantees.
- Three CI jobs, in order:
  1. `validate` — `bluebuild validate recipes/recipe.yaml` (§5). Fails in seconds, runs on every push, and is the gate that keeps a bad recipe out of `build`.
  2. `build` — the bootc build, then `niri validate` inside the built image (§5).
  3. `publish` — the GHCR push, and only from `build`.
- Monthly schedule plus `workflow_dispatch` for on-demand builds. Free on a public repository.
- Install over an existing Atomic Fedora. Two forms, and the choice is deliberate:

  ```bash
  sudo bootc switch ghcr.io/<user>/kinrin:latest && sudo reboot          # discovery
  sudo bootc switch ghcr.io/<user>/kinrin@sha256:<digest> && sudo reboot # reproducible
  ```

  `:latest` is what you want when you do not know the current build and are willing to take
whatever is published — the next monthly run replaces it under you. `@sha256:` is what you want when the install has to be reproducible, because no tag designates a stable image across builds (§7): the digest is the only reference that keeps resolving to the same bits.
- Bare hardware: `bootc install` from a live ISO. No ISO on GitHub.
- GHCR limits: 10 GB per layer, 10-minute upload timeout. If a push fails, look there first. The package must be made public explicitly — GHCR creates it private.
### 6.1 Signature

Three separate things, and this plan has read the source of **none of the three** — what the `signing` module emits, where the key lives, and who signs. Nothing below changes that: the two BlueBuild facts §5 and §5.2 now state (the `cosign.pub` at the repository root, the `files/` staging tree) are **asserted from the module and template sources without a pinned commit**, and are labelled as such where they appear. Neither is safe to assume: `cosign.pub` at the repository root is build-fatal, but the `files/`
  destination trap is the more dangerous of the two because it is **silent** — a `{source:}` entry with no
  `{destination:}` leaves `DEST` the literal string `null`, `cp -f` succeeds and the module exits 0, so the
  build goes green shipping an empty image rather than red. Confirm both against your BlueBuild tree and record the commit in `NOTES.md` before trusting them. Stated as mechanics, not as a verified reading of the module: the module contributes the **verification policy** the image ships, the private key
**never lives in the image** — it is a CI secret — and the signature over the published digest is
produced at **publish** time.

Read the first one out of the built image instead of asserting it:

```yaml
- name: read the signing policy out of the image
  run: podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" sh -c 'ls -l /etc/containers/policy.json /etc/containers/registries.d/ 2>&1'
```

**If that prints nothing, the module emitted nothing: do not claim the image verifies.** An absent
policy is an absence, not a default, and "the image is signed" is a statement about the digest, not about the policy.

The push, in the publish job of §6, is two `skopeo copy` calls — one per tag, `latest` and the date — of the local build output. They carry the image; they do not sign it. The signature is a separate step, and it is the step that turns a pushed digest into a verifiable one.

**That YAML is an excerpt, not a transcribable document.** The `on:`/`jobs:`/`steps:` scaffolding is elided and the two jobs follow one another, so the block deliberately does not parse as one document — assemble it: workflow `on:`, then a `build` and a `publish` job, each with its own `env:`, `if:` and `steps:` list. Everything shown under a job belongs to that job.

**Three things about that block are easy to get wrong. The first two break the job silently; the third fails it outright.** The source
is **`containers-storage:`, not `docker://`** — `docker://localhost/kinrin:latest` is a *registry* reference, so skopeo tries to reach a registry on `localhost:443` and fails with `connection refused` before touching your image. And because each CI job gets a **fresh runner**, the publish job cannot see the image `build` produced: `needs: build` orders the jobs, it does not carry podman storage across, so the image is handed over as an artifact and loaded back.

```yaml
# Both jobs need this at **job** level — a bare workflow-level `if:` is a schema error, and a build/publish: if: github.ref == format('refs/heads/{0}', github.event.repository.default_branch) Workflow level, not job level: the build job's `podman save` below expands $OWNER too.
env:
  OWNER: ${{ github.repository_owner }}
  REPO: ${{ github.repository }}
# build job, after the build and `niri validate`. `generate` needs the flags as much as `build` does: the `signing` module keys its policy from what `generate` passes, and left unset it falls back to the CI driver's registry — so `build` alone would name the image one way and the policy another. The flags also make the tag identical locally and on a runner, and `${OWNER,,}` lowercases them: bluebuild lowercases the name it tags, so an un-lowercased namespace would make it tag one name while the save below looked for another.
- run: bluebuild generate recipes/recipe.yaml -o /tmp/Containerfile --registry ghcr.io --registry-namespace "${OWNER,,}"
- run: bluebuild build -vv recipes/recipe.yaml --registry ghcr.io --registry-namespace "${OWNER,,}"
# `niri validate` is the second CI check the plan claims, so it has to be a real step: a broken `config.kdl` would otherwise leave the build job green and be caught only at criterion 28, by hand.
- run: podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" niri validate --config /etc/niri/config.kdl
# The presence chain of §5, same thirteen in the same order: the only step in this job that looks at a files.yaml path.
- run: podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" sh -c 'test -f /etc/xdg/xdg-desktop-portal/portals.conf && test -f /etc/greetd/config.toml && test -f /etc/systemd/logind.conf.d/kinrin.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/dms.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf && test -f /usr/lib/systemd/user/niri-vrr.service && test -f /etc/environment.d/90-dms.conf && test -f /usr/share/dms/cli-policy.json && test -f /etc/skel/.config/niri/local.kdl && test -f /etc/skel/.config/DankMaterialShell/settings.json'
# `set -o pipefail` is load-bearing: without it the step takes zstd's status, a failed save still produces a valid empty kinrin.tar, and the publish job dies later with a misleading error instead of here.
- run: set -o pipefail && podman save "ghcr.io/${OWNER,,}/kinrin:latest" | zstd -T0 > kinrin.tar
- uses: actions/upload-artifact@v4
  with: { name: kinrin-image, path: kinrin.tar }
# publish job
permissions:
  packages: write        # GHCR push requires this; without it the token cannot write the package
  contents: read
- uses: actions/download-artifact@v4
  with: { name: kinrin-image }
- run: podman load -i kinrin.tar
- name: Log in to GHCR
  run: skopeo login ghcr.io -u "${{ github.actor }}" -p "${{ secrets.GITHUB_TOKEN }}"
- name: Meta
  id: meta
  run: echo "tag=$(date +%F)" >> "$GITHUB_OUTPUT"
- name: Publish
  run: |
    skopeo copy --all "containers-storage:ghcr.io/${OWNER,,}/kinrin:latest" "docker://ghcr.io/${REPO,,}:latest"
    skopeo copy --all "containers-storage:ghcr.io/${OWNER,,}/kinrin:latest" "docker://ghcr.io/${REPO,,}:${{ steps.meta.outputs.tag }}"
- name: Capture digest
  id: digest
  run: echo "digest=$(skopeo inspect --format '{{.Digest}}' "docker://ghcr.io/${REPO,,}:latest")" >> "$GITHUB_OUTPUT"
# The assert the prose promises, as a step: a command substitution that fails does NOT fail its step. `echo "digest=$(false)"` exits 0 and writes `digest=` — verified. Left unchecked the empty value reaches `cosign sign … @` and dies there with a `manifest unknown` that reads like a registry or auth problem.
- run: test -n "${{ steps.digest.outputs.digest }}"
- name: Sign
  env:
    COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
  run: cosign sign --yes --key env://COSIGN_PRIVATE_KEY "ghcr.io/${REPO,,}@${{ steps.digest.outputs.digest }}"
```

A third trap, **distinct from the transport prefix**: skipping `podman load -i kinrin.tar` does not give you an empty digest, it fails `Publish` outright, because there is no local image for `skopeo copy` to read — the digest step is downstream and never reached. The prefix rule is about the two *sides* of the copy; the load step is about the image existing at all, and deleting it as "part of the same rule" breaks the publish. Once past `Publish`, still assert the digest output is non-empty before trusting the sign step.

**Asserted, source not pinned here**: that a runner tags the build `localhost/…` unless `--registry`/`--registry-namespace` are passed, and that `post_build.sh` removes `/var` contents after the modules run, come from the BlueBuild tree this plan has not read at a named commit. Both are cheap to confirm and expensive to get wrong, so confirm them first.

Every published reference is written `ghcr.io/${{ github.repository }}` — never a literal
`ghcr.io/<owner>/kinrin` — so the workflow resolves the owner itself. **Keep the two names in step**: the `signing` module keys the in-image policy from the recipe `name:` and the build's registry, so the policy covers `ghcr.io/<owner>/kinrin` while the push target is `ghcr.io/<owner>/<repo>`. If the repository is not named `kinrin`, boot-time verification of the published reference resolves nothing, and the `bootc switch` lines in §6 and §7 name an image that was never pushed. Either name the repository `kinrin`, or set the recipe `name:` to the repository name — decide once, record it in `NOTES.md`, and assert in **criterion 28b** that the policy's `matchRepository` entry equals the reference actually pushed. The two step outputs are what
the job consumes: `steps.meta.outputs.tag` is `$(date +%F)`, and `steps.digest.outputs.digest` is read back **from the registry after the push**, which is the only digest `cosign sign` can resolve. Capturing it from `containers-storage:` beforehand is the trap: `skopeo copy` rewrites the layers on the way in, so the local manifest digest is not the one the registry serves, and signing that reference fails with `manifest unknown`. `--preserve-digests` is not an escape — it errors out with `Copying this image would require changing layer representation`. The served digest is stable across both tags.

`COSIGN_PRIVATE_KEY` is the CI secret holding the cosign private key, and it reaches the binary through `--key env://COSIGN_PRIVATE_KEY` — an `env:` entry on the step is **not** read on its own, so without that flag cosign falls back to keyless and fails. If the generated key is passphrase-protected, set `COSIGN_PASSWORD` on the same step, or the run blocks on a prompt that never comes. and it is the answer to the
"which key signs" row of §10. It is an environment variable of the signing step, never a file in the repository and never a layer of the image.

Verify the pushed digest afterwards, never a tag: a tag designates nothing stable across builds (§7). `cosign verify` against the pinned digest, with the **public** key published alongside the image — the public half must be published beside the image, because it is what verification checks and what the target machine needs at boot. Boot-time enrollment is host-side and out of the image — follow whatever bootc and ostree do by default, and do not invent a procedure (§11).

**§4.12 and criterion 12b agree, and a review once claimed they did not**: the shipped `dms-greeter` symlinks the three root files (`installer.go:1384`, `:1437`) and *adds* per-user slots, and both sections now say so. The claim that `sync` *copies* the root files came from the shipped README's loose wording ("copies your DankMaterialShell theme") and does not survive the code or the binary; if a build ever shows the two sections disagreeing again, the plan's own text is what is wrong — do not paper over it in a workaround.

Keep the deployment layer-free before switching: on a deployment with a layer, layered packages disappear without a message and `bootc upgrade` refuses outright (§2).

---
## 7. Rollback

```bash
bootc status                    # active and staged deployments
bootc rollback                  # swap the bootloader order back
bootc rollback --apply          # UNVERIFIED — confirm with `bootc rollback --help` in the image first
```

`--apply` is listed as unverified on purpose: this plan has not run it, and this section is a
procedure someone runs while a display is broken. Check `bootc rollback --help` in the built image before relying on it, and use the plain form above until then.

Rollback alone is not enough. While `bootc-fetch-apply-updates.timer` is active, the man page warns that the rollback may be reverted at the next reboot. Disable it:

```bash
sudo systemctl disable --now bootc-fetch-apply-updates.timer
```

Freeze a restore point; `bootc upgrade` is then a no-op:

```bash
bootc switch ghcr.io/<user>/kinrin@sha256:<digest>
```

`/etc` in a bootc deployment is **persistent and three-way merged**, not overwritten: a rollback
restores the previous deployment's `/etc`, and a `bootc switch` *retains* files you hand-edited in
`/etc` (bootc docs: "locally modified files in /etc different from the default /usr/etc will be
retained"). So a local edit survives but goes stale, and a package upgrade will not overwrite it. The consequence is the same and is why the plan already does it everywhere: never edit a shipped file, add a drop-in beside it — `/etc/systemd/logind.conf.d/`, `/etc/xdg/xdg-desktop-portal/`. Machine-local configuration therefore belongs in `/var`, or in
`/etc/skel` seeded by the first-user path of §10 — **not** by sysusers, which creates a home without
copying `/etc/skel` and would therefore apply none of the niri config or the theme.

Rollback keeps the previous deployment, so two images must coexist. Budget 10 GB of free space for the OSTree partition: if it cannot hold two full deployments, `bootc switch` revokes the old one and this section silently stops being true. Measure the built image with `podman images`, then `bootc status -v` after the first install. Criterion 33.

The freeze is a digest, not a tag — no tag designates a stable image across builds. Record the digest at deployment time:

```bash
bootc status -v | grep -i digest  # capital D in both output forms; -v also forces YAML, not the human view
```

---
## 8. Validation criteria

A human checklist, run by hand on a real machine. The monthly CI runs none of it: no GPU, no graphical session, no gamepad, no game to buy. `bluebuild validate`, `niri validate` **and the presence chain over the `files.yaml` destinations** (criterion 28) **and the §6.1 policy read** (criterion 28b) are the only automated checks on the image (§5, §6.1).

- [ ] 1. niri starts
- [ ] 2. DMS starts with niri: bar, launcher, controller, notifications
- [ ] 2b. DMS shortcuts work: `Mod+Space`, `Mod+N`, `Mod+Alt+L`
- [ ] 2c. Default state — no remote pre-activated: `flatpak remotes --system` is empty, and `readlink /etc/systemd/system/flatpak-add-fedora-repos.service` is `/dev/null` — the mask is the mechanism that survives into the image, since `/etc` is versioned with the deployment. If the marker file `/var/lib/flatpak/.fedora-initialized` is also there, that is a bonus, not the check: BlueBuild's `post_build.sh` may clear `/var` after the modules run (§3.2). Discover still opens
- [ ] 2d. **DMS starts exactly once under niri**, and not at all under Plasma:
      `systemctl --user list-dependencies niri.service` shows `dms.service`,
      `graphical-session.target` is `active` in the niri session, the generated
      `config.kdl` holds no `spawn-at-startup "dms"` autostart — niri spells it that way, not
      `dms run` — and logging into Plasma starts no DMS (§4.8). Both units are asserted at build
      time by the §4.5 `RUN` (`rpm -ql niri`, `rpm -ql dms`); without those assertions a missing
      `niri.service` makes the drop-in inert and this check passes vacuously, so re-derive it
      against the `niri-session` wrapper if the assertions were dropped
- [ ] 3. KDE portal selected — `busctl --user list | grep org.freedesktop.impl.portal.desktop` shows `…desktop.kde`; then Spectacle capture, screen sharing, file picker, and Discord in-call screen share (§4.10)
- [ ] 4. Polkit: each action triggers exactly one prompt, never two, **and the prompt can actually be answered** — run the USB key action and the NetworkManager action separately, count the prompts in each case, and authenticate at each one. Counting alone is not a pass: a user outside `wheel` still gets exactly one prompt per action, and the count would look right while the authentication failed. So this criterion tests satisfiability, which is why §4.3 requires the account in `wheel`. One prompt for the pair is also not a pass (§4.3, §10)
- [ ] 5. `rpm -q dolphin konsole kate plasma-discover` all resolve — three of the four ship in the base, `kate` is the only genuine addition, and its presence is what proves §4.0 installed it (§4.0) — then each app is present and usable. Do not check the theme: `QT_QPA_PLATFORMTHEME=gtk3` forces gtk3 (§4.7)
- [ ] 6. Plasma still starts and works
- [ ] 7. PipeWire audio: playback and microphone
- [ ] 8. Suspend and resume
- [ ] 8b. Closing the laptop suspends. `plasma-workspace` pulls `powerdevil`, which wants to own lid and power events, so record which of the two wins: `HandleLidSwitch=suspend` is already in `/etc/systemd/logind.conf.d/kinrin.conf` (§4.0), so this criterion only **observes** — confirm the value is in the drop-in and that PowerDevil's own setting did not override it. Do not edit `/etc/systemd/logind.conf` to make this pass; §7 forbids it and the drop-in is what the image ships
- [ ] 9. An X11-only app starts, which also tests `xwayland-satellite` (§1)
- [ ] 10. niri CPU at idle: leave the session untouched for 5 minutes, then sample the compositor for 60 s — `top -b -d 1 -n 60 -p "$(pgrep -x niri)"`. Expect under 2 % of one core averaged over those 60 samples, with no window open. The 5-minute settle and the 60-sample average are the method; a single `top` reading taken right after login is not a measurement
- [ ] 11. `dms-greeter` displays and lets you log in
- [ ] 12. **After 12b's `dms-greeter sync`**, the greeter shows the DMS theme colours from the same
theme file: Dracula, not a second hand-picked theme (§4.12). No wallpaper claim — none ships. This is a continuation of 12b, not an independent test: the greeter renders its own default theme until
  `dms-greeter sync` has run, so on a freshly installed image this criterion **fails by design**.
Check it last, and do not "fix" it by editing a theme file
- [ ] 12b. The greeter theme, which is **symlinked into the greeter cache, never generated locally**. `dms-greeter sync` reaches `SyncDMSConfigs`, which links three files from the session user's home into `/var/cache/dms-greeter/`: `settings.json` from `~/.config/DankMaterialShell/settings.json` and `session.json` from `~/.local/state/DankMaterialShell/session.json` (`core/internal/greeter/installer.go:1404-1425`, the `ln -sf` at `:1437`), plus `colors.json` from `~/.cache/DankMaterialShell/dms-colors.json`, that source being `GreeterColorsSource` (`installer.go:1355-1356`, linked at `:1384`). A source that does not exist is created empty first — `os.WriteFile(link.source, []byte("{}"), 0o644)` at `:1430` — so a fresh home yields three symlinks onto three `{}` files rather than an error. The same function then **adds** a per-user layer: `users/<username>/` slot entries, symlinked by `linkSlotEntry` (`user_cache_sync.go:326`) and falling back to a snapshot copy, so the slots are additional to the three root links, not a replacement for them. Check: after the first login, the session user must be in the `greeter` group — `sync` tests for it, adds it itself when non-interactive, or prompts `"Would you like to add your user to the greeter group? (Y/n)"` and runs `usermod -aG greeter <user>` on confirmation, bailing with "aborted: user must be in the greeter group before syncing" if declined (`core/cmd/dms-greeter/greeter_sync.go:195-220`), and a logout/login is needed before it takes effect — so pre-add with `usermod -aG greeter <user>` before syncing, which is the non-interactive path. This is unrelated to §4.1's "add no group", which is about DRM access. Then run `dms-greeter sync` **as the session user** (it self-elevates internally; the cache is `chmod 2770`, `installer.go:889`, so no outer `sudo` is needed), and `ls -l /var/cache/dms-greeter/` must show all three as symlinks into that home. This needs the first user, so it cannot run in CI.
  **The shipped README's "copies" is loose wording, not the mechanism** — the code and the binary both link the three root files (`failed to create symlink for %s`, "…are linked to the greeter and stay in sync"), and the `setfacl` grant over the user's home only makes sense behind symlinks. The README's "Manual method" section documents the same root-symlink layout by hand.
- [ ] 13. The greeter is **expected** to list niri. Record whether it also offers Plasma; either way the guaranteed path is `Ctrl+Alt+F3` then `startplasma-wayland` (§1)
- [ ] 14. AMD: nothing to install; **each AMD GPU present** is on `amdgpu` — a single-GPU AMD machine satisfies this, the wording is not tied to a second adapter — and `vainfo` reports a working VA-API profile (§4.0)
- [ ] 15. Intel: `libva-intel-media-driver` shipped, `vainfo` confirms it on the target GPU (§4.0)
- [ ] 16. The greeter displays with no extra group: `getent group input` does not contain `greeter`; a black screen is read in `journalctl -u greetd`, not fixed with rights (§4.1)
- [ ] 17. Change the DMS theme — the niri colours follow live, which only happens if `~/.config/niri/config.kdl` exists so the include resolves into the home (§4.5)
- [ ] 18. Secure Boot, only if used; it tests the base (§3.3)
- [ ] 19. `steam` opens as an RPM, present without manual installation, and the window is not black
- [ ] 20. A Proton game starts, Steam having downloaded Proton itself. Check cursor and fullscreen; `gamescope` is not shipped by default, so this is the un-wrapped path (§4.9)
- [ ] 21. VRR: the game triggers the `steam_app_*` rule from `local.kdl` and the frame rate actually varies (§4.9)
- [ ] 22. Plugging in a gamepad does not crash Steam; then `getfacl /dev/uinput` shows the logind ACL on the session user, who is not in `input` (§4.9). **If it does crash, that is the host-side `extest` trigger of §4.9, not an image defect** — §10 and §11 leave whether the preload is ever needed open, and criterion 22 is what settles it: apply the preload host-side, re-run, and only then file the result
- [ ] 23. `/etc/skel/.config/niri/dms/binds.kdl` still carries DMS's default keybinds **and** the prepended `include optional=true "../local.kdl"`; `/etc/skel/.config/niri/local.kdl` carries the window rules. Both are seeded at first login, niri accepts the chain, and `Mod+Space` still opens the launcher — a `binds.kdl` holding only the include suppresses every default bind (§4.4)
- [ ] 24. `dnf repolist` shows `rpmfusion-free` and `rpmfusion-nonfree`, **and** `dnf repoinfo rpmfusion-free` prints an `OpenPGP` `Keys` line naming a `RPM-GPG-KEY-rpmfusion-free` file and `Verify packages : true` — assert on those two lines, not on `GPG check : enabled`, which dnf5 (5.4.5, the Fedora 44 `dnf`) never prints; and note `dnf repoinfo <unknown-id>` prints `No matches found.` and still **exits 0**, so a typo in the repo id cannot fail this criterion on its own
- [ ] 25. `discord` starts and its in-call screen sharing goes through the portal (§4.10)
- [ ] 26. `/etc/environment.d/90-dms.conf` is valid `KEY=VALUE` and `systemd-environment-d-generator` accepts it, and the three variables are set in the `niri.service` and `dms.service` drop-ins **only** — no `environment.d` file carries them, and nothing the Plasma session inherits does either. A Plasma session started from a TTY inherits none, while an app launched from DMS inherits all three. `XDG_CURRENT_DESKTOP` is in **both** drop-ins, not only the niri one, for the same reason as the theme variables: `dms.service` is a separate unit, and an `Environment=` on `niri.service` never reaches it. The other known source is the `environment {}` block of the §4.5 `config.kdl`, a KDL mechanism scoped to what niri spawns and not a unit environment (§4.7). Both `niri.service` and `dms.service` are asserted to exist at build time in §4.5, so an inert drop-in cannot pass this
- [ ] 27. `rpm -q xwayland-satellite` resolves **and** an X11 app really starts under it. `steam` is not that test — the RPM is 64-bit, only its dependencies are 32-bit — so use criterion 9 for the X11 smoke test and this one for the package (§1, §4.0)
- [ ] 28. `niri validate --config /etc/niri/config.kdl` passes **inside the built image** — a bare call on the host is not a gate, the binary is absent from a CI runner and it would not see the image — and `bluebuild validate` passes on the recipe — and the presence chain over the `files.yaml` destinations passes inside the same image
- [ ] 28b. The signing policy covers the reference actually published: inside the image, `jq -r '.transports.docker | keys[]' /etc/containers/policy.json` prints `ghcr.io/<owner>/<repo>` — the same reference the publish job pushed, lowercased. A mismatch means the `signing` module keyed the policy from a different name than the one pushed, so boot-time verification of the published image resolves nothing (§6.1)
- [ ] 29. orca starts under niri, opens a worktree and renders its integrated terminal; its RPM dependencies resolve in the image, and it coexists with `dms-greeter` — it is an Electron app, so GTK/sandbox depending on version (§4.11). `opencode` is not part of this criterion: answering needs a model provider, credentials and network, none of which the image supplies
- [ ] 30. After a theme change and then `dms setup headless --compositor niri --skip-existing`: `~/.config/niri/dms/binds.kdl` still holds `include optional=true "../local.kdl"`, still holds `Mod+Space`, and `local.kdl`'s rules still apply (§4.4)
- [ ] 31. VRR is applied by the IPC unit, not a config file: `niri msg outputs` shows `Variable refresh rate: supported, enabled` after login, on **every** output, and `niri-vrr.service` was **started by the `niri.service` drop-in** — it is not enabled anywhere, and a Plasma session never starts it (§4.4). The **on-demand half is not observable**: the IPC `Output` struct carries only `vrr_supported` / `vrr_enabled` (`niri-ipc/src/lib.rs:1229-1232`) and the human output prints no `on-demand` (`src/ipc/client.rs:645-651`), so cover it with the per-window `variable-refresh-rate true` rule in `local.kdl` and criterion 21's observed frame-rate variation
- [ ] 32. Opt-in path — the §3.2 one-liner adds Flathub, it appears, then removing it leaves the system clean again
- [ ] 33. The built image fits twice on the OSTree partition: two deployments coexist, so §7 is real
- [ ] 34. At first login, with nothing touched, DMS is in Dracula Dark; the theme is listed in **Settings → Theme**; flipping DMS day/night gives Alucard Light (§4.12). The file behind it passes the build-time shape check first — `jq -e 'has("dark") and has("light") and (.dark.surfaceContainerLowest | type == "string") and (.light.surfaceContainerLowest | type == "string")' /usr/share/dms-themes/dracula/theme.json` — so a wrong copy of the theme cannot reach this point silently
- [ ] 35. `~/.config/niri/dms/colors.kdl` and `~/.local/share/color-schemes/DankMatugen*.colors` exist and are rewritten on a theme change, and the Plasma fallback shows the same colours (§4.12)

---
## 9. Monitoring

A monthly job checks whether `dms` and `dms-greeter` — by name, individually — have landed in the Fedora repos. `DankMaterialShell` and `danksearch` are **already in Fedora**; `dms`,
`dms-cli` and `dms-greeter` are not, so the COPR still earns its place. Match on the COPR package
names, never on "DMS arrived", or the job opens a migration issue that breaks the build. The shell carries **two** names — the COPR's `dms` and Fedora's `DankMaterialShell` — and the check has to test both: matching on `DankMaterialShell` alone is already true today, and matching on `dms` alone misses a rename. Landed means the COPR name is gone, not that a DMS package exists in Fedora.

If they have landed, open an issue carrying the migration steps: drop the COPR from §4.0, drop the
`copr` key from `recipes/modules/dnf.yaml` — not from `recipe.yaml`, which only lists modules —
**and rename `dms` to `DankMaterialShell` in that same `install:` list**, because that is the name
Fedora carries; dropping the key without the rename leaves the `dnf` module requesting a package no enabled repo provides. Re-run §8 afterwards. Write the job before enabling it; until the file exists it has nothing to open.

A broken COPR turns the monthly build red and leaves the published image healthy. The risk is not the outage, it is not seeing it.

---
## 10. Open decisions

| Decision | When |
|---|---|
| **First-user creation path.** Nothing creates the session account: the base ships `plasmalogin` enabled, §3 disables it, and no first-boot session setup runs; the skel is the only way `config.kdl`, `binds.kdl`, `local.kdl`, `settings.json` and the theme reach a home. Criteria 2c, 4, 12b, 17, 23, 30 and 35 all need it — criterion 4 since it authenticates at each prompt, not merely counting them. Choose sysusers plus a first-boot service, or the greeter's own path, and record it in `NOTES.md` (§4.5, §7). The greeter must not offer `builder`. **The account must land in `wheel`**, because that is polkit's `auth_admin` identity (§4.3) and no first-boot path runs to grant it; `greeter` is a separate group, added by `dms-greeter sync` (§12b) | before first login |
| **greetd config ownership.** `/etc/greetd/config.toml` is **package-owned** — the greetd RPM ships it and `dms-greeter`'s `%post` writes it — and the exact rpm flag is unconfirmed offline, so no claim is made here about `%config`/`%noreplace`. What is verified is the writer's idempotence: the `%post` creates the file only when absent (`dms-greeter.spec:198`) and otherwise updates one that does not already mention `dms-greeter` (`:211`, backup at `:212-213`). greetd reads no drop-in directory, so the `files` module necessarily writes that same file — the single exception to §7's "never edit a shipped file" — and it is the last writer (`files.yaml` runs after `dnf.yaml`), so a rebuild is deterministic (§4.1, §7) | before the first build |
| License — the image bundles GPL-2.0 (Fedora), GPL-3.0-or-later (niri), MIT (DMS) and the dracula `theme.json`, which the source repository declares **no licence for** (§4.13) and which therefore cannot be counted as MIT. `GPL-2.0-only` is **not** a valid umbrella: it cannot cover niri's `GPL-3.0-or-later`. Either pick a licence that covers the whole set or publish per-component notices, listing the theme file on its own line as unlicensed, which is the only dracula-derived artefact (§4.13) — no dracula repository directory is installed, so there is nothing to enumerate | before publication |
| **Which key signs.** §6.1 gives the mechanics and the plan has read the source of none of them; the name agreed here is the CI secret **`COSIGN_PRIVATE_KEY`**, read as an environment variable by the `cosign sign` step of the publish job. Generating the key pair is a prerequisite of the first publication, not a build step, and the public half must be published beside the image | before first publication |
| **`ID=kinrin` in `os-release`** — §5 sets it, with `ID_LIKE: fedora` beside it in the same `properties:` map, and §11 records what is still unmeasured: no §8 criterion observes the file, the only check on it is the post-build grep at §5, and `--releasever` resolution for third-party repos and the rpm-ostree upgrade path were never run against the renamed image. The declaration of the parent is the mitigation that is available at build time; the residue is what the first upgrade cycle has to settle. Decide before the first upgrade cycle, do not change it in passing | before the first upgrade cycle |
| `libva-intel-media-driver` confirmed on the target Intel GPU | criterion 15 |
| Whether the `extest` preload is ever needed | criterion 22 |

---
## 11. Risks

| Risk | Response |
|---|---|
| `portals.conf` forgotten — no screenshot, no file picker, no Discord screen share | §4.2, criterion 3 |
| The base drifts (`latest` not pinned) | §8 is the safeguard, not this document |
| `dms` refuses root | §4.5 |
| Bare `include` to an absent file — niri does not start | `include optional=true`, §4.6 |
| `dms-greeter` breaks boot — login impossible | Keyboard accessible, rollback §7 |
| GHCR push over 10 min | Clean the build, §5.1 |
| COPR moved to Pulp — repo fetch 404 on the first build | Pin the version-parameterised `/coprs/<owner>/<proj>/repo/fedora-<N>/….repo`, `<N>` from the base, §4.0 |
| `dms-greeter` does not list Plasma | TTY fallback, §1 |
| Two AMD GPUs, the wrong one may drive the session | Criterion 14 |
| `rpmfusion-nonfree` breaks or is renamed — Steam not installable | Criterion 24, §4.0 |
| `steam` pulls 1 GiB, measured in isolation from a minimal base | `dnf clean all` after install, §5.1 |
| A game lets the cursor escape — playability broken in multi-monitor | `gamescope` on demand, §4.9 |
| A Steam crash when a gamepad connects — dead client, lost session | Criterion 22 settles it; remedy is the `extest` preload, not shipped |
| The gamepad does not drive the desktop under niri | No effect inside games |
| The cosign chain is enrolled nowhere — image not verifiable at first boot | Follow upstream, §6.1 |
| The gtk3 theme variables would leak into Plasma — the fallback inherits them | Per-unit drop-ins only; no `environment.d` entry carries them, §4.7 |
| The Steam and VRR rules die on a theme change, not only on `dms setup` — the shell rewrites `alttab.kdl` when its content changed | Prepend `include optional=true "../local.kdl"` to `binds.kdl`, §4.4, criterion 30 |
| GHCR purges old manifests — a recorded digest stops resolving | Re-push the digest you depend on from a local `kinrin.tar` before it ages out, and record the digest in the incident ticket (§7). The date tag is a record of what ran when, not a second copy (§6) |
| DMS regenerates the niri config on a cadence nobody controls | Criterion 28 validates the shipped file only |
| The skel `config.kdl` is missing — includes resolve into `/etc/niri/` and matugen is invisible to niri | Copy `config.kdl` into the skel, §4.5, criterion 17 |
| The dracula theme copy drifts and loses colour keys | Take the registry copy, branch `master`, not the app repo, §4.12 |
| `configVersion` omitted from `settings.json` — the whole migration chain runs over the file at first start | Set it explicitly, from a dated reading re-checked before each build; §4.12 records how to re-read it when the DMS release moves |
| A dracula repository turns out to carry a different licence than the root | Nothing from the dracula organisation ships; the only dracula-derived file is the registry `theme.json`, whose repository declares no LICENSE at all, §4.13 |
| Weak deps off in the `dnf` module — `matugen` and `danksearch` are both `Recommends:` (`dms.spec:27,28`), and `matugen` absent means the whole of §4.12 dies silently at first login, with no error and a fallback theme nobody chose | Leave weak deps at their default and set nothing; the key, if ever needed, is `install-weak-deps` inside `install:`, §4.0 |
| The base is Kinoite/KDE, so §1's KDE apps mostly exist already and only `kate` is a real addition | `dolphin`, `konsole`, `kate`, `plasma-discover` declared explicitly, criterion 5 |
| A minimal seeded `binds.kdl` suppresses every DMS default bind, because the deployer skips non-empty files | Prepend the include to the generated file, §4.4 (command in §4.5), criterion 23 |
| `Environment=` on one unit does not reach a unit it `Wants=` — a `niri.service` drop-in alone never themes DMS's apps | Two drop-ins, `niri.service` and `dms.service`, §4.7 |
| `plasma-workspace` pulls `powerdevil`, which contests the lid with logind | Decide explicitly in the `/etc/systemd/logind.conf.d/kinrin.conf` drop-in — never the shipped `logind.conf` (§4.0, §7), criterion 8b |
| The `flatpak` `%post` *may* have added the `fedora` remote during the build — it only enables the unit, and a unit enabled in a container build does not run, so nothing observes it; the marker only blocks future adds | `flatpak remote-delete --system` in `flatpak.yaml`'s `snippets:`, §3.2 — there is no `postprocess` key |
| `niri validate` run on the host instead of in the image, proving nothing | `podman run --rm <image> niri validate …`, §5, criterion 28 |
| `bluebuild validate` gated after the build, so a bad recipe burns a 20-minute bootc build | Pre-build job, §5 |
| `dms greeter uninstall` is blocked by the embedded `assets/cli-policy.default.json` alone: the in-code list at `immutable_policy.go:217` omits it, and an unmarshal failure sets an error instead of keeping that list (`:222-225`), so an entry dropped from the JSON would unblock it silently | Ship `/usr/share/dms/cli-policy.json` with `blocked_commands: []` (§4.14) so no upstream list applies to the build, and do not re-derive the defaults from the Go literal, §4.14 |
| `/etc/greetd/config.toml` is a **package-owned** file — the greetd RPM ships it, and the exact rpm flag is unconfirmed offline — and greetd reads no drop-in, so §7's "add a drop-in beside it" is impossible here: the image has to overwrite the file itself | Accepted as the one exception; `files.yaml` writes the `%post` template's content and, running after `dnf.yaml`, is the last writer, so determinism rests on the verified `%post` idempotence (`:198`, `:211`, `:212-213`) rather than on an rpm flag, §4.1, §10 |
| `ID=kinrin` in `os-release` affects `--releasever` resolution and the upgrade path | Declare `ID_LIKE: fedora` in the same `properties:` map, so the parent is still named, and run the module **last of the eight** so nothing in the build sees the new `ID`; the residue is unmeasured and belongs to §10 |

---
## 12. References

- bootc: <https://bootc.dev/bootc/> · <https://bootc.dev/bootc/man/bootc-rollback.8.html>
- Portal: <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.desktop>
- ProtonUp-Qt: <https://flathub.org/apps/net.davidotek.pupgui2>
- niri: <https://github.com/niri-wm/niri/wiki/Getting-Started> · <https://github.com/niri-wm/niri/wiki/Application-Issues>
- DMS config behaviour: `AvengeMedia/DankMaterialShell`, `core/internal/config/deployer.go`
### 12.1 File-level citations

Rule 2 pins the *build*, not the evidence: a build follows `:latest`, while a `file:line` citation has to name the tree it was read from, or the line numbers are unverifiable. Citations to the DMS and niri trees therefore name their repository and path, and their commit is to be filled in here from a local clone at the moment it is re-checked — re-check them, do not trust the number carried over from an older read. The two niri rows below are pinned to `1f03391` (2026-09-25, read with `git log -1` in the local clone, whose `.git` is present, so the commit is re-derivable rather than remembered):
`lib.rs:301` is the `match` arm dispatching on the node kind, `:374` and `:488` are the
`path.parent()` base, `:428` the `optional include not found` warning, `cli.rs:51` the `Validate`
arm. **The DMS and greeter trees are git-less archives** — no `.git`, so no commit can be read out of them; re-clone to fill their commits. The greeter tree is the exception on top of that: the citations to
`dms-greeter.spec`, `greeter_install.go` and `installer.go` have no table row of their own, because
their repository is a **candidate** and not a recorded identity — `dms-greeter.spec:16` carries
`URL: https://github.com/AvengeMedia/dank-greeter`, attributed to that field, which is a declaration
inside a spec rather than a verified repository identity. No commit can be filled in against those paths until someone confirms the repository.

| Citation | Repository | Path |
|---|---|---|
| include resolution | `niri-wm/niri` @ `1f03391` (2026-09-25) | `niri-config/src/lib.rs:374`, entry point `:488` |
| the `--config` flag on `validate` | `niri-wm/niri` @ `1f03391` (2026-09-25) | `src/cli.rs:51-58` |
| theme mode selection | `AvengeMedia/DankMaterialShell` | `quickshell/Common/Theme.qml:1895-1896` (`dark`/`light` fall back to each other) |
| `DMS_DISABLE_MATUGEN` | `AvengeMedia/DankMaterialShell` | `quickshell/Common/Theme.qml:24` |
| matugen toggles | `AvengeMedia/DankMaterialShell` | `quickshell/Common/settings/SettingsSpec.js:940` (`Gtk`), `:943` (`Niri`), `:952`/`:955` (`Qt5ct`/`Qt6ct`), `:1003` (`Kcolorscheme`), `:994` (`Neovim`, the one `def: false`) |
| `settingsConfigVersion`, the authority for the skel `configVersion` | `AvengeMedia/DankMaterialShell` | `quickshell/Common/SettingsData.qml:24` |
| the migration chain assigns `31` then `33` | `AvengeMedia/DankMaterialShell` | `quickshell/Common/settings/SettingsStore.js:700` (`configVersion = 31`), `:706` (`configVersion = 33`) |
| `add-wants niri.service dms` | `AvengeMedia/DankMaterialShell` | `core/internal/distros/base.go:574` |
| headless terminal defaults to ghostty; `--terminal` accepts three others | `AvengeMedia/DankMaterialShell` | `core/cmd/dms/commands_setup_headless.go:128-131`, `:29,132-139` (the `unknown terminal` error is `:139`) |
| `terminalCommand = "ghostty"` substitution | `AvengeMedia/DankMaterialShell` | `core/internal/config/deployer.go:224-225` (`case deps.TerminalGhostty:` and its assignment; the `default:` arm at `:231` holds the same value) |
| the shipped `Mod+T` terminal bind | `AvengeMedia/DankMaterialShell` | `core/internal/config/embedded/niri-binds.kdl:8` |
| `XDG_CURRENT_DESKTOP` in the generated niri config | `AvengeMedia/DankMaterialShell` | `core/internal/config/embedded/niri.kdl:137-139` |
| **Browse Themes** is remote-only | `AvengeMedia/DankMaterialShell` | `quickshell/Modules/Settings/ThemeBrowser.qml:202` — `refreshThemes` fills `allThemes` from `listThemes()` alone (`:205-213`); `listInstalledThemes()` (`:216-222`) is ignored on success |

Six of the eleven DMS rows are under `quickshell/`, five under `core/` — the config-deployer half of the tree — and the remaining two rows are `niri-wm/niri`. Note what the `ThemeBrowser.qml` row does **not** rest on: `listInstalledThemes()` is called, and it is still not a second source, because `refreshThemes` discards its result on the success path. "Remote-only" is established by the fill at `:205-213`, not by the mere presence of the call.

No commit is recorded yet for any of the eleven DMS rows, and this table is a **subset** of the plan's citations: the §4.4 `NiriService.qml` rewrite list, §4.14's `immutable_policy.go` and criterion 31's `niri-ipc/src/lib.rs` all carry line numbers with no row here yet, so treat the table as the re-clone checklist rather than the full set. That is a real gap rather than a licence: DMS ships from a branch, so these line numbers drift, and a citation that moved under this plan is worse than no citation. The trees read for them are git-less archives, so a commit cannot be recovered from what is on disk; re-clone to fill it in when you re-check.

The three-layer model of §4.5 — `/usr` from the image, `/etc` from the deployment, `/var` local — has a consequence worth writing down, because it decides where a config file may live: `/etc` travels with the deployment, so `bootc switch` and `bootc rollback` both move it (§7). Anything machine-local goes to `/var`, or into `/etc/skel` seeded by the first-user path of §10 — **not** by sysusers, which creates a home without copying the skel (§7).
