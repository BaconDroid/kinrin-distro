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
sudo bootc switch ghcr.io/bacondroid/kinrin-distro:latest && sudo reboot          # discovery
sudo bootc switch ghcr.io/bacondroid/kinrin-distro@sha256:<digest> && sudo reboot # reproducible
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

## Roll back (PLAN §7)

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
bootc switch ghcr.io/bacondroid/kinrin-distro@sha256:<digest>
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
or the repository. The **public** half belongs at the repository root as `cosign.pub` — a build
input, not a secret — and is published as the `kinrin-cosign-pub` artifact of the
publish job so it travels with the release.

> **`cosign.pub` is not in this tree yet.** The pair was never generated: the
> machine this was built on refused the write as a secret path, and the correct
> response to that is to report it, not to route around it. Until the public half
> exists, `bluebuild` reaches the **last** module and exits 1 — after the whole
> twenty-minute build. See `NOTES.md` §5.
>
> One command sequence finishes the publication; nothing above is a prerequisite
> for it. See [Publish it](#publish-it) below.

Verify what you actually installed, against the digest rather than a tag:

```bash
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin-distro@sha256:<digest>"
```

The image itself ships a **verification policy** that `bluebuild`'s `signing`
module layers in at the last module. It is read, not assumed:

```bash
podman run --rm ghcr.io/bacondroid/kinrin-distro:latest \
  sh -c 'ls -l /etc/containers/policy.json /etc/containers/registries.d/ 2>&1'
podman run --rm ghcr.io/bacondroid/kinrin-distro:latest \
  jq -r '.transports.docker | keys[]' /etc/containers/policy.json
```

That second command must print `ghcr.io/bacondroid/kinrin-distro` — the reference
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
module, after twenty minutes. It is a public key, so it belongs in the
repository — see the note above for its current state.

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

**What has actually run.** The image was built locally, end to end from the
eight module files — 2116 packages, 10.9 GB — and four of the six checks pass
inside it:

```
PASS  niri validate --config /etc/niri/config.kdl
PASS  files.yaml presence chain, 13 paths
PASS  os-release ID=kinrin
PASS  os-release ID_LIKE=fedora
```

The other two are unprovable here rather than passing. Criterion 28b needs the
`signing` module, which needs `cosign.pub`, which does not exist yet — see
[Publish it](#publish-it). And `cosign verify` needs a pushed digest. That is
the honest state, not four out of six quietly reported as good enough.

One thing worth knowing about the policy check, because it is easy to get wrong:
`/etc/containers/policy.json` **is already present** in a plain Kinoite base,
shipped by `containers-common`. Its `.transports.docker` is `null`. So a gate
that only did `test -f /etc/containers/policy.json` would pass on an image whose
verification policy says nothing about this repository. The step does both —
`test -f` **and** `jq -e '.transports.docker | has("ghcr.io/<owner>/<repo>")'`.

## Monitoring

`monitor-fedora.yml` runs monthly and opens one issue once **both** COPR package
names, `dms` and `dms-greeter`, have left the COPR. It matches them
individually on purpose: `DankMaterialShell` is already in Fedora, so a generic
"DMS arrived" signal would read true on day one and open a migration issue while
one of the two is still COPR-only.

A broken COPR turns the monthly build red and leaves the published image healthy.
The risk is not the outage — it is not seeing it.

## Publish it

Everything above builds and runs. This is the part that is **not** done yet, and
it is one sequence: generate the key pair, hand the private half to CI as a
secret, commit the public half as a build input, and let the push start CI.

```bash
cd ~/Projects/kinrin-distro
set -euo pipefail
REPO=BaconDroid/kinrin-distro

# 1. The pair. COSIGN_PASSWORD="" writes an UNENCRYPTED key with no prompt —
#    cosign otherwise blocks on an interactive password question. The publish
#    job needs no COSIGN_PASSWORD secret to match, because the key is unencrypted.
COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix cosign

# 2. The private half becomes a CI secret, then leaves the disk immediately.
gh secret set COSIGN_PRIVATE_KEY --repo "$REPO" < cosign.key
shred -u cosign.key

# 3. The public half is a BUILD INPUT — the `signing` module cannot find it
#    otherwise. Named explicitly: .gitignore is exactly `kinrin.tar`, so a
#    blanket `git add` is the only way a private key could ever get in here.
git add cosign.pub
git commit -m 'Add the cosign public half: the build input the signing module requires'
git push origin "$REPO"

# 4. The push starts build.yml (on: push). Watch it to the end.
gh run watch --repo "$REPO" --exit-status
```

Then, once the run is green, make the GHCR package public — **GHCR creates it
private**, and an unpublished package cannot be pulled even though the repository
is public:

```
https://github.com/users/BaconDroid/packages/container/kinrin-distro/settings
```

Flip **Change visibility → Public**. It has to be done in the browser here: the
CLI token in use carries `gist, read:org, repo, workflow` and **no packages
scope**, so `gh api` on the package endpoint is refused. A token with
`write:packages` can do it instead:

```bash
gh api -X PATCH /user/packages/container/kinrin-distro -f visibility=public
```

Finally, record what was published — §6/§7's rollback needs the digest, and a
date tag is only a record:

```bash
DIGEST=$(skopeo inspect --format '{{.Digest}}' docker://ghcr.io/bacondroid/kinrin-distro:latest)
echo "digest: $DIGEST"
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin-distro@$DIGEST"
```

`cosign verify` must pass here. If it does not, the image is **not** verifiable
and the boot-time policy will resolve nothing — that is the whole point of the
key, so treat a failure as a real defect rather than a warning.

Afterwards, put the digest and the date tag into `NOTES.md` §5 so the next build
knows which deployment a rollback should return to.

### Re-running without a new key

The key pair is generated **once**, not per build. To rebuild or re-publish,
skip steps 1 and 2 and start at step 3, or dispatch CI directly:

```bash
gh workflow run build.yml --repo BaconDroid/kinrin-distro
```

## Licence

This repository ships **per-component notices**, not one covering licence — see
[`LICENSE`](LICENSE). The short version: the image bundles GPL-2.0 (Fedora),
GPL-3.0-or-later (Niri) and MIT (DMS), and the registry `theme.json` declares
**no licence at all**, so it cannot be filed under MIT and carries its own line.
`GPL-2.0-only` is not a valid umbrella here: it cannot cover Niri's
GPL-3.0-or-later.
