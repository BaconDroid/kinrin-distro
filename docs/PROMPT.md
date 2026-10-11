# KinRin — build the image repository and its CI

You are building the **KinRin** repository: the source, the BlueBuild recipe, and the CI that
publishes the image. The design is already decided and written down. **Your job is to
implement it, not to redesign it.**

## The specification

`/home/bacon/Plans/niri-kde-atomic/PLAN.md`, English. Read the file — do not trust any line count
quoted anywhere, including the one that may have reached you before.

Read it **in full before writing anything**. It is an instruction set: what to build, where
files go, what commands run, and what to verify. Every section is a task for you.

It is not a document to improve. If something in it is ambiguous, pick the reading the rest of
the document supports, implement it, and note the ambiguity in a `NOTES.md` at the repo root.
Do not silently change a decision.

## What to produce

A git repository, public, containing:

```
recipes/recipe.yaml                  # the recipe, verbatim from §5
recipes/modules/*.yaml               # one file per `from-file:` entry — eight files
.github/workflows/build.yml          # the CI
.github/workflows/monitor-fedora.yml # monthly check that `dms` and `dms-greeter` landed in Fedora — Fedora name `DankMaterialShell` — (§9)
README.md                            # what KinRin is, how to install, how to build (§6 and §7)
TESTING.md                           # the §8 criteria, as the manual test plan
NOTES.md                             # ambiguities you resolved, and why
LICENSE                              # §10 open decision, resolved before publication
.gitignore                        # just `kinrin.tar` (job 2's artifact). NEVER ignore `*.pub` —
                                    # `cosign.pub` is a committed build input, not a secret (§5)
files/                              # the `files` module's data tree: one entry per file it ships (§5.2)
cosign.pub                          # the PUBLIC half only, committed at the root — the `signing`
                                    # module exits 1 without it, at the last module (§5)
```

In `files/`, every path mirrors its destination, minus the leading `/` — so
`files/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf` serves
`/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf`. Write each `files.yaml` entry as an explicit
`source:`/`destination:` **pair**; the bare single-key form makes the module copy to a path named
`null` and still exit 0 (§5.2). The seven other modules live in `recipes/modules/` and need no data
tree.

Eight module files, one per `from-file:` entry of §5. `- type: signing` is **inline** in the
recipe and gets no file of its own. There is no `systemd-user.yaml`: `niri-vrr.service` is
activated by a `niri.service` drop-in, so nothing needs a user-unit enable list.

§9 requires `monitor-fedora.yml` and it is **not optional**: it is the monthly job that opens the
issue carrying the migration steps once the monitor reports that `dms` and `dms-greeter` landed in
the Fedora repos — both of them, each named in its own check. Two rules decide whether that job
helps or misleads (§9):

- Match the two COPR package names **individually** — `dms` and `dms-greeter` — never a generic
  "DMS arrived" signal, or the job opens a migration issue while one of the two is still COPR-only.
  The check has to accept **either** name for the shell: Fedora's package is `DankMaterialShell`, which is **already in Fedora**, while the COPR ships `dms`. A match on
  `DankMaterialShell` alone therefore reads as "landed" on day one, and a match on `dms` alone would
  never fire if the upstream name changes. Test both names and require the COPR one to be gone.
- The issue must tell the maintainer to drop the `copr` key from **`recipes/modules/dnf.yaml`**,
  not from `recipe.yaml`, which only lists modules and has no such key. Saying the wrong file is
  worse than saying nothing: it sends them editing a file with nothing to remove. The same issue
  must also say to **replace `dms` with `DankMaterialShell` in that file's `install:` list** — that
  is the name the Fedora package carries, so dropping the COPR key without the rename leaves a
  `dnf` module asking for a package no enabled repo provides, and the build fails. Then re-run §8.

Write the job in the same pass as `build.yml` — a broken COPR leaves the published image healthy,
so scheduled CI is where breakage shows, not the published image: the monthly build turning red is the
  signal for a broken COPR, and the monitor job is the signal for a package that failed to land (§9).

Nothing else. No documentation site and no extra tooling. **No Dockerfile is delivered** — the recipe
is the whole image description, and the only Containerfile that ever exists is the one
`bluebuild generate` writes, which you point at `/tmp` — outside the repository, so there is nothing
to gitignore — and never emit into the repo. Nothing hand-written under `recipes/` beyond the recipe and its eight module files. Nothing
beyond the list above and the `LICENSE` §10 requires — that file is the repo-file decision owed at publication — the Cosign
key pair in §10 is the other publication prerequisite, and it stays out of the repo. The `LICENSE` itself is a per-component notice or a covering licence, not a single
hard-coded SPDX id.

The image also ships two themes, **Dracula** (dark) and **Alucard** (light), as a single
`theme.json` in which they are the `dark` and `light` objects. They are activated through DMS and
propagated by matugen, which rewrites colours only and leaves Breeze underneath — that is the
intended fallback, not an omission. §4.12, and §4.13 for the licensing. Nothing from the dracula
organisation is installed: `dracula/kde` does not exist (`404`) and `dracula/gtk` does (§4.13).

## The image

- Fedora Kinoite base, `:latest`, built with **bootc**.
- **Plasma is kept as a fallback session.** `plasma-workspace`, `plasma-workspace-common` and
  `kwin` are **already in** the §4.0 `install:` list — copy them verbatim, do not re-derive.
  `plasma-workspace-common` is the one that is easy to drop, but the one that carries
  `/usr/share/wayland-sessions/plasma.desktop` is **`plasma-workspace`**: without it criterion 6
  cannot run, criterion 13 cannot list Plasma, and the greeter has no fallback session to offer
  (criterion 13). So the build check for criterion 6 is two commands — `ls /usr/share/wayland-sessions/`
  listing **both** `niri.desktop` and `plasma.desktop`, and `test -x /usr/bin/startplasma-wayland`
  passing — because the session file and the command resolve separately and either can be missing
  while the other works.
- Authored with **BlueBuild**; the recipe's modules are the only place the image content is
  declared. No hand-written shell beyond the four `type: script@v2` modules. Of those four, two are
  multi-command shell steps — the six ordered commands of §3.2 in
  `flatpak.yaml`, and the `dms setup` `RUN` of §4.5, which lives in
  `recipes/modules/niri-config.yaml`. The other two are `script` because they fetch a URL, which is
  a different reason and the same consequence.
- Published to **GHCR** as `ghcr.io/${{ github.repository }}`, tags `latest` plus a **build-date** tag
  (§6), the date computed **in the publish job** by the `id: meta` step — not in the build job, and not
  a hardcoded value. Not a Fedora version tag — the base is not pinned, so a
  version tag would lie.
- Signed with **cosign** (§6.1). The `signing` module contributes the **verification policy** the
  image ships — inspect it in the built image, do not assume it:
  `podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" sh -c 'ls -l /etc/containers/policy.json /etc/containers/registries.d/ 2>&1'`
  — inside the image, and keep the `2>&1`, without which a missing file goes to stderr and the check below cannot
  fire. The private key **never enters
  the image**: it is a CI secret, and the signature over the pushed digest is produced at **publish**
  time. The **public** key is published and is what the publish job verifies against. If the
  inspection prints nothing, do not claim the image verifies.
- CI runs **monthly** on a schedule plus `workflow_dispatch` (§6).

## Hard constraints

These come from §2, and are not negotiable:

1. **Repository order: official Fedora, then COPR, then RPM Fusion.** `dms` on rung 2,
   `steam` and `discord` on rung 3. (§2 rule 1)
2. **Latest stable, never pinned.** No version pins on packages or the base image. An RC counts as a dev
   build. (§2 rule 2) — **exception, and it is not a package pin**: the four `script` modules are declared
   `type: script@v2`, not a bare `type: script`. A bare type resolves to the `latest` tag, and that tag is
   reassigned to the highest major on every upstream push, so the bare form silently becomes `@v3` when one
   lands; v1 is bash and accepted only as the literal `script@v1`, and v2 is POSIX shell with `set -eu` per
   entry and no `pipefail`. Every other type in the plan is single-major, so its bare form is already `@v1` and
   cannot drift — leave those bare. Record the pinned major in `NOTES.md` (§5).
3. **RPM only.** The `flatpak` package stays — §3.1 gives the reason, the installed Flatpak backend `plasma-discover-flatpak` `Requires: flatpak` (`plasma-discover` itself does not) —
   but nothing is installed from it and no remote is enabled (§3.2). (§2 rule 3)
4. **bootc stays** — it is how the image is authored. rpm-ostree is the deployment system. (§2 rule 4)
5. **No layering.** The image is rebuilt, never patched. (§2 rule 5, §6.1)

And from §5: **no module may be `type: custom`** — that module's schema is
`type, source, no-cache, env, secrets`, with no inline content key, so a `RUN` in it fails
`bluebuild validate`. **Four** modules are `type: script@v2`: two because they run a multi-command shell in
one layer — `flatpak.yaml` (§3.2) and `niri-config.yaml` (§4.5) — and two more because they fetch a
URL: `theme.yaml` and `orca.yaml` (§5.2; no official BlueBuild module can download anything, and
`theme.yaml` also
runs the `jq` shape assertion). The other four are official types (`dnf`, `files`, `systemd` for
the system units, `os-release`). `os-release.yaml` carries `properties: {ID: kinrin,
ID_LIKE: fedora}` and runs **last of the eight**, so `dnf` and `dms setup` still resolve
`ID=fedora` (§3, §5.2, §11). Nothing else may be custom, and
the script modules stay a single stage: no `FROM … AS`, no `COPY --from`, no second builder image.

## Traps that will cost you a build or a session if you miss them

Each is already written in the plan. Some fail loudly — the COPR 404 and `dms` refusing root break
the build outright — and the rest fail quietly afterwards, as a wrong theme, a missing keybind, a
laptop that does not suspend. This is not an exhaustive list of §4 or §11 either: read those too.
Treat all of them as load-bearing.

- **The base ships a display manager, enabled — disable it and enable greetd, or the boot never
  settles.** `/etc/systemd/system/display-manager.service -> /usr/lib/systemd/system/plasmalogin.service`
  is there in `quay.io/fedora/fedora-kinoite:latest` (verified by execution). Enabling greetd alone
  is not enough: two DMs both claiming `graphical.target` is not a login screen, and a bare-metal
  install with the base's DM still active has none of ours. **Enable greetd and do NOT disable the alias.**
  `recipes/modules/systemd-system.yaml` must read `system: {enabled: [greetd], disabled: [plasmalogin.service]}`. Writing
  `display-manager.service` into `disabled:` **breaks the boot**: the BlueBuild `systemd` module runs its `enabled:` loop before
  its `disabled:` loop, greetd activates **only** through the `display-manager.service` alias (`[Install] Alias=display-manager.service`,
  no `WantedBy=`), and `graphical.target` wants `display-manager.service` as its only DM boot path — so `systemctl -f enable greetd`
  repoints the alias at greetd, and the `disabled:` pass then deletes the symlink it just created, leaving greetd disabled and the image
  booting to a black screen with no login. Keep `plasmalogin.service` in `disabled:` (it is harmless and worth declaring);
  disabling only the alias is a vacuous pass, because the base may have `plasmalogin.service`
  enabled directly and a `plasmalogin.service` still racing greetd for VT1 is the same unsettled
  boot. The package `plasma-login-manager` ships `plasmalogin.service`, the unit
  that symlink points at — it is not an sddm alias — so the Plasma binaries exist either way,
  which is what the fallback needs. §3, §11.
- **`user = "greeter"` in `/etc/greetd/config.toml` is greetd's default, written out explicitly.** greetd falls back
  to the `greeter` account, and the line says so; it is also read back out of the config by the
  `%post` to `chown` the cache, which is its second reason to exist. The `dms-greeter` `%post`
  writes a config containing it and touches the file on **two** branches: `:198` creates it when
  the file is absent, and `:211` updates one that does not already mention `dms-greeter`, after
  backing it up at `:212-213` — and our `files` module writes the file, so ours is authoritative and
  the RPM's is skipped, not merged. Write the spec's own template (`dms-greeter.spec:200-208`):
  ```toml
  [terminal]
  vt = 1

  [default_session]
  user = "greeter"
  command = "/usr/bin/dms-greeter --command niri"
  ```
  The 0.8 form `default_session = "dms-greeter.desktop"` is a table in 0.10 and the greeter never
  starts. greetd never looks in `/usr/share/wayland-sessions/`, so do not go looking there for a
  name. Criterion 11 is the check.
- **Ship no sysusers file for `greeter`.** The RPM installs
  `/usr/lib/sysusers.d/dms-greeter.conf` and creates the group and user in `%pre` with `-r`
  (`dms-greeter.spec:77,97,102-108`). Redeclaring that line makes two sources of truth for one
  system user and fights the RPM at every boot. DRM access needs no group, but the two node types come from **different** rules: `card*` through the logind ACL at `70-uaccess.rules:46`, `renderD*` world-accessibly through `50-udev-default.rules:61` (`MODE="0666"`). Add no group, and do not assume one rule covers both.
- **Do not add a `semanage` step.** The `%post` already sets the three fcontexts and `restorecon`s
  them in **four** actions, the fourth being `restorecon /etc/pam.d/greetd`
  (`dms-greeter.spec:113-128`, the PAM line at `:127`); it also reads `user =`
  back out of the config to `chown` the cache, which is why that line matters twice. The block is
  guarded on `[ -x /usr/sbin/semanage ] && [ -x /usr/sbin/restorecon ]` (`:113`), and that guard is
  redundant rather than a real branch: the `Requires: policycoreutils-python-utils` at `:26` is
  **hard**. `dms-greeter enable` labels **nothing** — it enables greetd (`greeter_install.go:667`)
  and sets `graphical.target`
  (`:686-715`), which the `%post` also attempts, so it is a first-boot check and not a build step:
  confirm `systemctl get-default` says `graphical.target`, confirm greetd is **enabled**, and confirm
  both `systemctl is-enabled plasmalogin.service` and `systemctl is-enabled sddm.service` report
  `disabled` or `not-found` — checking only the `display-manager.service` symlink passes vacuously
  if the base enables `plasmalogin.service` directly. Run `dms-greeter enable` only if the target or
  greetd is wrong. Criterion 11.
- **The greeter theme is symlinked into the greeter cache, not regenerated and not copied.** `dms-greeter sync` reaches `SyncDMSConfigs`, which links three files from the session user's home into `/var/cache/dms-greeter/`: `settings.json` from `~/.config/DankMaterialShell/settings.json` and `session.json` from `~/.local/state/DankMaterialShell/session.json` (`installer.go:1404-1425`, the `ln -sf` at `:1437`), plus `colors.json` from `~/.cache/DankMaterialShell/dms-colors.json` — the last from `GreeterColorsSource` (`:1355-1356`, linked at `:1384`). **A missing source is created empty first** (`installer.go:1430`), so a fresh home yields three symlinks onto three `{}` files rather than an error, and the greeter renders the same Dracula theme **without ever running matugen**; there is no `colors.kdl` to look for under `/var/lib/greeter`, and `~/.config/DankMaterialShell/colors.json` is not a path at all. The same call then **adds** a per-user layer under `users/<username>/`, symlinked by `linkSlotEntry` (`user_cache_sync.go:326`) with a snapshot-copy fallback — extra to the three root links, not instead of them. **The shipped README says `sync` "copies" the theme; that is loose wording, not the mechanism** — the code and the binary both link the root files. **The session user must be in the `greeter` group**: `sync` tests for it, adds it itself when non-interactive, or prompts `"Would you like to add your user to the greeter group? (Y/n)"` and runs `usermod -aG greeter <user>` if confirmed — and either way a logout/login is needed before it takes effect, so pre-add with `usermod -aG greeter <user>` rather than relying on the prompt. This is unrelated to the DRM rule above, which is about device access. Run `dms-greeter sync` **as the session user** — it self-elevates internally, and the cache is `chmod 2770` (`installer.go:889`), so no outer `sudo`. Criterion 12b: after the first login, pre-add the group, run the sync, then `ls -l /var/cache/dms-greeter/` must show all three as symlinks into that home, then confirm the greeter shows Dracula before anyone logs in. It needs a first user, so it cannot run in CI.
- **Criterion 12 fails by design on a fresh image — do not fix it by editing a theme file.** The
  greeter renders its own default theme until `dms-greeter sync` has run, and 12b is what runs it.
  So on a freshly installed image, before any login, 12 **fails by design**; the fix is to run 12b
  first, never to touch `theme.json` or the skel. Editing a theme file to make 12 pass proves nothing
  about the greeter and leaves the shipped theme wrong.
- **`opencode` is not shipped; §4.11 is the RPM list only.** No RPM and no Flatpak exists for it
  (every candidate appid is a 404 on Flathub) and the only channel is an install script that writes
  into the user's home, so nothing goes in `dnf.yaml`, in a module, or in the image. The §4.11 table
  is what the image installs; orca is the only tool of the two that comes from a package.
- **`orca.yaml` takes the RPM out of the release, never the AppImage.** The release ships
  `orca-ide-<version>.x86_64.rpm`, `orca-ide-<version>.aarch64.rpm` and `orca-linux.AppImage`, and
  the AppImage is the one to refuse: it mounts in the home on every launch. Pick the asset out of
  the release JSON rather than composing a filename —
  `'.assets[].browser_download_url' | grep -E 'x86_64\.rpm$' | head -n1` — so the AppImage and the `aarch64`
  RPM are never candidates, then `test -n "$url"` on the result so an empty match fails the build
  instead of feeding `dnf install` nothing. Transcribe the plan's shape exactly: **one** `snippets:` entry, not
  three — the v2 runner gives each entry its own `/bin/sh -c 'set -eu; …'` subshell, so `$url` does not survive into
  the next entry; and keep the `&&` chain. The guard is **two** tests, not one — transcribe both:
  `&& test -n "$url"` fails a fetch that collapsed to empty, and
  `&& case "$url" in https://github.com/stablyai/orca/releases/download/*) ;; *) exit 1 ;; esac`
  binds the URL to the one download prefix the live `releases/latest` response uses, so a redirected or
  substituted host never reaches `dnf install`. `test -n` alone is an empty-URL check, not an origin check.
  It binds origin, it does not authenticate: a same-origin hostile asset would still install, and closing that
  needs a signature check, which is new design rather than a minimal fix. No `pipefail`: not POSIX, and each
  failure mode already collapses to an empty `$url`. The module takes `releases/latest`, so nothing is pinned (§2 rule 2),
  and the numbers §4.11 prints are the release at build time. It installs through `dnf`, so orca
  lives in the image and updates with it. §4.11 and §5.2 both name `stablyai/orca`; the release itself is
  `releases/latest`, so neither the owner, the repository nor a version is yours to confirm — take the
  mirror from those two sections and do not re-derive it. Criterion 29 is the check —
  the RPM's dependencies resolve in the image, and orca coexists with the greeter. §4.11, §5.2.
- **VRR is a user unit, the unit file is content `files.yaml` must ship, and nothing enables it.**
  Both `/usr/lib/systemd/user/niri-vrr.service` and its
  `/usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf` drop-in
  (`[Unit]` / `Wants=niri-vrr.service`) go in `files.yaml`'s `files:` list. The unit carries
  `After=niri.service`, `PartOf=niri.service` — it stops with the session, and `Wants=` has no stop
  semantics — and `TimeoutStartSec=infinity`, which exempts the socket-wait loop from the 90 s start
  timeout. `infinity`, **never `0`**: `0` is a zero-second budget, not a disable, and `Type=oneshot` already has
  the start timeout disabled by default, so `0` would override that and kill the unit on its first `sleep 1`
  (a `Type=oneshot` unit with `TimeoutStartSec=0` fails in 2 ms with `status=15/TERM`; the same unit with no
  explicit timeout, or with `infinity`, exits 0). It also carries **no `[Install]` section**: `WantedBy=default.target` would start it in
  every session, Plasma included, where `niri msg` has no socket and the wait loop never returns.
  Activation is the `Wants=` from `niri.service`, so it starts with niri and only with niri — which
  is why there is no `systemd-user.yaml` in the recipe at all. Never `systemctl --user enable
  niri-vrr.service`: that writes back the `default.target` symlink. It waits for niri's socket in a
  loop before calling `niri msg`, then loops over the real output names — a one-shot `ExecStart`
  fires before the socket exists and silently does nothing. The loop variable must be spelled `$$o`:
  a bare `$o` is substituted to the empty string by systemd before the shell runs, so every call
  becomes `niri msg output ""` and fails the oneshot. Never a system unit. §4.4, criterion 31.
- **The flatpak cleanup is six commands and the order matters.** It lives in
  `recipes/modules/flatpak.yaml`, a `type: script@v2` module using `snippets:` — **not** a recipe
  `postprocess`, no such BlueBuild key exists.   That module goes **immediately after** `dnf.yaml` in `modules:`, for the reason §5.2 gives —
  `/var/lib/flatpak` must still be empty and no user session has run yet. Run
  `install -d /var/lib/flatpak` first (the directory does not exist in the base), then
  the capture-then-test form §3.2 gives — `remotes=$(flatpak remotes --system --columns=name)` then
  `if printf '%s\n' "$remotes" | grep -qx <name>; then flatpak remote-delete --system <name>; fi` — **capture before you grep**, because a
  pipeline reports the status of its last command, so piping `flatpak remotes` straight into `grep` swallows a failing
  `flatpak`, skips both deletes and still reaches the marker with exit 0 (verified: under `set -eu`, `if false | grep -qx fedora; then :; fi; touch marker` exits 0 and creates the marker) for `fedora` and `fedora-testing` — **not** `--if-exists`, which flatpak 1.18.2 does not have (the
  unit has two `ExecStart` lines and adds both, so removing one leaves `flatpak remotes --system`
  non-empty and criterion 2c fails), then write the empty marker `/var/lib/flatpak/.fedora-initialized`, then `ln -sf /dev/null` the unit. **The mask is what criterion 2c checks**: `readlink /etc/systemd/system/flatpak-add-fedora-repos.service` must be `/dev/null`. The marker and the two `remote-delete` guards may be erased after the modules run, because BlueBuild's `post_build.sh` is reported to `rm -rf /tmp/* /var/* /opt` (§3.2, asserted not pinned), so never write a criterion against the marker
  `/var/lib/flatpak/.fedora-initialized`, then
  `ln -sf /dev/null /etc/systemd/system/flatpak-add-fedora-repos.service` — the mask symlink,
  `/etc/systemd/system/<unit> → /dev/null`, not `/usr/lib/systemd/system`.
  **Mask it** — the marker alone is not enough, because it lives in `/var` and bootc treats `/var`
  in the image like a Docker `VOLUME`, unpacked only from the *initial* image, so on the
  `bootc switch` path of §6 it never arrives. The `%post` only *enables* the unit, and a unit
  enabled during a container build does not run: confirm rather than assume. §3.2, §11.
- **COPR moved to Pulp, and `copr:` is a mapping key, not a list entry.** The old flat URL
  `…/avengemedia/dms/repo_fedora44.xml` returns 404, as does the old `/api/coprs/…`. The plan
  carries **no COPR URL**: it writes `copr:` as a mapping key whose value is an `enable:` list,
  and `- avengemedia/dms` is an **item of that list**. Written as a `- copr:` list entry it breaks
  the build — `nonfree:` and `copr:` are two keys at the same level (§4.0). If your first build
  fails fetching the repo, that is why — pin the
  `/coprs/<owner>/<proj>/repo/fedora-<N>/<owner>-<proj>-fedora-<N>.repo` form, with `<N>` read
  from the base image. Do not hard-code `44`: the base is `:latest`, so a frozen version breaks the
  build the day Fedora moves on — that is pinning in all but name, and rule 2 forbids it.
- **`dms` refuses root** (exit 1) on every subcommand, and the build is root. Implement §4.5 as a
  **single shell body in `snippets:` inside `recipes/modules/niri-config.yaml`** — the block below with the leading
  Dockerfile `RUN` verb **stripped**, because a snippet is a plain `/bin/sh` command string and pasting the verb
  gives `RUN: command not found` (§5). Everything else transcribed exactly, all of it in one layer:
  ```sh
  dnf install -y util-linux shadow-utils \
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
  Five groups (six lines) are load-bearing and cannot be paraphrased away:
  - `su - builder -c 'HOME=/staging dms setup headless --compositor niri'` — do not run this as
    root: `dms setup` refuses root, which is why the throwaway `builder` exists. And do not add a
    `dms setup` autostart anywhere. §4.5.
  - `sed -i 's/spawn "ghostty"/spawn "konsole"/'` — a **correction, not a preference**.
    `dms setup headless` resolves its terminal with `parseHeadlessTerminal("")`, which returns
    `TerminalGhostty` (`core/cmd/dms/commands_setup_headless.go:128-131`), and the deployer maps
    that to `terminalCommand = "ghostty"` in the `case deps.TerminalGhostty:` arm
    (`core/internal/config/deployer.go:224-225`; the `default:` arm at `:231` holds the same value, so
    do not cite `:231`), substituted into
    `Mod+T … { spawn "{{TERMINAL_COMMAND}}"; }` in the shipped template
    (`core/internal/config/embedded/niri-binds.kdl:8`). We install `konsole`, not `ghostty`, so the
    `Mod+T` bind deployed to both `/etc/niri/dms/` and the skel would be dead — and **no criterion
    catches it**, because 2b only tests `Mod+Space`, `Mod+N` and `Mod+Alt+L`. `--terminal` cannot
    fix it: the flag accepts only `ghostty`, `kitty` or `alacritty` (`:29,132-139`, `:139` being the
    `unknown terminal` error), none of them
    `konsole`. Both `install` calls read the corrected file, so it is rewritten once.
  - `rpm -ql niri … niri.service` and `rpm -ql dms … dms.service` are **hard failures**. The drop-ins
    of §4.7 and §4.8 and criteria 2d and 26 rest on those two being *user* units. If `niri.service`
    is absent, greetd runs `niri-session` as a script, nothing starts it, and the drop-in is inert —
    which looks identical to a working one from a login. If that assertion does fire, the documented
    fallback is a wrapper at `/usr/bin/niri-session-kinrin` — not under `/usr/local/bin`: on Atomic that is `/var/usrlocal`, mutable machine state
  a build cannot make reproducible and which the `files` module is documented not to write (§4.5, §4.9) — that execs `niri-session` after
    starting `dms.service` on the user bus. **Stop relying on the `graphical-session.target` binding**,
    and re-derive the §4.1 greetd session path alongside criteria 2d and 26, since neither drop-in form
    exists in that shape and §4.1 passes a compositor flag, not a path.
  - `install -d -o builder -g builder /staging` — without it the `su - builder` call has no
    writable `HOME=/staging` and fails immediately.
  - `sed -i '1i include optional=true "../local.kdl"'` — a **prepend**, because niri accepts
    `include` only at the top level, and the path is `../local.kdl` because an include resolves
    against the including file's directory, and `binds.kdl` sits in `dms/`.
    `binds.kdl` already carries DMS's default keybinds (`Mod+Space`,
    `Mod+N`, `Mod+Alt+L`); seeding a `binds.kdl` holding *only* the include permanently suppresses
    every default bind, because the deployer skips any non-empty file, and criterion 2b plus the
    launcher in criterion 2 fail. Note the `1i` insert form: sed inserts the include as a new first
    line, and because the argument is a bare string with no trailing `\n`, the original first line
    is pushed down intact. If you rewrite this as an append (`>>`), the include lands
    *after* the existing content and may glue onto the last KDL node when the generated file has no
    trailing newline, which fails `niri validate`. §4.4, §4.5, criterion 23.
  `util-linux` provides `su` and `shadow-utils` provides `useradd`; the `install` is a guarantee
  rather than a dependency. `-u 2000` is on purpose — without it `useradd` takes 1000, and the
  first real user collides with the leftover account at first login. The staged files move with
  `install` in the same layer: do **not** reach for `COPY --from`, there is no second stage, and
  §5 forbids a custom `FROM … AS` stage. `local.kdl` is **not** produced here — it is an authored
  file owned by the `files` module (§4.4). **The build `RUN` takes neither `--skip-existing` nor
  `--force`** — transcribe the §4.5 line exactly as it stands. `--skip-existing` is for the *user's*
  re-run, where `config.kdl` already exists; `--force` is never the answer, because it writes a
  timestamped backup and two builds then produce different output. Both flags belong to
  **`headless`**, not to bare `dms setup`, so the re-run reads
  `dms setup headless --compositor niri --skip-existing`.
  And know what that flag buys you, because it is the same flag **criterion 30** runs: with
  `config.kdl` already present in the home, the command **returns without deploying anything** — so
  a first-boot re-run does not refresh the empty files, and criterion 30 is a statement about what
  survived, not about a re-deploy.
- **`files.yaml` ships `/usr/share/dms/cli-policy.json`, and `files` must come before
  `niri-config.yaml`.** `dms setup headless` carries `PersistentPreRunE: requireMutableSystemCommand`
  (`core/cmd/dms/commands_setup_headless.go:15`, the gate itself at
  `core/cmd/dms/immutable_policy.go:252`) and refuses only when the system reads as immutable
  **and** the command matches `blocked_commands`. This base reads immutable twice over:
  `/run/ostree-booted` is checked first (`immutable_policy.go:167`) and `VARIANT_ID` carries
  `kinoite` (`:197`), and the shipped defaults are **four explicit entries** — `greeter install`,
  `greeter enable`, `greeter uninstall`, `setup` — each matched exact-or-prefix rather than by
  equality (`immutable_policy.go:77`), so the single `setup` entry covers `setup headless …`
  (`core/cmd/dms/assets/cli-policy.default.json`). The in-code fallback at `immutable_policy.go:217`
  lists only three — `greeter uninstall` is missing there — so take the four entries from the JSON
  asset alone, never from the Go literal (§11).
  The `RUN` above would therefore fail outright on a bare Kinoite, and the `dms` RPM installs no
  policy file of its own, so without this one the build has nothing to read. `files.yaml` writes
  ```json
  {"policy_version": 1, "immutable_system": false, "blocked_commands": []}
  ```
  In that file, `immutable_system: false` is the operative key, not `blocked_commands`: the gate
  returns on it before it ever reaches the matching loop (`immutable_policy.go:257`,
  `if !policy.ImmutableSystem { return nil }`), so the empty list is belt-and-braces.
  The gate reads `/usr/share/dms/cli-policy.json` first, then `/etc/dms/cli-policy.json`
  (`immutable_policy.go:17-18`). Module order is the part that is easy to get wrong: `files` before
  `niri-config.yaml`, because that is the one module whose content depends on a file another module
  wrote. `sync` is **not** blocked upstream, so criterion 12b is untouched by this file. §4.14.
- **`/etc/environment.d/` takes `KEY=VALUE`**, one per line. Not KDL. A KDL block there is an
  unreadable file. Only `QT_QPA_PLATFORM` and `ELECTRON_OZONE_PLATFORM_HINT` use it — those are
  harmless under Plasma, unlike the theme variables below.
- **`portals.conf` is three keys, and the old form was a silent no-op.** Write exactly:
  ```ini
  # /etc/xdg/xdg-desktop-portal/portals.conf
  [preferred]
  default=kde
  org.freedesktop.impl.portal.Notification=plasmanotify
  org.freedesktop.impl.portal.Secret=kwallet
  ```
  Each key in a `[preferred]` group takes a **semi-colon-separated** list of backend implementations, so `default=kde` is the
  one-element case — a `:` there is the `XDG_CURRENT_DESKTOP` separator and matches no backend at all, which is why
  `default=kde:plasmanotify` did nothing. Measured
  on `xdg-desktop-portal-1.22.1` under `XDG_CURRENT_DESKTOP=niri` by counting the chooser's
  `Choosing …` fallbacks: absent → 10 to `gtk.portal`; the old form → 10; the first two keys → **0**. That count is the chooser's fallback tally for the ten interfaces it reports, and the third key is not among them — `Secret` is absent from that set, which is why the third key could be added without moving the number. The third key is load-bearing for a different reason: without it `Secret` resolves to nothing at all, silently (PLAN.md §4.2).
  The file is **not** optional: `kde.portal` is `UseIn=KDE` and `gtk.portal` is `UseIn=gnome`,
  neither matches `niri`, so without the preference every interface falls through to gtk and
  criterion 3 fails. §4.2, criterion 3.
- **`XDG_CURRENT_DESKTOP=niri` goes in a drop-in, and only there.** Not a judgement call: the
  `niri.kdl` that `dms setup headless` writes, and that §4.5 installs to `/etc/niri/` and the skel
  unchanged, already contains `environment { XDG_CURRENT_DESKTOP "niri"; }`
  (`core/internal/config/embedded/niri.kdl:137-139`) — but that is a **KDL `environment {}` block,
  not a unit environment**: it applies to what niri spawns, while `Environment=` in a drop-in sets
  the systemd unit's own environment, which is what criterion 26 reads. The global
  `environment.d` branch is not taken at all, because it leaks into the Plasma fallback where
  `niri` is wrong. Same unit-scoped reasoning as the theme variables. §4.7, §4.8, criterion 26.
- **The DMS binding and the two theme variables are five drop-ins, never fewer.** The theme
  variables must not be global: under Plasma they would force the gtk3 platform theme onto KDE's
  own apps. They go in **two** drop-ins, because *"systemd does not pass one unit's `Environment=`
  to a unit that it merely `Wants=` — a drop-in on `niri.service` alone would never reach DMS, nor
  anything DMS launches"* (§4.7). §4.8: **five files in total** — `kinrin-dms.conf` binds the unit,
  `kinrin-xdg.conf` carries `XDG_CURRENT_DESKTOP`, the two theme drop-ins set environments, and
  `kinrin-vrr.conf` starts `niri-vrr.service`; no single one of them does both jobs. Merging them is
  not the fix, and §4.7 is not superseded: there is no deviation to record. `files.yaml` owns all
  five — **and `/etc/environment.d/90-dms.conf` as well**, which carries only the two remaining keys
  (`QT_QPA_PLATFORM=wayland`, `ELECTRON_OZONE_PLATFORM_HINT=auto`) and none of the three variables
  above; criterion 26 still checks that the generator accepts that file.
  ```ini
  # /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf
  [Unit]
  Wants=dms.service
  Wants=graphical-session.target
  ```
  The second `Wants=` is robustness, not the mechanism: the upstream `niri.service` `BindsTo=`s
  `graphical-session.target`, and a `BindsTo=` pulls the target in the way a `Requires=` would, so
  this line only covers an RPM that patches the units. `dms.service` itself carries
  `Requisite=graphical-session.target` and fails outright when the target is inactive.
  ```ini
  # /usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf
  [Service]
  Environment=XDG_CURRENT_DESKTOP=niri
  ```
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
  `PartOf=niri.service` is what stops DMS with the session, and it is **not optional** — drop it and
  DMS outlives the compositor, so tearing down niri leaves an orphaned Quickshell process holding
  the DRM master. It is **not the only stop path, though**: `dms.service` already ships
  `PartOf=graphical-session.target` and the upstream `niri.service` `BindsTo=`s that same target, so
  the end of the session already stops DMS — the drop-in makes that stop unconditional rather than
  dependent on the session target being torn down in order, belt-and-braces against an ordering this
  plan does not control. Ship it anyway. It has to sit in the `dms.service` drop-in and not the
  `niri.service` one:
  `PartOf` is read by the unit that carries it, and putting it under `niri.service` would make
  *niri* stop when DMS does. This is a third reason the two units need separate drop-in files.
  Do **not** use `systemctl --user enable dms` instead of the `Wants=`: `enable` starts DMS in
  *every* session, and Plasma is a fallback here — DMS would then launch in the Plasma session
  too. With `Wants=` in place, there is **no autostart to remove**: the *deployer* never writes that
  string, because `dms setup` selects the systemd path for niri, so `transformNiriConfigForNonSystemd`
  — the only writer of `spawn-at-startup "dms" "run"` — is never reached (§4.8). Criterion 2d still
  *observes* the generated `config.kdl` for the absence of the node, which is a weaker statement
  than §4.8's: the file is produced by a path that cannot contain it, and the `RUN` copies it
  verbatim. Do **not** "fix" a string you think you should see — and record that disagreement
  (§4.8 vs criterion 2d) in `NOTES.md` rather than changing either side. Criterion 2d checks the
  *dependency*, not a string — and a
  duplicate want is expected rather than wrong, because DMS itself runs
  `systemctl --user add-wants niri.service dms` at runtime (`core/internal/distros/base.go:574`),
  on top of the drop-in we ship.
- **`include` must be `optional=true`.** A bare `include` to a missing file stops niri booting.
  §4.6.
- **Never `rm -rf /var/{log,cache,lib}/*`.** The glob hits `/var/lib/rpm` and destroys the RPM
  database, which makes the image unverifiable. §5.1 has the correct cleanup:
  ```bash
  dnf clean all
  rm -rf /var/cache/dnf /var/cache/yum
  ```
- **Never run `dnf update` during the build.** Kernel and bootloader do not behave well mid-build.
  §5.1.
- **Free runner disk first** (`rm -rf /opt/hostedtoolcache`). bootc images grow fast and GHCR
  times out at 10 minutes. §5.1.
- **`xwayland-satellite` and `steam-devices` must be declared explicitly.** `niri-26.04` already
  `Requires: xwayland-satellite >= 0.7` (verified, §4.0), so the first is redundant rather than
  needed — keep it anyway, so it survives a future niri relaxing it. `steam-devices` is the one
  genuinely missing: without it no gamepad is recognised and criterion 22 fails with no
  explanation.
- **`plasma-workspace` pulls `powerdevil`, which contests lid events with logind.** That is a real
  configuration decision, not a default: set **`HandleLidSwitch=suspend`** — that exact value; the
  other valid values (`poweroff`, `hibernate`, `ignore`) are all wrong here — in the drop-in
  `/etc/systemd/logind.conf.d/kinrin.conf` (owned by `files.yaml`), **not** in
  `/etc/systemd/logind.conf` — editing it directly is
  both a package-owned conflict and invisible to `systemctl` diffing. **Ship it with its section header**, because a
  setting written before any header is discarded and the file is then silently inert — while a grep for the value still
  passes:
  ```ini
  # /etc/systemd/logind.conf.d/kinrin.conf
  [Login]
  HandleLidSwitch=suspend
  ```
  Then confirm PowerDevil's own
  setting does not override it. Criterion 8b decides which of the two wins. §4.0, criterion 8b.
- **`danksearch` is not in the `install:` list.** §4.0 records it as a `Recommends:` of the `dms`
  spec that the `dnf` module pulls by default, from the second stanza the
  COPR ships by itself, `[coprdep:copr.fedorainfracloud.org:avengemedia:danklinux]`, or from Fedora —
  the repo that satisfied the transaction was not recorded, so treat the origin as unverified.
  Weak deps are **on by default** in the `dnf` module, so nothing needs setting. If you ever set it,
  the key is `install-weak-deps`
  (hyphens) inside `install:`; `install_weak_deps` is not in the schema and fails
  `bluebuild validate`.
- **The COPR pulls a second repo by itself** — `[coprdep:copr.fedorainfracloud.org:avengemedia:danklinux]`. You do
  not declare it; `dms-greeter` comes from it, and `danksearch` comes from it **or** from Fedora — the
  repo that satisfied the transaction was not recorded, so its origin is unverified and nothing turns
  on the answer.
- **Window rules do NOT go in `dms/alttab.kdl`.** The deployer preserves a non-empty file, but
  the running shell rewrites `layout.kdl`, `alttab.kdl`, `cursor.kdl` and `input.kdl` on a theme
  change — unconditionally for all but `alttab.kdl`, whose write is content-deduped, so unchanged
  content is not rewritten — and `outputs.kdl` on every output or refresh-rate change. **never write in
  `outputs.kdl`**, a rule there is destroyed silently. `binds.kdl` is the only included file it never
  rewrites, which is why the include lands in the **skel** `binds.kdl`: §4.5's `RUN` installs the
  *generated* file to both `/etc/niri/dms/` and the skel, and `files.yaml` authors only the skel
  `local.kdl` — there is no `binds.kdl` for `files` to write, and none should be. The `include` is not
  something you author: the §4.5 `sed 1i` prepends it to the **generated** `binds.kdl` as that `RUN` installs the same file to
  `/etc/niri/dms/` and the skel, so `files.yaml` owns `local.kdl` and nothing else. Authoring a `binds.kdl` holding only
  the include would suppress every default bind (`Mod+Space`, `Mod+N`, `Mod+Alt+L`), because the deployer skips a
  non-empty file. Put the rules in `/etc/skel/.config/niri/local.kdl` (§4.4). The `../` matters: an include resolves against the
  including file's directory and `binds.kdl` sits in `dms/`, so a bare `local.kdl` would fail loudly
  against a path nothing writes; `optional=true` is what makes a wrong path fail silently instead,
  which is why the path is a review obligation and not something `niri validate` can catch.
- **Seed `config.kdl` into the skel, not only `/etc/niri/`.** An include resolves relative to the
  including file's directory. Without a user-side `config.kdl`, `/etc/niri/config.kdl` reaches
  `/etc/niri/dms/colors.kdl` and niri never reads what matugen writes — the theme is applied and
  invisible. §4.5.
- **`settings.json` needs `"configVersion": 33`, not 31.** Omitted, DMS reads it as version 0 and
  runs the whole v0→v33 migration chain over the file at first start. `SettingsData.qml:24` carries
  `settingsConfigVersion: 33` as the authority, the chain tops out at
  `quickshell/Common/settings/SettingsStore.js:706`, and `31` then `33` are consecutive assignments,
  so an older number is a
  downgrade, not a harmless default. The value is a **dated reading, not a pin** — 33, read on 2026-09-30 — and under rule 2 the COPR
  serves `dms` at `:latest`, so **re-read `SettingsData.qml:24` from the installed `dms` before each build and change this one number if it
  moved**; a stale value is a downgrade, not an error. It is written into the skeleton at authoring time, because the §4.5 `RUN` runs after
  `files.yaml` has already written this file, so it cannot inject into it — do not try. Re-read
  the build does not do it for you. Write only non-default keys.
  §4.12.
- **The skel `settings.json` needs two more keys, both load-bearing.**
  `"customThemeFile": "/usr/share/dms-themes/dracula/theme.json"` with
  `"currentThemeName": "custom"` is what makes Dracula
  **apply at first login with nothing touched**, which criterion 34 requires — remove it and that
  criterion fails. Write **no** `currentThemeCategory`: the property carries its own literal default
  (`Theme.qml:42`, `"generic"`) and nothing binds it to the settings file — the stored value is read
  *into* the property only by `applyStoredTheme` (`SettingsData.qml:1288`), and the `switchTheme`
  it calls (`Theme.qml:1372-1409`) overwrites it to `custom` in memory — its persist at
  `Theme.qml:1402` is gated on `savePrefs`, which this call passes as `false`, so the skel key is
  shadowed, never rewritten. Either way a `"registry"`
  value there buys nothing and would only mislead you about the Settings grid. And `"matugenTemplateQt5ct": false` / `"matugenTemplateQt6ct": false` are **a
  precaution, not a proven fix**: they do default to `true`
  (`SettingsSpec.js:952` and `:955`), but the old justification — that the templates write
  `platform_theme=qt5ct` into the qtct config, a file-level setting that outranks
  `QT_QPA_PLATFORMTHEME=gtk3` — is **false**: `grep platform_theme` over the whole DMS tree (go,
  qml, toml, conf) returns nothing. Keep both `false` so no unexamined template runs against
  `QT_QPA_PLATFORMTHEME=gtk3`, and settle the outcome by observation: the §4.5 `niri-config.yaml`
  script is the post-build inspection, criterion 5 the human one. The separate skel
  copy under `themes/dracula/` is a *different* mechanism: it makes the theme selectable in
  Settings → Theme. §4.12.
- **`theme.yaml` must assert the theme's shape, not just download it.** It is `type: script@v2` partly
  because it fetches a URL, and partly because it runs
  `jq -e 'has("dark") and has("light") and (.dark.surfaceContainerLowest | type == "string") and (.light.surfaceContainerLowest | type == "string")'` on the result.
  The `files` module can do neither. Any exit code but 0 fails the build, which matters because the
  wrong copy of the file fails **silently** — DMS falls back to a default theme rather than
  erroring. Ship only `theme.json`: the previews are cosmetic, their registry paths are unverified
  offline (PLAN §4.12, "their registry paths are unverified offline"), and no command fetches them, so listing them would name files nothing
  creates. The module also carries the skel copy,
  `install -Dm444 /usr/share/dms-themes/dracula/theme.json /etc/skel/.config/DankMaterialShell/themes/dracula/theme.json`,
  and that half is **not** `files.yaml` work either: `files` writes paths out of the repository and
  cannot copy a file that a download in this layer produced. §4.12.
- **Take the theme from the plugin registry, branch `master`**, not from
  `dracula/dankmaterialshell` — the app-repo copy is missing `surfaceContainerLowest` and
  `surfaceContainerLow`. And a 404 from `raw.githubusercontent.com` on `.../themes/dracula/` is
  normal: `raw` cannot list a directory. §4.12.
- **Install nothing from the dracula organisation, and do not cite a licence for it.** Checked live
  against the GitHub API (§4.13): `dracula/kde` returns **404** — there is no GPL-3.0 KDE tree to avoid,
  and no `metadata.desktop` carrying `X-KDE-PluginInfo-License=GPLv3` exists anywhere to point at, so
  that citation is not available. `dracula/gtk` does exist, and `dracula/dracula-theme` ships per-app
  trees — `themes/gtk`, `themes/kate`, `themes/konsole`, `themes/qt5` and others — with no `themes/kde`.
  Theming is DMS + matugen only, which sidesteps the question, and the one
  dracula-derived file we ship is the registry `theme.json` — a JSON colour definition, not
  artwork. §4.13.

## Verification you can actually run

The plan's §8 is a human checklist for a real desktop — you cannot run most of it in CI. Do not
pretend otherwise. What you can and should gate on, in this order.

**That block is an excerpt, not a transcribable document** — exactly as §6.1 says of its own. It is a **YAML**
workflow shown with its shell spelled out: the structural lines (`env:`, `permissions:`, `- name:`, `uses:`,
`with:`, `if:`) are workflow YAML, while a bare command line like `bluebuild validate …` or `skopeo copy …`
is **shell, not YAML** — in a real workflow no bare command appears at job level, it only ever appears as the
value of a `run:` key. So a bare command line must become `- run: <command>` (or go under a `run: |` block when it
spans several lines), and the `#` lines are placement notes, not commands. Transcribed literally it parses as
neither bash nor a workflow. Assemble it: one `on:` trigger set, then the three jobs. Three keys sit at a specific scope and the block
is explicit about which: **`env:` once at workflow level**, not per job — all three jobs expand `${{ env.OWNER }}`
and `${{ env.REPO }}`, and the publish job's `skopeo copy` and `cosign sign` need them, so a job-scoped `env:`
would empty those expansions; the job-level **`if:` default-branch gate on the build and publish jobs** — a bare
workflow-level `if:` is a schema error, and without the gate on publish a `workflow_dispatch` from a feature
branch reaches a job that cannot find the image; and **`permissions:` on the publish job only**. Everything else
in the block belongs to whichever job the surrounding `#` note places it in.

```bash
# job 1 — pre-build validate, on every push as well as the schedule: it is the gate that keeps a
# bad recipe out of a 20-minute bootc build
#   on: { push: {}, schedule: {…}, workflow_dispatch: {} }
bluebuild validate  recipes/recipe.yaml
bluebuild generate recipes/recipe.yaml -o /tmp/Containerfile --registry ghcr.io --registry-namespace "${OWNER,,}"

# job 2 — build
bluebuild build -vv recipes/recipe.yaml --registry ghcr.io --registry-namespace "${OWNER,,}"

# job 2 and job 3 both start with this, or a workflow_dispatch from a feature branch tags the
# branch produces a tag the steps below never name, and they fail with "image not known":
#   if: github.ref == format('refs/heads/{0}', github.event.repository.default_branch)
# At WORKFLOW level, not job level: the build job's `podman save` expands $OWNER too, and a job-scoped
# env would leave it empty there. Both podman and skopeo reject an uppercase owner, and a GitHub login
# may carry one, so everything below lowercases with ${OWNER,,}.
#   env: { OWNER: "${{ github.repository_owner }}", REPO: "${{ github.repository }}" }
# The branch gate stays at JOB level on both jobs — a bare workflow-level `if:` is a schema error.
# job 2 — build, then hand the image to job 3: each job gets a FRESH runner, so podman storage
# does not travel with `needs: build`. Without this the publish job has no image to read.
# pipefail matters: without it the exit status is zstd's, so a failed `podman save` still yields a valid
# (empty) kinrin.tar and the publish job fails later with a confusing error instead of here.
set -o pipefail && podman save "ghcr.io/${OWNER,,}/kinrin:latest" | zstd -T0 > kinrin.tar   # then upload-artifact kinrin-image
# job 3 — publish. `packages: write` is required or the token cannot write the package, and
# without `skopeo login` the push is `unauthorized`:
#   permissions: { packages: write, contents: read }
# download-artifact, then `podman load -i kinrin.tar`, then:
#   skopeo login ghcr.io -u "${{ github.actor }}" -p "${{ secrets.GITHUB_TOKEN }}"
echo "tag=$(date +%F)" >> "$GITHUB_OUTPUT"                                                  # id: meta
skopeo copy --all "containers-storage:ghcr.io/${OWNER,,}/kinrin:latest" "docker://ghcr.io/${REPO,,}:latest"
skopeo copy --all "containers-storage:ghcr.io/${OWNER,,}/kinrin:latest" "docker://ghcr.io/${REPO,,}:${{ steps.meta.outputs.tag }}"
echo "digest=$(skopeo inspect --format '{{.Digest}}' "docker://ghcr.io/${REPO,,}:latest")" >> "$GITHUB_OUTPUT"   # id: digest — AFTER the push
test -n "${{ steps.digest.outputs.digest }}"   # never sign an empty or unresolvable reference
# the env var alone is NOT read by cosign: without --key env:// it falls back to keyless and fails.
# Put the key in the step `env:` block, NOT as an inline shell prefix — a generated cosign key is a
# MULTILINE PEM, and an unquoted `VAR=${{ … }} command` prefix splits at the first newline inside it.
- name: Sign
  env:
    COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
    # add COSIGN_PASSWORD here ONLY if the key is passphrase-protected, or the run blocks on a prompt
  run: cosign sign --yes --key env://COSIGN_PRIVATE_KEY "ghcr.io/${REPO,,}@${{ steps.digest.outputs.digest }}"

# gates on the built image, run in job 2
podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" niri validate --config /etc/niri/config.kdl
# the presence chain over the `files.yaml` destinations: the only check that sees a destination go missing
podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" sh -c 'test -f /etc/xdg/xdg-desktop-portal/portals.conf && test -f /etc/greetd/config.toml && test -f /etc/systemd/logind.conf.d/kinrin.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-dms.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/dms.service.d/kinrin-theme.conf && test -f /usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf && test -f /usr/lib/systemd/user/niri-vrr.service && test -f /etc/environment.d/90-dms.conf && test -f /usr/share/dms/cli-policy.json && test -f /etc/skel/.config/niri/local.kdl && test -f /etc/skel/.config/DankMaterialShell/settings.json'
podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" grep -qE '^ID="?kinrin"?$' /etc/os-release
podman run --rm "ghcr.io/${OWNER,,}/kinrin:latest" grep -qE '^ID_LIKE="?fedora"?$' /etc/os-release

# gate on the published image, so it can only run once job 3 has pushed
cosign verify --key cosign.pub "ghcr.io/${REPO,,}@sha256:<digest>"
```

The build-date tag is **computed in the publish job**, by the `id: meta` step, and consumed as
`steps.meta.outputs.tag` — `latest` plus that date, and never a hardcoded date, because the base is
not pinned and a frozen tag would name a build that no longer happens. The two step outputs belong to
that one job but are captured at **different** points: `steps.meta.outputs.tag` before the push, and
`steps.digest.outputs.digest` after it, so the sign step pins a digest it did not have to guess and
that the registry actually serves:
`steps.meta.outputs.tag` is `$(date +%F)` and `steps.digest.outputs.digest` comes from
`skopeo inspect`. The two `skopeo copy` calls read from `containers-storage:ghcr.io/<owner>/kinrin:latest` — the tag `--registry`/`--registry-namespace` pinned — the podman store, **not**
`docker://`, which is a *registry* reference and fails with `connection refused` there. The digest is the opposite case:
it is read back from the registry **after** the push, because `skopeo copy` rewrites the layers and the local manifest digest
is not the one the registry serves — signing that one fails with `manifest unknown`, and `--preserve-digests` is not an escape. The publish job does **not** share a runner with the build, so the image crosses as
an artifact (`podman save` + `upload-artifact`, then `download-artifact` + `podman load`); `needs: build`
only orders the jobs. Skip the load and `Publish` itself fails — there is no local image for `skopeo copy` to read, and the digest step is downstream and never reached. That is a different failure from an empty digest, which is the second guard: once past `Publish`, the job still asserts the digest is
non-empty before trusting the sign step. `skopeo copy` is the push and
nothing more: it carries the image, it does not sign it (§6.1). Every published reference is written
`ghcr.io/${{ github.repository }}` rather than
a literal `ghcr.io/<owner>/kinrin`, so the workflow resolves the owner itself; the `<owner>` form is
prose, never a line of the job.

The cosign public half is part of publication, not a later chore: the private key is the
`COSIGN_PRIVATE_KEY` secret and **the public half must be published beside the image**, because it
is what `cosign verify` checks and what the target machine needs at boot. `cosign.pub` is **committed
at the repository root** (§5) and the publish job checks the repository out, so `--key cosign.pub`
resolves as-is. Upload it as an artifact too, so the key travels with the release; there is no need to
write it out from a CI variable. Record where it ended up.

No `NOTES.md` entry is owed here: which stanza carries what is already settled, and §4.0 carries the
exact value. The COPR's `.repo` file ships a second enabled stanza,
`[coprdep:copr.fedorainfracloud.org:avengemedia:danklinux]`, you do not declare it, and
`dms-greeter` comes from that one rather than from the main `avengemedia/dms` stanza. §9's migration
issue tells the maintainer to drop the `copr` key, and §4.0 is where that loss is written down.

Wire `bluebuild validate` and `bluebuild generate` as a **pre-build job**, not after the build.
That is the whole point of `bluebuild validate`: a recipe typo must fail before you spend a
20-minute bootc build on it. Then the build, then `niri validate` and the `ID=kinrin` check as
post-build gates, then publish — the GHCR push, plus the `cosign verify` of §6.1 against the
pushed digest, with the published public key. PLAN
§8 sanctions four gates on the image — `bluebuild validate` and `niri validate` (criterion 28), the §6.1 policy read (criterion 28b), and the presence chain over the `files.yaml` destinations (criterion 28). The chain is the only check that can see a destination go missing: a `{source:}` entry with no `{destination:}` leaves `DEST` the literal string `null`, `cp -f` succeeds and the module exits 0, and `bluebuild validate` accepts that form because the schema types the list as `Array<Record<string>> | Array<{source; destination}>`.
This prompt adds two more that cost nothing and are required elsewhere in the plan: the
`ID=kinrin` check (§5) and `cosign verify` (§6.1). Ship all six.

`niri validate` is **not** runnable bare: the binary does not exist on a GitHub runner, and a bare
call would not see the image anyway. It has to run inside the image, against the file that
shipped.

`cosign verify` with no public key is not a check. Publish the cosign **public** key as an artifact
of the publish job — `--key` reads a file, not a variable — and verify against the pinned digest,
never a mutable tag.

Everything else in §8 is a manual criterion; keep §8 in the repo as the manual test plan and do not
convert it into fake automation. The `ID=kinrin` check above is the same requirement §5 states:
the image must not report itself as `fedora`.

## How to know you are done

- `bluebuild validate` passes, before the build, not after it.
- The image builds end to end from a clean runner.
- `niri validate` passes on the config that actually shipped in the image — run it inside the
  image, against `/etc/niri/config.kdl`.
- `/etc/os-release` carries **both** `ID=kinrin` and an `ID_LIKE` that still names `fedora`. The two
  keys are one change in the same `properties:` map of `os-release.yaml`, which runs **last of the
  eight** so `dnf` and `dms setup` still read `ID=fedora` (§3, §5.2). Checking `ID=kinrin` alone
  leaves the parent undeclared and every third-party repo that branches on it broken (§11).
- `/etc/niri/config.kdl` **and** `/etc/skel/.config/niri/config.kdl` are both in the image, so
  niri's includes resolve into the home where matugen writes (§4.5). `~/.config/niri/config.kdl`
  is not a path in the image — it is the per-user copy of the skel file at first login.
- `cosign.pub` is committed at the repository root and the `signing` module found it — without it the build dies at the **last** module, after 20 minutes (§5).
- Every `files.yaml` entry is a `source:`/`destination:` **pair**, and every source exists under `files/`: the bare single-key form copies each file to a path named `null` and still exits 0, so a green build can hold an empty image and no gate would notice (§5.2).
- The publish job declares `packages: write` **and** `contents: read`, and ran `skopeo login ghcr.io` before pushing — the push needs the first, the checkout needs the second (§6.1).
- The signing policy inside the image names the reference actually pushed — criterion 28b: `jq -r '.transports.docker | keys[]' /etc/containers/policy.json` prints the lowercased `ghcr.io/<owner>/<repo>`. A mismatch means the `signing` module keyed the policy from another name and boot-time verification resolves nothing (§6.1).
- The `build` and `publish` jobs both carry the default-branch gate. Without it a `workflow_dispatch` from a feature branch produces a tag the steps below never name, and they fail with `image not known`. §6.1 states the placement; the tag format itself is a BlueBuild behaviour to confirm, not a plan fact.
- The CI workflow runs green and the image is pullable from GHCR.
- `cosign verify --key cosign.pub "ghcr.io/${REPO,,}@sha256:<digest>"` passes against the
  published digest, with the public key actually present.
- `NOTES.md` records every ambiguity you resolved, and these entries are mandatory rather than
  optional:
  - the re-read of the thirteen `file:line` citations in §12.1 (eleven DMS rows, two niri rows),
    **from a fresh clone**, with the commit you read them at — a citation carried
    over unverified is the one thing the plan asks you not to do. Two of them are already pinned:
    the niri rows name `1f03391` (2026-09-25), and that tree is a real clone, so confirm the commit
    rather than trusting the hash. The greeter paths are the **named
    exception**: `dms-greeter.spec`, `greeter_install.go` and `installer.go` have no repository row
    in §12.1, because `dms-greeter.spec:16` carries
    `URL: https://github.com/AvengeMedia/dank-greeter` and that is a **candidate** read out of a
    spec field, not a verified identity. Say so in `NOTES.md` and do not invent a commit for them;
  - the commit of the **BlueBuild tree you built with**, against which you confirmed the three facts this plan asserts without a pinned commit: `cosign.pub` at the repository root (§5), the `files/` staging layout and its `null`-destination behaviour (§5.2), and `post_build.sh` clearing `/var` (§3.2). All three are build-fatal, so record the commit even though you did not read the plan's source;
  - the module `type:` majors you built against — the `script@v2` pin this rule 2 exception requires, and
    the BlueBuild commit you read it at. `script` is one of only two multi-major types in BlueBuild (the other
    is `default-flatpaks`, which this plan does not use), so a bare `type: script` would follow `latest`
    straight to a future `@v3` and change the shell from POSIX to whatever that major specifies, with no diff
    in your recipe to show for it;
  - which branch of the `dms-greeter` `%post` SELinux block actually ran, i.e. whether
    `test -x /usr/sbin/semanage && test -x /usr/sbin/restorecon` answered in the build image (§4.8).
    That two-tool guard (`dms-greeter.spec:113`) is redundant rather than a real branch, because
    the `Requires: policycoreutils-python-utils` at `dms-greeter.spec:26` is **hard** — so the
    answer is a confirmation, and `NOTES.md` should say that instead of leaving it open;
  - the two gates this prompt adds, and why each is there, **recorded with the plan's own
    inconsistency rather than smoothed over**: PLAN §8 ("the only automated checks on the image") calls `bluebuild validate`, `niri validate`, the presence chain over
    the `files.yaml` destinations (all three criterion 28) and the §6.1 policy read (criterion 28b) the only **four**
    automated checks. §6.1 adds
    `cosign verify` against the pushed digest. Six checks, four named in §8 (28 and 28b), one in §5, one in
    §6.1 — say that in `NOTES.md`, and say which four the plan sanctions as gates (criterion 28 and 28b)
    so the additions do not look like the plan's own list;
  - the disagreement between §4.8 and criterion 2d over the `spawn-at-startup "dms"` node: the
    *deployer* never writes it, and criterion 2d still *observes* the generated `config.kdl` for its
    absence. Record it as a divergence; do not edit either side to match.

If the build fails on something the plan does not cover, stop and write it in `NOTES.md` rather
than working around it silently. A documented gap is worth more than a quiet patch.

## What the plan leaves open

Eight things are genuinely undecided — these eight, plus the two **conditional** `NOTES.md` items the
plan already names in passing: the §6.1 greeter-theme divergence and the §4.5 `../local.kdl` path
obligation. Those two are not choices, they are obligations; record them and move on.

- **The first-user creation path** — the most consequential, because nothing in the image creates the
  session account. The base ships `plasmalogin` enabled and the recipe disables it, so no first-boot
  session setup ever runs, and the skel
  is the only way `config.kdl`, `binds.kdl`, `local.kdl`, `settings.json` and the theme reach a home.
  Criteria 2c, 4, 12b, 17, 23, 30 and 35 all need that user to exist — criterion 4 since it authenticates at each prompt, not merely counting them. Choose sysusers plus a first-boot
  service, or `dms-greeter`'s own path, and **record it in `NOTES.md`** (§4.5, §7, §10). Note that
  sysusers alone is not enough: it creates a home *without* copying `/etc/skel`, so it would apply
  none of the niri config and no theme. The greeter must not offer `builder`.
  **The account must land in `wheel`**, because that is polkit's `auth_admin` identity — the default
  rule is literally `return ["unix-group:wheel"]` (`/usr/share/polkit-1/rules.d/50-default.rules:11`) —
  and no first-boot path runs to grant it. Criterion 4 depends on this: the USB and NetworkManager actions are `auth_admin`, so a session user outside `wheel` cannot answer them — and criterion 4 authenticates at each prompt, not merely counts them, so an unanswerable prompt fails the criterion even though the count looks right. Use `usermod -aG wheel`, or a sysusers `groups=` key. `greeter` stays separate: it is the
  cache access §12b needs, and `dms-greeter sync` adds it itself.
- **`/etc/greetd/config.toml` ownership** (§10). The file is **package-owned** — the `greetd` RPM
  ships it, and the exact rpm flag is unconfirmed offline, so claim no `%config`/`%noreplace` — and
  greetd reads **no drop-in directory** (drop-ins are a systemd feature and this is a TOML file), so
  §7's "never edit a shipped file, add a drop-in beside it" is impossible here and the `files` module
  has to write the packaged file itself. This is the single exception in the whole plan. Its content
  is the `dms-greeter` `%post` template verbatim (§4.1), and determinism rests on the verified
  `%post` idempotence rather than on an rpm flag: `:198` creates the file only when absent, `:211`
  updates one that does not already mention `dms-greeter`, `:212-213` is the backup. Because `files.yaml`
  runs after `dnf.yaml` it is the last writer, so a rebuild is deterministic. Nothing to decide at
  run time; know it, and do not "fix" it by adding a drop-in that greetd would ignore.
- **License**: **OPEN** (§10, "before publication"), and the `LICENSE` file is a deliverable for it.
  Do not hard-code a single SPDX id. The image
  bundles GPL-2.0 (Fedora), GPL-3.0-or-later (niri), MIT (DMS) and the registry `theme.json`, for
  which the source repository declares **no licence** — so it cannot be filed under MIT and needs
  its own line — and
  `GPL-2.0-only` is **not** a valid umbrella: it cannot cover niri's `GPL-3.0-or-later`. Either pick
  a licence that covers the whole set or publish per-component notices. §4.13 is already settled on the dracula
  question and should not be re-argued: the only dracula-derived artefact is the registry `theme.json`,
  it declares no licence, and no dracula directory is installed, so there is nothing to enumerate.
  Either way, record the choice and the reason in `NOTES.md`.
- **Which key signs** (§10). §6.1 gives the mechanics and the plan has read the source of none of
  them; the name agreed on is the CI secret **`COSIGN_PRIVATE_KEY`**, read as an environment
  variable by the `cosign sign` step of the publish job. Generating the key pair is a prerequisite
  of the **first publication**, not a build step, and the public half must be published beside the
  image — the public key is what `cosign verify` runs against, and it is what the target machine
  needs. Decide before first publication.
- **Repository name vs the recipe `name:`** (§6.1, before the first build). The `signing` module keys its in-image policy from the recipe `name:` plus the build registry, so the policy covers `ghcr.io/<owner>/kinrin` while the workflow pushes to `ghcr.io/<owner>/<repo>`. If the two differ, boot-time verification of the published image resolves nothing and §6/§7's `bootc switch` names an image never pushed. Either name the repository `kinrin`, or set the recipe `name:` to the repository name; record it in `NOTES.md` and check criterion 28b.
- **`ID=kinrin` in `os-release`** (§10). §5 sets it and §11 lists the risk, but no §8 criterion
  observes it. The only check is the post-build gate this prompt adds, and it is **both** greps —
  `^ID="?kinrin"?$` **and** `^ID_LIKE="?fedora"?$`, because an `ID` with no `ID_LIKE` declares no parent. What stays
  unmeasured is the upgrade side: `--releasever` resolution for third-party repos and the rpm-ostree path
  across the rename. Decide before the first upgrade cycle; do not change it in passing.
- **`libva-intel-media-driver`** needs confirming on the target Intel GPU (criterion 15).
- **The `extest` preload** is only needed if criterion 22 reproduces a Steam crash on gamepad
  connect. Do not ship it speculatively. If criterion 22 does reproduce it, apply it **host-side**: the overlay is
  `/usr/local/share/applications/steam.desktop` — the RPM's launcher is in `/usr/share/applications/`, which that directory
  precedes in `$XDG_DATA_DIRS` — but on Atomic `/usr/local` is a symlink to `/var/usrlocal`, so it is machine state under `/var` — the persistence
  §3.2 relies on — and nothing needs redoing after a `bootc switch`; a library under `/usr/lib64` is what a switch
  would wipe. Clone the shipped entry and edit its `Exec`, never a stub. Host-side only: do not bake it into the image
  or read it as part of one.

Cosign is **mechanics per §6.1, unverified by the plan**: the `signing` module is said to
contribute the verification policy, the private key is a CI secret that never enters the image,
the signature is produced at publish over the pushed digest, and the public key is published and
used to verify it. Keep `- type: signing` **last** in `modules:`, so the policy it installs is
layered over an image that already contains everything. The plan has read the source of none of
that, so treat it as a shape to
implement, not a settled reading: **inspect the policy in the built image** and report what the
inspection printed, and do not invent an enrollment procedure on top of it.

One more is a **conditional branch, not an open question** — take the stated branch and record it:
`DMS_DISABLE_MATUGEN` (§4.12). The greeter no longer poses this question at all: `dms-greeter sync`
symlinks the theme into `/var/cache/dms-greeter/`, so the greeter renders Dracula without ever
running matugen, and there is nothing to disable.

The README is the place the §6 and §7 procedures surface, so point it at both sections by name:
**§6** for publication — the two GHCR tags (`latest` and the build date, both pushed, the date
computed in the publish job), the 10 GB per layer and 10-minute upload limits, and where the cosign
**public** half ended up — and record the build's date tag in `NOTES.md` at build time, so §7's rollback can find the digest of the build you are leaving — and **§6** for the two `bootc switch` forms (`:latest` for discovery,
`@sha256:<digest>` for a reproducible install) and **§7** for rollback — `bootc rollback` and its
`--apply` caveat, the timer, and the
10 GB budget that keeps two deployments. Three of them are easy to leave out:
the two `bootc switch` forms — `:latest` for discovery, `@sha256:<digest>` for a reproducible
install, because no tag designates a stable image across builds; the
`bootc-fetch-apply-updates.timer` that must be disabled before a `bootc rollback`, or the next
reboot reverts the rollback; and the fact that the **GHCR package must be made public explicitly**,
since GHCR creates it private.

Everything else is decided: every decision outside this section is settled, and the eight above are
the only open list — the two conditional `NOTES.md` items above are obligations, not open questions.
Do not relitigate the rest.
