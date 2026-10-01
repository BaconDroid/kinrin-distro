# KinRin

Fedora Kinoite with **Niri** as the compositor and **DankMaterialShell** as the
desktop shell. Plasma is kept as a manual fallback session, so a Niri regression
can never leave you with no way to log in.

```
greetd ──▶ dms-greeter
   │
   ├──▶ niri ──▶ DMS : bar, notifications, launcher, controller, polkit, lock screen
   │         └──▶ apps KDE (Dolphin, Konsole, Kate, Discover)
   │
   └──▶ Plasma ──▶ kwin + plasmashell          (manual fallback)
```

- AMD and Intel GPUs, in-kernel drivers only. No NVIDIA, no kernel module signing.
- Everything is RPM. No Flatpak application is installed and no remote is enabled.
- The image is authored with [BlueBuild](https://blue-build.org) and built with
  **bootc**; rpm-ostree is the deployment system.
- **No layering.** The image is rebuilt, never patched.

## What is in the box

| | |
|---|---|
| Session | `niri` + `dms-greeter` login screen |
| Theming | Dracula (dark) and Alucard (light) in one `theme.json`, applied through DMS and propagated by matugen; Breeze stays underneath as the fallback for anything a colour scheme does not reach |
| Apps | Dolphin, Konsole, Kate, Discover |
| Games | `steam` + `steam-devices` from RPM Fusion; on-demand VRR for `steam_app_*` windows |
| Chat | `discord` from RPM Fusion, screen sharing through the KDE portal |
| Dev | Node, Go, Rust, Python, C/C++, podman, ripgrep, fish, zsh |
| Editor | orca, installed from its GitHub release RPM |
| Flatpak | the `flatpak` package is present (Discover needs its backend) but no remote is enabled |

## Install

Over an existing Atomic Fedora — two forms, and the choice is deliberate:

```bash
sudo bootc switch ghcr.io/bacondroid/kinrin:latest && sudo reboot          # discovery
sudo bootc switch ghcr.io/bacondroid/kinrin@sha256:<digest> && sudo reboot # reproducible
```

`:latest` is what you want when you do not know the current build and are
willing to take whatever is published — the next monthly run replaces it under
you. `@sha256:` is what you want when the install has to be reproducible: no tag
designates a stable image across builds, so the digest is the only reference
that keeps resolving to the same bits.

Bare hardware: `bootc install` from a live ISO. There is no ISO on GitHub.

Keep the deployment layer-free before switching: on a deployment with a layer,
layered packages disappear without a message and `bootc upgrade` refuses
outright.

### Your first user

The base ships a display manager enabled, and the recipe disables it in favour
of greetd, so no first-boot session-setup path runs and the image creates no
account. Create your user from the greeter's own user-creation screen at first
login, then:

```bash
sudo usermod -aG wheel "$USER"    # polkit's auth_admin identity
sudo usermod -aG greeter "$USER"  # what `dms-greeter sync` checks for
```

`wheel` is not optional: polkit's default rule for administrative authorisation
is literally `return ["unix-group:wheel"]`, and the USB and NetworkManager
actions you will meet on first login are `auth_admin`. A session user outside
`wheel` gets a prompt it cannot answer.

`greeter` is a separate group and unrelated to DRM access — the greeter reaches
the GPU through the logind ACL, and `/dev/dri/renderD*` is world-accessible by
udev. It is only needed for the greeter theme sync below.

### The greeter theme

Criterion 12 of `TESTING.md` **fails by design on a fresh image**, and that is
correct. The greeter renders its own default theme until `dms-greeter sync` has
run, and that sync needs a first login. Do not "fix" it by editing a theme file
— that proves nothing about the greeter and leaves the shipped theme wrong.

Once logged in:

```bash
dms-greeter sync     # as the session user; it self-elevates, no sudo needed
ls -l /var/cache/dms-greeter/   # settings.json, session.json, colors.json — symlinks into your home
```

The three files are **symlinked**, not copied, so they stay in sync with the
session user's home. A logout/login is needed after joining the `greeter` group.

### Flatpak, if you want it

Nothing is enabled by default. To add Flathub yourself:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

Discover opens on demand; no system remote is ever added.

## Roll back

```bash
bootc status                    # active and staged deployments
bootc rollback                  # swap the bootloader order back
bootc rollback --apply          # UNVERIFIED — check `bootc rollback --help` first
```

Rollback alone is not enough. While `bootc-fetch-apply-updates.timer` is active,
the man page warns the rollback may be reverted at the next reboot, so disable
it first:

```bash
sudo systemctl disable --now bootc-fetch-apply-updates.timer
```

To freeze a restore point — `bootc upgrade` is then a no-op — switch by digest:

```bash
bootc switch ghcr.io/bacondroid/kinrin@sha256:<digest>
bootc status -v | grep -i digest # record it; capital D in both output forms
```

Rollback keeps the previous deployment, so two images must coexist: budget
**10 GB** of free space on the OSTree partition. If it cannot hold two full
deployments, `bootc switch` revokes the old one and rollback silently stops
being possible. Measure the image with `podman images`, then `bootc status -v`
after the first install.

## Publication (PLAN §6)

Two tags are pushed to GHCR, and both are real:

| Tag | What it is |
|---|---|
| `latest` | whatever the last successful run published |
| `YYYY-MM-DD` | a human-readable record of **what ran when** — computed in the publish job by `date +%F`, never hardcoded |

The date tag is a record, not an install mechanism: with a monthly schedule
`date -d yesterday` equals the build date roughly one day in thirty. To roll
back, read the date tag of the build you are leaving and switch by its
`sha256:` digest.

There is deliberately **no** Fedora-version tag: the base follows `:latest` and
is never pinned, so a `44` tag would name a version nothing guarantees.

GHCR limits worth knowing before a push fails for no visible reason: **10 GB per
layer** and a **10-minute upload timeout**. The build cleans its dnf caches
(`dnf clean all`, then `/var/cache/dnf` and `/var/cache/yum`) to stay under it.

The **GHCR package must be made public explicitly** — GHCR creates it private.

### Signature

The image is signed with **cosign** over the pushed digest, at publish time.
The private key is the CI secret `COSIGN_PRIVATE_KEY` and never enters the image
or the repository. The **public** half is committed at the repository root as
`cosign.pub` — it is a build input, not a secret — and it is published as the
`kinrin-cosign-pub` artifact of the publish job, so it travels with the release.

Verify what you actually installed, against the digest rather than a tag:

```bash
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin@sha256:<digest>"
```

The image itself ships a **verification policy** that `bluebuild`'s `signing`
module layers in at the last module. It is read, not assumed:

```bash
podman run --rm ghcr.io/bacondroid/kinrin:latest \
  sh -c 'ls -l /etc/containers/policy.json /etc/containers/registries.d/ 2>&1'
podman run --rm ghcr.io/bacondroid/kinrin:latest \
  jq -r '.transports.docker | keys[]' /etc/containers/policy.json
```

That second command must print `ghcr.io/bacondroid/kinrin` — the reference
actually published. If it prints nothing, the module emitted nothing and the
image does not verify. Boot-time enrollment of the key is host-side and follows
upstream's default; there is no enrollment procedure to run here.

## Build it yourself

You need `bluebuild` and `podman`. Bootc builds want privileges.

```bash
git clone https://github.com/bacondroid/kinrin-distro
cd kinrin-distro

bluebuild validate recipes/recipe.yaml      # pre-build, fails in seconds
bluebuild generate recipes/recipe.yaml -o /tmp/Containerfile \
  --registry ghcr.io --registry-namespace <owner>

bluebuild -vv build --registry ghcr.io --registry-namespace <owner> recipes/recipe.yaml
```

Order matters: `bluebuild validate` exists to fail **before** a 20-minute
bootc build, not after it. Write the generated Containerfile to `/tmp`, outside
the repository, so there is nothing to gitignore — the recipe is the whole image
description, and no Dockerfile is delivered.

`cosign.pub` must exist at the repository root or the build dies at the **last**
module, after twenty minutes. It is a public key, so it is committed.

### Layout

```
recipes/recipe.yaml           the recipe; its modules are the only place the image content is declared
recipes/modules/*.yaml        one file per from-file: entry — eight of them
files/                        the files module's data tree, one entry per file it ships
.github/workflows/            build.yml, and the monthly monitor-fedora.yml
TESTING.md                    the manual criteria, to run on a real machine
NOTES.md                      every ambiguity resolved, and every open decision settled
```

`files/` mirrors each destination minus the leading `/`, so
`files/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf` serves
`/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf`. Every entry in
`files.yaml` is an explicit `source:`/`destination:` **pair**: the bare
single-key form copies each file to a path named `null` and still exits 0, so
the build goes green on an empty image and nothing notices.

### CI

Three jobs, in order: `validate` (every push and every scheduled run — it is the
gate that keeps a bad recipe out of a long build), `build` (the bootc build plus
the in-image gates), `publish` (the GHCR push and the signature).

Six checks gate on the image. Four are the plan's: `bluebuild validate` and
`niri validate`, the presence chain over the `files.yaml` destinations
(criterion 28), and the §6.1 policy read (criterion 28b). Two are additions:
the `ID=kinrin` / `ID_LIKE=fedora` greps (§5) and `cosign verify` against the
pushed digest (§6.1). `niri validate` runs **inside** the built image — the
binary is absent from a CI runner and a host-side call would not see the image's
config anyway.

## Monitoring

`monitor-fedora.yml` runs monthly and opens one issue once **both** COPR package
names, `dms` and `dms-greeter`, have left the COPR. It matches them
individually on purpose: `DankMaterialShell` is already in Fedora, so a generic
"DMS arrived" signal would read true on day one and open a migration issue while
one of the two is still COPR-only.

A broken COPR turns the monthly build red and leaves the published image healthy.
The risk is not the outage — it is not seeing it.

## Licence

This repository ships **per-component notices**, not one covering licence — see
[`LICENSE`](LICENSE). The short version: the image bundles GPL-2.0 (Fedora),
GPL-3.0-or-later (Niri) and MIT (DMS), and the registry `theme.json` declares
**no licence at all**, so it cannot be filed under MIT and carries its own line.
`GPL-2.0-only` is not a valid umbrella here: it cannot cover Niri's
GPL-3.0-or-later.
