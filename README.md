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
| Apps | Dolphin, Konsole, Kate, Discover (backed by `packagekit`) |
| Games | `steam` + `steam-devices` from RPM Fusion; on-demand VRR for `steam_app_*` windows |
| Chat | **not preinstalled** — `sudo dnf install discord` |
| Dev | podman, ripgrep, fish, zsh. **No compiler toolchain** — see [What is not in the box](#what-is-not-in-the-box) |
| Editor | **not preinstalled** — Dolphin is the file manager; orca is one command, see below |
| Flatpak | the `flatpak` package is present but no remote is enabled |

### What is not in the box

Some things were removed so the ISO fits under GitHub's 2 GiB release-asset cap.
All of it is one command away, and the repositories are already enabled:

```sh
sudo dnf install discord                          # rpmfusion-nonfree
sudo dnf install @development-tools rust cargo    # compilers, rust, cargo
sudo dnf install golang nodejs npm python3-pip git-lfs golangci-lint
```

`orca` is the exception: it never came from a repository — `recipes/modules/orca.yaml`
fetched a GitHub release RPM — so the module has to be restored to bring it back.
`NOTES.md` records the exact steps.

**Discover does work**, which is the point of removing them by hand rather than
pruning the repos: `plasma-discover` alone is inert, because it pulls in only the
Qt library and never the `packagekit` daemon. The image now installs `packagekit`,
so the GUI can search `fedora`, `rpmfusion-free`, `rpmfusion-nonfree` and the
`dms` COPR. Steam, Discord and the rest are all reachable that way.

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

> `cosign.pub` **is** in this tree, and the image has been published and verified
> against it — see `NOTES.md` §6. It was missing for most of the build, and that
> gap is a trap rather than an inconvenience: without the public half `bluebuild`
> reaches the **last** module and exits 1, after the whole twenty-minute build. If
> you regenerate the tree from scratch, put this file in place *before* the first
> CI run. See [Redoing this from scratch](#redoing-this-from-scratch).

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
recipes/modules/*.yaml        one file per from-file: entry — seven of them
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
the `ID=kinrin` / `ID_LIKE=fedora` greps (PLAN §5) and `cosign verify` against the
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

The other two are unprovable **here** rather than passing. Both need the published
artifact: criterion 28b needs the `signing` module, which needs `cosign.pub`, and
`cosign verify` needs a pushed digest. At the time of that local build `cosign.pub`
did not exist yet — that is the honest state, not four out of six quietly reported
as good enough.

Both now pass in CI, where the artifact exists. Run `36821596275` was green across
`validate`, `build` and `publish`, and the pushed image was then verified from
outside CI: `cosign verify` accepts it against the committed `cosign.pub`, and a
deliberately falsified digest is rejected. The gate that once failed on a
*correct* image — because `${REPO,,}` cannot expand inside the container's `sh` —
now passes for the right reason. See `NOTES.md` §6.

One thing worth knowing about the policy check, because it is easy to get wrong:
`/etc/containers/policy.json` **is already present** in a plain Kinoite base,
shipped by `containers-common`. Its `.transports.docker` is `null`. So a gate
that only did `test -f /etc/containers/policy.json` would pass on an image whose
verification policy says nothing about this repository. The step does both, and
the reference is passed to `jq` as an argument — `--arg r "ghcr.io/$OWNER/$REPO"` —
rather than interpolated into the program. That is not a style preference: inside
single quotes, `${REPO,,}` never expands, so the assertion silently compares
against an empty reference and fails against a perfectly good image.

## Monitoring

`monitor-fedora.yml` runs monthly and opens one issue only when **three**
conditions hold together: both COPR package names, `dms` and `dms-greeter`, are
gone from the COPR, **and** official Fedora now resolves `dms` or
`DankMaterialShell`. The second half is what makes the signal mean anything — COPR
absence on its own also reads true when the COPR has merely broken, which would
file a migration issue that is not a migration. It matches the package names
individually too: `DankMaterialShell` is already in Fedora, so a generic
"DMS arrived" check would read true on day one while one of the two is still
COPR-only.

A broken COPR turns the monthly build red and leaves the published image healthy.
The risk is not the outage — it is not seeing it.

## Publish it

**This part is done.** The key pair was generated, the image was published to
`ghcr.io/bacondroid/kinrin-distro`, and `cosign verify` passes against the
committed `cosign.pub`. The procedure is kept below because it is also how you
repeat a publication without orphaning the key CI already holds — and because
every step in it exists to avoid a failure that actually happened.

### One command

```bash
~/Projects/kinrin-publish.sh
```

Run it as a script. Note the script does **not** use `set -e`: it uses
`set -uo pipefail` plus an explicit `die()` on every command, so a failure stops
the sequence at a known point instead of the shell deciding. That is a better
property than `set -e`, not a weaker one — `set -e` in an *interactive* shell
terminates the terminal outright, which is what closed the tab during the first,
pasted attempt. As a file, a failure costs you one `die` line and the script stops
there.

It is safe to re-run: each step checks whether it is already done, and it
**refuses to regenerate** the key when `cosign.pub` is already committed, because
that would orphan the `COSIGN_PRIVATE_KEY` secret CI already holds. Add
`--dry-run` to see what it would do and change nothing.

It does: generate the pair → `COSIGN_PRIVATE_KEY` into the repo secret → shred
the private half off disk → commit **only** `cosign.pub` → push, which starts
`build.yml` → wait for the run. Then it prints the published digest and the
`cosign verify` line to use against it.

### Why the pieces are what they are

- **`COSIGN_PASSWORD=""` is required, not cosmetic.** `cosign`'s `readPasswordFn`
  tests `os.LookupEnv` for **presence** and never for non-emptiness
  (`cmd/cosign/cli/generate/generate_key_pair.go:130-147` in v3.1.3), so an
  exported empty value is honoured and there is no prompt — upstream has a test
  asserting exactly that (`generate_key_pair_test.go:38-47`). Without the
  variable, `cosign` reads the controlling **terminal** twice
  (`pkg/cosign/common.go:28-53`), and a pipe cannot satisfy it. The result is an
  **unencrypted** key: it is still an `ENCRYPTED SIGSTORE PRIVATE KEY` PEM, but
  scrypt'd over an empty passphrase, which is why the publish job needs no
  `COSIGN_PASSWORD` secret to match. If you would rather have a real passphrase,
  generate with one and add `COSIGN_PASSWORD` to the `Sign` step's `env:` block
  in `build.yml`, or the run blocks on a prompt that never comes.
- **Do not pipe blank lines "for safety".** The only prompt that reads piped
  stdin is the overwrite confirm, whose default is **N**
  (`internal/ui/prompt.go:44-65`) — blank input would *decline* and abort the
  command.
- **The private half is shredded before the commit, not after.** It is on disk
  from the first command until the second; deleting it immediately closes the
  window instead of leaving it open until a later step happens to run.
- **`git add cosign.pub` is named, never a blanket add.** `.gitignore` lists
  `kinrin.tar` and `kinrin-oci.tar.gz` and nothing else — the first is required,
  and `*.pub` must never be ignored — so nothing would stop a `git add -A` from
  staging the private key.

### After the run is green

Make the GHCR package public. **GHCR creates packages private**, and a public
repository does not change that:

```
https://github.com/users/BaconDroid/packages/container/kinrin-distro/settings
```

Flip **Change visibility → Public**. It has to be the browser here: the CLI token
in use carries `gist, read:org, repo, workflow` and **no packages scope**, so
`gh api` on the package endpoint is refused. With a `write:packages` token:

```bash
gh api -X PATCH /user/packages/container/kinrin-distro -f visibility=public
```

Then verify against the digest, never a tag — no tag designates a stable image
across builds:

```bash
DIGEST=$(skopeo inspect --format '{{.Digest}}' docker://ghcr.io/bacondroid/kinrin-distro:latest)
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin-distro@$DIGEST"
```

`cosign verify` must pass. If it does not, the image is **not** verifiable and
the boot-time policy resolves nothing — treat that as a real defect, not a
warning. Record the digest and the date tag in `NOTES.md` §6 so the next build
knows which deployment a rollback returns to.

### Re-running without a new key

The key pair is generated **once**, not per build. `~/Projects/kinrin-publish.sh`
is idempotent, so re-running it after the first publication does the right thing
and nothing else: it finds `cosign.pub` already committed, leaves the key alone,
and skips straight to the push.

To rebuild or re-publish without touching the key at all, dispatch CI directly:

```bash
gh workflow run build.yml --repo BaconDroid/kinrin-distro
```

## When CI runs

`build.yml` triggers on a push that touches a **build input** only:

| Path | Why |
|---|---|
| `recipes/**` | the recipe and its seven modules |
| `files/**` | the 13 staged files |
| `cosign.pub` | what the `signing` module signs with |
| `.github/workflows/build.yml` | the pipeline itself |

A documentation-only push does not rebuild. Before this filter, fixing a typo
spent a full container build, republished `:latest`, and minted a release whose
digest differed from the previous one — several publications of the same
operating system wearing different digests, which is the exact ambiguity a
digest exists to remove.

Two triggers are deliberately **not** filtered:

- the **monthly schedule**, because its whole purpose is to notice the unpinned
  `:latest` base moving underneath us, which involves no commit at all;
- **`workflow_dispatch`**, so a rebuild is always one click away.

The filter is silent when it is wrong: a build input added outside these four
paths simply stops rebuilding, and the symptom reads as "CI is flaky" rather
than "a path is missing". If you add an input, add it here too.

## Releases

A GitHub Release is created automatically whenever `build.yml` goes green. It is
an **index entry, not a host for the image**: GitHub caps a release asset at
2 GiB and the OCI archive is 4.2, so the release carries the digest, the pinned
`podman pull` and `cosign verify` commands, and `cosign.pub` — while the image
itself stays in GHCR, the only place it is addressed by content rather than by
name.

```
v MAJOR . MINOR . PATCH
  │      │       └── counts publications within that pair
  │      └────────── major version of dms
  └───────────────── Fedora release
```

The first two are **read out of the built image** — `MAJOR` from
`/etc/fedora-release`, `MINOR` from `rpm -q dms` — while it is loaded for the
gates, never from a value typed into the workflow. A hardcoded version drifts the
moment the base moves; a release whose name disagrees with its contents is worse
than no release. So Fedora 44 builds as `v44.x.y`, Fedora 45 as `v45.0.0`, and dms
2.x as `v44.2.0`.

Two guards keep the numbering honest:

- **Idempotent.** A re-run that reproduces the same digest does not mint a new
  version — releases, not CI runs, are what get numbered.
- **Serialised.** Releases are created under a concurrency group, so two runs
  finishing together cannot read the same release list and race for one tag.

The job holds `contents: write` and deliberately **not** `packages: write`, so it
cannot move a tag in the registry.

## Redoing this from scratch

Every item below is a failure that actually happened, not a hypothetical. The
order matters as much as the content.

**In this order:**

1. **`cosign.pub` must be in the tree before the first CI run.** It is a build
   input, not documentation. Without it the `signing` module — the *last* of the
   last of seven — exits 1, and the full build is spent before you find out.
2. **Run `~/Projects/kinrin-publish.sh` as a script, never pasted into a shell.**
   It uses `set -uo pipefail` and an explicit `die()` rather than `set -e`, so a
   failure stops the sequence at a known point. Pasting it does not close the tab
   the way the original `set -euo pipefail` attempt did — but a file is still the
   only way to keep the steps ordered and idempotent.
3. **Never `git add -A` while a key pair is on disk.** `.gitignore` is exactly
   `kinrin.tar` and `kinrin-oci.tar.gz`; `*.pub` must never be ignored, so a
   blanket add would stage the private half. The script names `cosign.pub`.
4. **Do not pipe blank lines into cosign.** The only prompt that reads piped
   stdin is the overwrite confirm, whose default is **N**; blank input declines
   and aborts the command.
5. **Shred the private half before committing, not after.** It exists on disk
   from the first command until the second.
6. **Do not add a Dockerfile, an `image` module, or versioned module names.** The
   signing policy keys off the recipe's `name:` joined to the build registry, and
   the modules are fixed in order with `signing` last.
7. **Check the package is publicly readable rather than assuming it.** GHCR
   creates packages private and a public repository does not change that.

**The pipeline's own fixes are load-bearing. Do not "simplify" them away** —
each is explained in the comments on the step that needs it:

- `--build-driver docker` **and** `--archive`. bluebuild passes `--load` only when
  `GITHUB_ACTIONS` is unset, because upstream expects a push; without them the
  image stays inside the buildx builder and no local store can see it, while
  bluebuild still logs `Finished building:` with every tag. `--archive` is
  implemented only in the docker driver, which is why the driver is forced.
- The archive is `<name>.tar.gz`. A glob of `*.tar` misses it.
- A gate that runs `jq` **inside** the image must pass it as argv, not through
  `sh -c` with the ref in single quotes: `${VAR,,}` is a bashism that never
  expands inside the container's `sh`, so the ref silently arrives empty.
- `sha256sum --check` resolves the filename *from the checksum line*, so a
  release binary must be downloaded under its release name.
- The publish job needs **both** `skopeo login` and `docker login`: skopeo writes
  containers-image's `auth.json`, cosign reads `$DOCKER_CONFIG/config.json`.
- Do not publish with `skopeo copy --all containers-storage:`. It drives podman
  over `dial-stdio` and fails `Operation not permitted` on a runner where
  `podman load` just succeeded. The archive is handed over and read as
  `oci-archive:`.

**Then verify, instead of believing the green tick:**

```bash
DIGEST=$(skopeo inspect --format '{{.Digest}}' docker://ghcr.io/bacondroid/kinrin-distro:latest)
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin-distro@$DIGEST"
podman pull "docker://ghcr.io/bacondroid/kinrin-distro@$DIGEST"
podman run --rm "docker://ghcr.io/bacondroid/kinrin-distro@$DIGEST" \
  niri validate --config /etc/niri/config.kdl
```

Two of those checks matter more than they look. `skopeo inspect` **with no
credentials at all** must succeed, or the package is private and the image is not
actually installable by anyone else. And confirm the verification can fail:
`cosign verify` against a deliberately falsified digest must be rejected. A check
that cannot fail is not a check.

Every `:latest` moves with each green run, so a digest copied into documentation
is a record of one run, not a constant. The authoritative value is the one the
publish job prints in its log, in the `Capture digest` step.

## Licence

This repository ships **per-component notices**, not one covering licence — see
[`LICENSE`](LICENSE). The short version: the image bundles GPL-2.0 (Fedora),
GPL-3.0-or-later (Niri) and MIT (DMS), and the registry `theme.json` declares
**no licence at all**, so it cannot be filed under MIT and carries its own line.
`GPL-2.0-only` is not a valid umbrella here: it cannot cover Niri's
GPL-3.0-or-later.
