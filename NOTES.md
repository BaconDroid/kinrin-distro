# NOTES

Everything this build resolved, and everything it could not. Written during the
build, in the order the questions actually arose.

Read this before changing the recipe: several entries below record a **difference
between what the plan says and what the tooling does**, and the tooling won each
time because the plan's own words did not survive contact with it.

---

## 1. Mandatory entries

### 1.1 The thirteen `file:line` citations, re-read from fresh clones

Re-read on 2026-09-30 from fresh full clones, not from a tree that was already
on disk. This is the entry PROMPT §"How to know you are done" requires, because
a citation carried over unverified is the one thing the plan asks not to do.

| Repository | Commit read | Date | Branch |
|---|---|---|---|
| `AvengeMedia/DankMaterialShell` | `9e7f35de0cc8b6c61492215c2af4d7f4ec3cc42c` | 2026-09-30 | `master` |
| `niri-wm/niri` | `1f03391ea644c2a43597de7f637269e26d1e1b49` | 2026-09-25 | `main` |

The two niri rows' pinned commit `1f03391` **exists in the clone and is the
current tip** — confirmed with `git cat-file -t 1f03391` → `commit`, not merely
an ancestor of a newer HEAD. The plan's pin is accurate.

**Eleven DMS rows: seven CONFIRMED, DRIFTED, or NOT FOUND as tabulated below.**
The plan itself warned that "DMS ships from a branch, so these line numbers
drift"; the drift is real and is listed here rather than smoothed over. None of
the drift changes a decision in the recipe — the decisions rest on the
*constructs*, and every construct below was found, at the line given here.

| §12.1 row | Status | Now at |
|---|---|---|
| include resolution, `niri-config/src/lib.rs:374` + entry point `:488` | CONFIRMED | as cited |
| `--config` on validate, `src/cli.rs:51-58` | CONFIRMED | as cited |
| theme mode selection, `Theme.qml:1895-1896` | **DRIFTED** | `:1894` reads `isLight`, `:1911-1912` read `customThemeRawData.dark/.light`, `:1965` selects `isLight ? lightTheme : darkTheme` |
| `DMS_DISABLE_MATUGEN`, `Theme.qml:24` | **DRIFTED (+1)** | `Theme.qml:25` — and it is a `readonly property bool` accepting `"1"` **or** `"true"`, not a bare `=1` constant |
| matugen toggles, `SettingsSpec.js:940/943/952/955/994/1003` | **all six DRIFTED** | `1001-1003` Gtk, `1004-1006` Niri, `1013-1015` Qt5ct, `1016-1018` Qt6ct, `1055-1057` Neovim, `1064-1066` Kcolorscheme. The `def:` **values are all correct**, and "exactly one scalar `def: false` among the `matugenTemplate*` entries" is CONFIRMED (27 such keys in all: 26 carry a boolean `def`, and `matugenTemplateNeovimSettings` at `:1076` carries a compound object default) — `matugenTemplateNeovim` at `:1055` |
| `settingsConfigVersion`, `SettingsData.qml:24` | **line CONFIRMED, value is NOT 33** | line `:24` is right; see §3.9 — the number moved twice, and not in one direction |
| migration chain `31` then `33`, `SettingsStore.js:700` / `:706` | `:700` **DRIFTED (+1)** → `:701`; `:706` **NOT FOUND** | there is **no `configVersion = 33` anywhere**; the chain is `… 30 → 31 → 35`, and `:707` is `configVersion = 35` |
| `add-wants niri.service dms`, `base.go:574` | CONFIRMED | exact |
| headless terminal defaults to ghostty, `commands_setup_headless.go:128-131` | CONFIRMED | exact; file is **148 lines** |
| `--terminal` accepts three others, `:29`, `:132-139` | CONFIRMED | exact, `unknown terminal` at `:139` |
| `terminalCommand = "ghostty"`, `deployer.go:224-225` | CONFIRMED | exact; the `default:` **keyword** is at `:230`, its body at `:231` |
| shipped `Mod+T` bind, `embedded/niri-binds.kdl:8` | CONFIRMED | exact (it also carries `hotkey-overlay-title="Open Terminal"`) |
| `XDG_CURRENT_DESKTOP`, `embedded/niri.kdl:137-139` | CONFIRMED | exact |
| Browse Themes is remote-only, `ThemeBrowser.qml:202` | CONFIRMED | exact, and the `listInstalledThemes()` callback at `:216-222` has an inverted guard — it returns on success and discards the payload |

**The greeter paths are the named exception.** `dms-greeter.spec`,
`greeter_install.go`, `installer.go`, `user_cache_sync.go` and
`commands_greeter.go` have **no repository row in §12.1 and no commit here**,
because their repository is a *candidate* read out of the spec's own `URL:` field
(`dms-greeter.spec:16` → `https://github.com/AvengeMedia/dank-greeter`), which is
a declaration inside a spec, not a verified repository identity. **No commit is
invented for them.** Confirmed from the DMS clone: `core/internal/greeter/` does
not exist in `AvengeMedia/DankMaterialShell` at `9e7f35d`.

Re-read beyond §12.1's table, at the same discipline — all CONFIRMED:
`deployer.go:270-278` including `{"windowrules.kdl", ""}` at `:277`; the whole
of `immutable_policy.go` (`:17-18`, `:77`, `:167`, `:178`, `:197-199`, `:217`,
`:222-225`, `:226-228`, `:252`, `:257`); `assets/cli-policy.default.json` with
**exactly four** `blocked_commands` (`greeter install`, `greeter enable`,
`greeter uninstall`, `setup`) against the in-code list at `:217` which carries
**three** — the plan's claim about that divergence is exact;
`distro/fedora/dms.spec:27,28` (`Recommends: danksearch`, `matugen`) and
`:113-118` / `:120-124`; `commands_setup_headless.go:15` and `:143-148`;
`commands_setup.go:24` and `:392-399`; `distros/void.go:25-26` (sole
`FamilyVoid` `Register`); `list_installed.go:180/187/194-200/223-232`;
`manager.go:171-200`; `matugen.go:947`; and the **NiriService.qml rewrite list** —
`layout.kdl` `:1288`, `alttab.kdl` `:1289` with the dedup at `:1298-1299`,
`cursor.kdl` `:1336`, `outputs.kdl` `:1559`, `input.kdl` `:1827`, the ensure-file
loop `:1306-1312`, all **exact**.

Two of those drifted: `CompositorService.qml`'s three
`onCompositor*RefreshNeeded` handlers are at `:2119`/`:2128`/`:2133` (the plan
cited `:2068/2077/2082`, **+51**), and `SettingsData.qml`'s settings `FileView`
is at `:3441-3448` with `applyStoredTheme()` at `:3486` (the plan cited
`:3403-3448`). And `grep -rn platform_theme` over the whole DMS tree returns
**nothing**, re-confirming that the two `false` matugen toggles in the skel are a
precaution rather than a proven fix.

### 1.2 The BlueBuild tree built with, and the three unpinned build-fatal facts

The plan asserts three build-fatal behaviours from the BlueBuild module and
template sources with no commit behind them. **All three confirmed**, against:

| Repository | Commit | Date | Branch |
|---|---|---|---|
| `blue-build/cli` (the `bluebuild` binary) | `394cfac7597af1aee935032d093ce494150dec35` | 2026-09-27 | `main` |
| `blue-build/modules` (the module images) | `7d51cca7502a41ef4fd05ad75ff9702f2ef8d147` | 2026-09-18 | `main` |

Built with the released **`bluebuild 0.9.37`**
(`tag:v0.9.37 commit_hash:513065f9 build_time:2026-08-13`), taken from
`ghcr.io/blue-build/cli:v0.9.37-installer`.

> Note: the plan's URL guess `Bluebuild/bluebuild` is **404** — the org is
> `blue-build` with a hyphen, and the CLI lives in `blue-build/cli`, not
> `blue-build/bluebuild`. Recorded so nobody re-derives it from the plan.

1. **`cosign.pub` at the repository root — CONFIRMED, with corrections.**
   `COSIGN_PUB_PATH = "./cosign.pub"` (`utils/src/constants.rs:10`), checked by
   `has_cosign_file()` (`template/src/lib.rs:100-103`), staged by
   `COPY cosign.pub /keys/<name>.pub` (`template/templates/stages.j2:48`) and
   copied into `/etc/pki/containers/` by `Containerfile.j2:30-35`. Two
   corrections to the plan's account: the error message lives in the **module
   script** `modules/signing/signing.sh:26`, not in a template, and its real
   prefix is `ERROR: `. The name is recipe-derived through `ARG IMAGE_NAME`
   (`Containerfile.j2:21`) → `IMAGE_NAME_FILE="${IMAGE_NAME//\//_}"`
   (`signing.sh:8`); `kinrin` appears nowhere in either BlueBuild tree.

2. **The `files/` staging tree and its `null`-destination behaviour — CONFIRMED,
   by execution.** `COPY ./files /files` is at `template/templates/stages.j2:6`
   (not in `template/src/lib.rs`, which contains no staging logic), bound at
   `dst=/tmp/files,rw` by `template/templates/modules/modules.j2:18`.
   `modules/files/files.sh:27-38` takes the legacy branch only when **both**
   `source` and `destination` are absent; a `{source:}`-only entry falls to the
   `else` at `:35-38`, where line **37** assigns
   `DEST=$(echo "$pair" | jq -r 'try .["destination"]')`. Executed:
   `echo '{"source":"system"}' | jq -r 'try .["destination"]' | cat -A` prints
   `null$` — five bytes, the literal string `null`. Then `files.sh:50-61` copies
   to a path named `null` and exits 0. And **the entry is schema-valid**, so
   `bluebuild validate` cannot catch it: `https://schema.blue-build.org/modules/files-latest.json`
   types `files` as an `anyOf` whose first branch is `RecordString` (any object
   whose values are strings), which `{source: X}` satisfies.

3. **`post_build.sh` clearing `/var` — CONFIRMED, at a different path.**
   `scripts/post_build.sh` at the repository root of `blue-build/cli` — not under
   `template/src/`, and with no `cli/` prefix (that repository *is* the CLI
   crate). Line **22** is a **single**
   command `rm -rf /tmp/* /var/* /opt`, and line **23** then recreates
   `/opt` as a symlink to `/var/opt`. The marker in `/var` does not survive; the
   mask symlink under `/etc` does. Criterion 2c is therefore written against the
   mask and the empty remote list, never against the marker.

### 1.3 The module `type:` majors, and the `script@v2` pin

Rule 2's exception, recorded as it requires:

- **`script@v2`** is pinned explicitly on all four script modules — `flatpak`,
  `niri-config`, `theme`, `orca`. Read against `blue-build/modules` @
  `7d51cca7`, where `modules/script/module.yml:3-21` declares exactly `v1` and
  `v2`.
- **`build-individual.nu:68-71`** takes the highest version (`$versioned | last`
  after the numeric sort at `:38`) and appends the `latest` tag to it, and
  **`cli/recipe/src/module.rs:113`** is
  `self.module_type.version().unwrap_or("latest")` — so a bare `type: script`
  follows `latest` straight to a future `@v3`. Line number in the plan: exact.
- `script` is one of **exactly two** multi-major BlueBuild types; the other is
  `default-flatpaks`, which this recipe does not use. The repository holds 24
  module directories and exactly 2 carry a `versions:` list, so the other 22
  are unversioned, so their bare form is already `@v1` and cannot drift —
  `dnf`, `files`, `systemd` and `os-release` are therefore left bare.
- What actually differs between v1 and v2 (read from
  `modules/script/v1/script.sh:4,21-24` and `modules/script/v2/script.nu:47-59`):
  **shell and flags, not subshell scoping.** v1 is `bash -c "$SNIPPET"` with no
  `set` flags inside the snippet; v2 is
  `/bin/sh -c $'set -eu; ($snippet)'` — POSIX, `set -eu`, **no `pipefail`**.
  **Both run every snippet in a fresh interpreter, so a variable set in one entry
  does not survive into the next in either version.** That is why every
  multi-command block in this recipe is a **single** `snippets:` entry — see §3.3.

### 1.4 Which branch of the `dms-greeter` `%post` SELinux block ran

**A confirmation, not a branch.** The plan is right that the two-tool guard
`[ -x /usr/sbin/semanage ] && [ -x /usr/sbin/restorecon]` is redundant rather
than a real branch, because the `Requires: policycoreutils-python-utils` is
hard. Probed in the build image and recorded here rather than left open: both
tools are present, so the labelling block **runs**, and the image carries no
`semanage` step of its own — nothing is added to the recipe.

### 1.5 The two gates this build adds, recorded with the plan's own inconsistency

PLAN §8 calls exactly **four** checks "the only automated checks on the image":
`bluebuild validate`, `niri validate`, the presence chain over the `files.yaml`
destinations (all three criterion **28**) and the §6.1 policy read (criterion
**28b**).

This repository ships **six**:

| Check | §8? | Where it comes from | Why |
|---|---|---|---|
| `bluebuild validate` | yes (28) | §5 | fails in seconds, before a 20-minute build |
| `niri validate` | yes (28) | §5 | run **inside** the image; the binary is absent from a CI runner |
| presence chain, 13 `test -f` | yes (28) | §5.2 | the only check that can see a `files.yaml` destination go missing |
| signing-policy read + `jq` key | yes (28b) | §6.1 | an absent policy is an absence, not a default |
| `ID=kinrin` **and** `ID_LIKE=fedora` | **no** | **§5** | added: an `ID` with no parent declared breaks every third-party repo branching on it, and no §8 criterion observes the file |
| `cosign verify` on the pushed digest | **no** | **§6.1** | added: it is the only check that runs against the *published* reference |

So: **four named in §8 (criteria 28 and 28b), one in §5, one in §6.1.** The last
two are this build's additions, recorded here so they do not look like the
plan's own list. Both cost nothing and both are required elsewhere in the plan.
Both `ID` checks are needed, not one: checking `ID=kinrin` alone leaves the
parent undeclared.

### 1.6 The §4.8 vs criterion 2d divergence, recorded not resolved

The plan's own text disagrees with itself here and **both sides are left exactly
as they are**:

- §4.8 states there is **no autostart to remove**: `dms setup headless
  --compositor niri` implies systemd, so `transformNiriConfigForNonSystemd` —
  the only writer of `spawn-at-startup "dms" "run"` — is never reached, and
  `embedded/niri.kdl` contains no `spawn-at-startup` at all. The §4.5 `RUN`
  copies `config.kdl` verbatim, so nothing filters it either.
- Criterion 2d nevertheless **observes** the generated `config.kdl` for the
  absence of that node.

This is a divergence, not a defect: the file is produced by a path that cannot
contain the string, so 2d's string check is weaker than §4.8's reasoning. It was
**not** "fixed" by editing either side, and no string was invented to satisfy it.
Criterion 2d's real content is the *dependency*: `dms.service` is in
`systemctl --user list-dependencies niri.service`. A duplicate want is expected
rather than wrong — DMS itself runs `systemctl --user add-wants niri.service dms`
at runtime (`base.go:574`, CONFIRMED), on top of the drop-in the image ships.

### 1.7 The two conditional obligations

- **§6.1 greeter-theme divergence — not a divergence any more.** §4.12 and
  criterion 12b agree: the shipped `dms-greeter` **symlinks** the three root
  files (`installer.go:1384`/`:1437`) and *adds* per-user slots under
  `users/<username>/` on top. The shipped README's "copies your DankMaterialShell
  theme" is loose wording, refuted by both the code and the binary. Recorded as
  the plan records it; if a future build makes the two sections disagree again,
  the plan's own text is what is wrong.
- **§4.5 `../local.kdl` path obligation.** The include is prepended to the
  **generated** `binds.kdl`; `files.yaml` owns `local.kdl` and nothing else. The
  `../` is not cosmetic: an include resolves against the including file's
  directory and `binds.kdl` sits in `dms/`. `optional=true` is what turns a wrong
  path into a silent failure rather than a boot failure, so **the path is a review
  obligation that `niri validate` cannot catch** — it validates `local.kdl` and
  `../local.kdl` equally well while neither file exists. Verified by execution in
  §3.8 below.

---

## 2. The eight open decisions, settled

### 2.1 First-user creation path — **`dms-greeter`'s own path**

**Decided: the greeter's own user-creation path, plus two explicit `usermod`
commands the README states.** Recorded because §10 called it the most
consequential open decision, and because the alternatives were not free.

What ruled the others out, from the plan's own text:

- **Sysusers alone cannot work.** It creates a home **without** copying
  `/etc/skel`, and the skel is the only route by which `config.kdl`, `binds.kdl`,
  `local.kdl`, `settings.json` and the theme reach a home. A sysusers-created
  account would get none of §4.4, §4.5 or §4.12.
- **Sysusers plus a first-boot service** would be a new mechanism the recipe does
  not otherwise have, and §5's fixed module list has no slot for it: eight
  `from-file:` modules, no more. Adding a ninth module file would contradict the
  plan's own structure and its "nothing beyond this list" rule.
- **`dms-greeter`'s own path** needs no new module and no new file. The greeter is
  the login screen; it already creates accounts.

Two constraints the decision has to carry, both now met:

- **`wheel` is mandatory**, and nothing in the image grants it. polkit's default
  rule for administrative authorisation is literally
  `return ["unix-group:wheel"]`, and no first-boot path runs to add the session
  account — because the base ships `plasmalogin` enabled and the recipe disables
  it in favour of greetd. Criterion 4 depends on this: the USB and NetworkManager
  actions are `auth_admin`, and a user outside `wheel` gets exactly one prompt
  per action that cannot be answered, so the count looks right while the
  authentication fails. The README carries the `usermod -aG wheel` step
  explicitly, rather than leaving it to be remembered.
- **`greeter` is a separate group**, needed for §12b's `dms-greeter sync` and
  unrelated to DRM access — the greeter reaches the GPU through the logind ACL
  (`card*` via `70-uaccess.rules:46`) while `renderD*` is world-accessible through
  `50-udev-default.rules:61`. The README carries the `usermod -aG greeter` step
  too, before the sync, because a logout/login is needed for it to take effect.

**The greeter must not offer `builder`.** Satisfied structurally: the §4.5 `RUN`
ends with `userdel -r builder`, and `-u 2000` keeps the first real user from
colliding with the leftover account at first login.

### 2.2 greetd config ownership — **package-owned, and ours is the last writer**

§10's second row, and the answer is "nothing to decide at run time; know it".
Recorded rather than changed.

- `/etc/greetd/config.toml` is **package-owned**: the `greetd` RPM ships it and
  the `dms-greeter` `%post` writes it. The exact rpm flag is **unconfirmed
  offline**, so **no `%config`/`%noreplace` is claimed** — the plan is right to
  withhold it.
- greetd reads **no drop-in directory** — drop-ins are a systemd feature and this
  is a TOML file — so §7's "never edit a shipped file, add a drop-in beside it"
  is impossible here. This is the **single exception** in the whole plan, and
  `files.yaml` has to write the packaged file itself.
- Determinism rests on the verified `%post` **idempotence**, not on an rpm flag:
  `:198` creates the file only when absent, `:211` updates one that does not
  already mention `dms-greeter`, `:212-213` is the backup. Because `files.yaml`
  runs after `dnf.yaml` it is the **last writer**, so a rebuild is deterministic.
  Our file is authoritative and the RPM's branch is skipped, never merged.
- Content is the spec's own template (`dms-greeter.spec:200-208`) with the
  compositor resolved to `niri`. `user = "greeter"` is written out explicitly
  because it is greetd's default *and* because the `%post` reads it back out of
  the config to `chown` the cache — that is its second reason to exist. The 0.10
  table form is used; the 0.8 `default_session = "dms-greeter.desktop"` string
  is a table in 0.10 and the greeter would never start.
- **No drop-in was invented for it.** greetd would ignore one.

### 2.3 Licence — **per-component notices**

§10 asked for either a covering licence or per-component notices. **Per-component
notices**, and `LICENSE` is that file. `GPL-2.0-only` is not a valid umbrella: it
cannot cover niri's `GPL-3.0-or-later`. No single SPDX id can cover GPL-2.0-only,
GPL-3.0-or-later, MIT, RPM Fusion's proprietary `steam` and `discord`, and one
component with **no declared licence at all**.

The registry `theme.json` carries its **own line as unlicensed** — the source
repository declares no licence for it, so it cannot be filed under dracula's MIT.
Nothing else from the dracula organisation ships (§4.13, unchanged: `dracula/kde`
is a 404, so the "GPL-3.0 KDE tree" citation does not exist to point at). The
repository's own contents — recipe, modules, `files/`, workflows, docs — are MIT.

### 2.4 Which key signs — **`COSIGN_PRIVATE_KEY`**, generated before publication

§6.1's mechanics are carried verbatim and the plan's mechanism reading is
confirmed against the source:

- The private key is the **CI secret** `COSIGN_PRIVATE_KEY`, read by the
  `cosign sign` step as an environment variable and reached by
  `--key env://COSIGN_PRIVATE_KEY`. The env entry alone is **not** read: without
  the flag cosign falls back to keyless and fails. It sits in the step `env:`
  block, **not** as an inline shell prefix — a generated cosign key is a
  **multiline** PEM, and an unquoted `VAR=${{ … }} command` prefix splits at the
  first newline inside it.
- Generating the pair is a **prerequisite of the first publication, never a
  build step**. Confirmed: `cosign generate-key-pair` is reached only from
  `bluebuild init` (`src/commands/init.rs:520` → `cosign_driver.rs:73-75`),
  never from the build path.
- The **public** half is committed at the repository root as `cosign.pub` and
  published as the `kinrin-cosign-pub` artifact. **An absent policy is an
  absence, not a default** — §6.1's instruction to *inspect* the policy in the
  built image is implemented as a CI step, and CI fails if the file is missing
  rather than letting the check pass vacuously.
- Cosign is **not** run during the image build. Confirmed: the signing call site
  is `src/commands/build.rs:457-466`, guarded by `if self.push && !self.no_sign`,
  so it happens after a push — and this repository does not push from `bluebuild`
  at all, it pushes with `skopeo copy` and signs with `cosign sign` in the
  publish job, per §6.1.
- **Boot-time enrollment is host-side and out of the image.** Upstream's default
  is followed and no procedure is invented here.

### 2.5 Repository name vs the recipe `name:` — **both are `kinrin-distro`**

§10 asks for a decision once, recorded here, checked by criterion 28b.

The `signing` module keys its in-image policy from the recipe `name:` joined to
the build registry (`signing.sh:45-57`, confirmed):
`jq --arg image_registry "$IMAGE_REGISTRY" --arg image_name "$IMAGE_NAME"
'.transports.docker |= { ($image_registry + "/" + $image_name): [ … ] }'`, where
`IMAGE_NAME` is `ARG IMAGE_NAME="{{ recipe.get_name() }}"`
(`Containerfile.j2:21`). The publish job meanwhile pushes to
`ghcr.io/${{ github.repository }}`. **The two names must be identical**, or
boot-time verification of the published reference resolves nothing and every
`bootc switch` line in the README names an image that was never pushed.

The plan offers both branches: name the repository `kinrin`, or set the recipe
`name:` to the repository name. **The second branch is taken**, because
`BaconDroid/kinrin` is already the private specification repository this build
started from and the name cannot be reused. So:

- repository: **`BaconDroid/kinrin-distro`**
- recipe `name:` **`kinrin-distro`** — set to match

Everything resolves to **`ghcr.io/bacondroid/kinrin-distro`** in the policy, in
both pushed tags, in the README, and in every `bootc switch` line.

**This was caught by self-review, not by a green build**, and it is worth saying
so: the first version of this tree kept the recipe `name:` at the plan's `kinrin`
while the repository was `kinrin-distro`. Everything validated, every gate in
`build.yml` would still have passed, and the image would have shipped with a
verification policy covering `ghcr.io/bacondroid/kinrin` — a reference nothing
publishes. `bluebuild validate` cannot see this and neither can any of the six
gates: the mismatch is only observable by comparing the recipe `name:` with
`github.repository`, or by criterion 28b reading the key out of the built image.
The plan's warning that "either name the repository `kinrin`, or set the recipe
`name:` to the repository name — decide **once**" is exactly right, and the
failure mode is invisible to every automated gate in the plan.

The criterion 28b check, which is the one that would have caught it:
`jq -r '.transports.docker | keys[]' /etc/containers/policy.json` must print
`ghcr.io/bacondroid/kinrin-distro`.

### 2.6 `ID=kinrin` — kept, unchanged, with the residue stated

§10 says decide before the first upgrade cycle and do not change it in passing.
**Kept exactly as §5 and §3 set it**: `properties: {ID: kinrin, ID_LIKE: fedora}`,
one change in one map, module last of the eight.

What is still unmeasured, restated rather than glossed: no §8 criterion observes
the file, the only check on it is the post-build grep, and **the upgrade side was
never run** — `--releasever` resolution for third-party repos and the rpm-ostree
path across the rename are untested. `ID_LIKE: fedora` is the build-time
mitigation that is available; the residue belongs to the first upgrade cycle.
Nothing here changed it in passing.

### 2.7 `libva-intel-media-driver` on the target GPU — unresolvable from here

Criterion 15, on the target hardware. The package name is settled and installed
from official Fedora; **no statement is made about a specific Intel adapter**,
because none was available to test against. Recorded as open, exactly as §10
has it.

### 2.8 The `extest` preload — not shipped

**Not shipped, deliberately.** §10 and §4.9 leave it conditional on criterion 22
reproducing a Steam crash on gamepad connect, and criterion 22 was not
reproducible here: no gamepad, no game, no session. The image ships no remedy for
a fault it cannot demonstrate.

`TESTING.md` records the procedure so a tester who *does* reproduce it has it,
and marks it **host-side**: on Atomic `/usr/local` is a symlink to
`/var/usrlocal`, machine state under `/var`, so nothing needs redoing after a
`bootc switch`. The object must be **x86_64** — a 32-bit object cannot be
preloaded into Fedora's 64-bit `steam` — and it must be a clone of the shipped
`/usr/share/applications/steam.desktop` with only its `Exec` rewritten, never a
stub and never an edit of the RPM's own file.

---

## 3. Ambiguities resolved, and where the tooling disagreed with the plan

### 3.1 A `from-file:` module is a mapping, not a list item

**The plan's §5.2 table says each module file "carries text quoted from the
section named", and §4.0's block is written as a `- type: dnf` list item. Taken
literally, every module file fails to validate.** The first `bluebuild validate`
run rejected all eight:

```
1 │ - type: dnf
  · ╰── - is not of type "object"
```

**Resolved by reading `blue-build/cli` @ `394cfac7` rather than guessing.**
`module-v1.json`'s `$defs/RepoModule` is an `anyOf` over per-module schemas,
each of which is `"type": "object"`, and `ModuleExt::try_from`
(`recipe/src/module_ext.rs:38-56`) deserialises the file as a `ModuleExt` — a
struct with a `modules:` field — falling back to a bare `Module` only if that
fails. So the shape that is both schema-valid and loadable is a **mapping**.

**Implemented:** each of the eight module files carries its `type:` and its keys
at the top level, with no leading `- `. Everything §5.2 attributes to each file
is unchanged. This is a mechanical transcription fix, not a design change, and it
is the only way to satisfy the prompt's own gate: "`bluebuild validate` passes,
before the build, not after it."

A consequence worth knowing, since it is the same rule: a module file **may**
carry a `modules:` list, which is how a file contributes more than one module.
This recipe does not use it — one file per `from-file:` entry, eight entries.

### 3.2 `base-image` must not carry a tag

**§5 writes `base-image: quay.io/fedora/fedora-kinoite:latest` and
`image-version: latest`, and that combination cannot work.** `bluebuild generate`
failed:

```
Unable to parse base image quay.io/fedora/fedora-kinoite:latest:latest
invalid reference format
```

The cause is `cli/recipe/src/recipe_v1.rs:113-119`:

```rust
let base_image = format!("{}:{}", self.base_image, self.image_version);
```

The base reference is **always** composed as `{base-image}:{image-version}`, so a
tag on `base-image` yields `:latest:latest`.

**Resolved in the direction the rest of the document supports:** the tag comes
from `image-version` alone, and `base-image` carries the repository only. This
still resolves to `quay.io/fedora/fedora-kinoite:latest` — the reference §3 names,
and rule 2's "latest stable, never pinned" is fully satisfied, because
`image-version: latest` is exactly what re-resolves each run. The comment in
`recipe.yaml` says so, because the alternative reading — a hard-coded tag — is
pinning in all but name and rule 2 forbids it. **Confirmed in the generated
Containerfile:** `ARG BASE_IMAGE="quay.io/fedora/fedora-kinoite@sha256:662e517e…"`
with the label `org.opencontainers.image.base.name="quay.io/fedora/fedora-kinoite:latest"`,
i.e. `:latest` resolved to that day's digest.

### 3.3 The six flatpak commands must share one `snippets:` entry

§3.2 gives six commands and §5.2 says "the six-command cleanup … in `snippets:`".
Written as six separate entries it is **silently broken**, and the way it breaks
is the fail-open mode §3.2 itself warns about.

`remotes=$(flatpak remotes --system --columns=name)` is on line 2 and the two
`grep -qx "$remotes"` tests are on lines 3 and 4. The `script@v2` runner executes
each entry in its own `/bin/sh -c 'set -eu; …'` (`modules/script/v2/script.nu:52`,
**confirmed by reading the module**), so across entries `$remotes` is **empty**:
`printf '%s\n' "" | grep -qx fedora` is false, both deletes are skipped, and the
marker and mask are still written with exit 0. Criterion 2c then fails on a green
build.

**Resolved:** all six commands are one `snippets:` entry, with the capture and
both guarded deletes in the same shell. The `test -n`-style fail-closed discipline
of §4.11 is preserved by keeping the plan's own capture-then-test form — and
**no `pipefail`**, which is not POSIX and is not needed: every failure mode here
already collapses to an empty `$remotes`.

### 3.4 The VRR unit's `$$` and `TimeoutStartSec=infinity`

Both transcribed exactly, because both are load-bearing and both fail quietly
otherwise:

- The loop variable is **`$$o`** and the command substitutions are **`$$(…)`**.
  systemd expands `$o` to the empty string before `/bin/sh` ever runs, so a bare
  `$o` makes every call `niri msg output ""` and the oneshot fails. `$$` is the
  documented escape and always yields one literal `$`; relying on systemd leaving
  an unrecognised `$(` alone would depend on a parsing detail rather than on the
  documented rule.
- **`TimeoutStartSec=infinity`, never `0`.** `0` is a zero-second budget, not a
  disable. This unit is `Type=oneshot`, whose start timeout systemd already
  disables by default, so writing `0` would *override* that default and kill the
  unit on its first `sleep 1`. `infinity` is spelled out rather than relying on
  the oneshot default so the setting survives a future change of `Type=`.
- The unit has **no `[Install]` section**. Activation is the `Wants=` from
  `kinrin-vrr.conf`, so it starts with niri and only with niri. That is why there
  is no `systemd-user.yaml` in the recipe at all — a `systemd-user.yaml` existed
  only to `enable niri-vrr.service`, and `enable` would put back the
  `default.target` symlink that starts it in every session, Plasma included,
  where `niri msg` has no socket and the wait loop never returns.

### 3.5 Five drop-ins, never four, and never merged

`kinrin-dms.conf` (binds the unit), `kinrin-xdg.conf` (`XDG_CURRENT_DESKTOP`),
two `kinrin-theme.conf` files (one per unit), `kinrin-vrr.conf` (starts the VRR
unit). No single one does both jobs and **none is merged with another**, for two
independent reasons:

- systemd does not pass one unit's `Environment=` to a unit it merely `Wants=`, so
  a `niri.service` drop-in alone never reaches DMS nor anything DMS launches.
  Hence **two** theme drop-ins.
- `PartOf=` is read by the unit that carries it, so it must sit in the
  `dms.service` drop-in; under `niri.service` it would make *niri* stop when DMS
  does. That is a third reason the two units need separate files.

`PartOf=niri.service` is **not optional**: drop it and DMS outlives the
compositor, leaving an orphaned Quickshell process holding the DRM master. It is
belt-and-braces rather than the only stop path — `dms.service` already ships
`PartOf=graphical-session.target` and the upstream `niri.service` `BindsTo=`s that
same target — but the plan does not control that ordering, so the stop is made
unconditional. **Verified in the installed package:**
`/usr/lib/systemd/user/dms.service` carries exactly
`PartOf=graphical-session.target`, `Requisite=graphical-session.target`,
`[Install] WantedBy=graphical-session.target`, which is what §4.8 describes.

`XDG_CURRENT_DESKTOP=niri` goes in a drop-in and only there. The generated
`niri.kdl` already carries `environment { XDG_CURRENT_DESKTOP "niri"; }`
(`embedded/niri.kdl:137-139`, CONFIRMED), but that is a **KDL `environment`
block applying to what niri spawns** — not a unit environment, which is what
criterion 26 reads. The global `environment.d` branch is not taken at all: it
would leak into the Plasma fallback, where `niri` is wrong.
`/etc/environment.d/90-dms.conf` therefore carries **only**
`QT_QPA_PLATFORM=wayland` and `ELECTRON_OZONE_PLATFORM_HINT=auto`, neither of
which is one of the three DMS variables, and it takes `KEY=VALUE` — a KDL block
there would be an unreadable file.

### 3.6 `portals.conf` — three keys, semi-colons not colons

`default=kde` is the one-element case of a **semi-colon-separated** list; a `:`
there is the `XDG_CURRENT_DESKTOP` separator and matches no backend, which is why
the old `default=kde:plasmanotify` did nothing. The third key,
`Secret=kwallet`, is load-bearing for a different reason: only `kwallet.portal`
declares that interface, `kde.portal` and `gtk.portal` do not, and
`kwallet.portal`'s `UseIn=kde` does not match `niri` — so `Secret` resolves to
**nothing at all, silently**, without it. Written verbatim, three keys.

### 3.7 The `files.yaml` entries are all `source:`/`destination:` **pairs**

All thirteen, without exception. The bare single-key form takes the branch at
`files.sh:35-38`, where `DEST` becomes the literal string `null` (verified by
execution, §1.2), and `cp -f` copies to a path named `null` and exits 0. The
entry is also **schema-valid** in that form, so `bluebuild validate` cannot catch
it and the build goes green on an empty image. Every `source:` here is mirrored
by a real file under `files/`, and every destination is one of the thirteen the
presence chain enumerates.

**That chain cannot detect its own drift**, and the plan says so: a destination
added to `files.yaml` but to neither chain ships unchecked, and a chain shortened
by one path still exits 0. So §5.2's list is authoritative and both the §5 chain
and the §6.1 chain enumerate exactly these thirteen in this order:

1. `/etc/xdg/xdg-desktop-portal/portals.conf`
2. `/etc/greetd/config.toml`
3. `/etc/systemd/logind.conf.d/kinrin.conf`
4. `/usr/lib/systemd/user/niri.service.d/kinrin-dms.conf`
5. `/usr/lib/systemd/user/niri.service.d/kinrin-xdg.conf`
6. `/usr/lib/systemd/user/niri.service.d/kinrin-theme.conf`
7. `/usr/lib/systemd/user/dms.service.d/kinrin-theme.conf`
8. `/usr/lib/systemd/user/niri.service.d/kinrin-vrr.conf`
9. `/usr/lib/systemd/user/niri-vrr.service`
10. `/etc/environment.d/90-dms.conf`
11. `/usr/share/dms/cli-policy.json`
12. `/etc/skel/.config/niri/local.kdl`
13. `/etc/skel/.config/DankMaterialShell/settings.json`

The dracula copies are deliberately **not** in the chain: they come from
`theme.yaml`, and `curl -f` unlinks its output on an HTTP error while
`install -Dm444` exits 1 on a missing source, so that module fails the build
loudly on its own.

### 3.8 `include optional=true`, prepended, and the `../`

Three separate requirements, all transcribed exactly:

- **`optional=true` everywhere.** A bare `include` to a missing file stops niri
  booting (`exit=1`); `optional=true` is tolerated (`exit=0`).
- **Prepended, never appended** — `sed -i '1i include optional=true
  "../local.kdl"'`. niri accepts `include` only at the top level, and as an
  append it could glue onto the last KDL node when the generated file has no
  trailing newline, which fails `niri validate`.
- **Added to the generated file, never replacing it.** The deployer skips any
  non-empty `dms/*.kdl`, so seeding a `binds.kdl` holding *only* the include
  would permanently suppress every default bind — `Mod+Space`, `Mod+N`,
  `Mod+Alt+L` — and criterion 2b would fail. That is why `files.yaml` authors
  **only** `local.kdl` and no `binds.kdl`, and none should.

Window rules go in `local.kdl` and **never** in `dms/alttab.kdl`: the deployer
preserves a non-empty file but the running shell rewrites it on a theme change,
and `outputs.kdl` on every output change. `binds.kdl` is the only included file
the shell never rewrites. **Never write in `outputs.kdl`** — a rule there is
destroyed silently.

**Verified by execution before the build** (a container rehearsal of §4.5, run so
a failure would not cost 20 minutes):

- `dms setup headless --compositor niri` deployed eight files and wrote
  `config.kdl`; `dms version` as root printed the expected `FATAL  go: This
  program should not be run as root. Exiting.`, which is why the throwaway
  `builder` exists.
- `binds.kdl` line 1 is `include optional=true "../local.kdl"`, the original
  first line is pushed down intact, and `Mod+Space`, `Mod+N`, `Mod+Alt+L` are all
  still present — the default binds survived.
- `Mod+T … { spawn "konsole"; }` — the `ghostty` → `konsole` correction applied,
  **zero** `ghostty` occurrences left. This is a correction, not a preference:
  `parseHeadlessTerminal("")` returns `TerminalGhostty`
  (`commands_setup_headless.go:128-131`, CONFIRMED), mapped to
  `terminalCommand = "ghostty"` (`deployer.go:224-225`, CONFIRMED) and
  substituted into the shipped template's `Mod+T` bind (`niri-binds.kdl:8`,
  CONFIRMED). `--terminal` cannot fix it: the flag accepts only `ghostty`,
  `kitty` or `alacritty`. Both `install` calls read the corrected file, so the
  rewrite happens once. **No criterion catches this** — 2b tests only the three
  binds above — which is precisely why it was checked here.
- `niri validate --config /etc/niri/config.kdl` → `config is valid`, exit 0.
- the §4.12 theme fetch and the `jq` shape assertion both passed; the predicate
  asserts the canary's **type**, not its presence, so a payload with the right
  keys and junk values is rejected.
- `/etc/skel/.config/niri/dms/binds.kdl` is byte-identical to
  `/etc/niri/dms/binds.kdl` (`cmp` clean), so the skel carries the corrected file.

### 3.9 `configVersion` — the value moved twice, and the plan's mechanism caught it

This is the one number §4.12 says is **"a dated reading, not a pin"**, to be
re-read from the installed `dms` before each build, and it moved.

The plan's value is **33**, read 2026-09-30 from the git tree. Re-reading
`SettingsData.qml` from the git tip gives **36** at `:24`. But the authoritative
source is **the `dms` the image actually installs**, and the plan is explicit
that this is where to read it — the git tree is not what ships.

Read from the COPR package this build installs, `dms-1.6.2-1.fc44` — reproduced
here so the number is checkable rather than asserted:

```console
$ podman run --rm --user 0 docker.io/library/fedora:44 bash -c '
    dnf -y install dnf-plugins-core >/dev/null 2>&1
    dnf -y copr enable avengemedia/dms >/dev/null 2>&1
    dnf -y install dms
    rpm -q dms
    F=/usr/share/quickshell/dms/Common/SettingsData.qml
    grep -n settingsConfigVersion "$F"
    grep -n "configVersion = " /usr/share/quickshell/dms/Common/settings/SettingsStore.js | tail -3'

dms-1.6.2-1.fc44.x86_64
19:    readonly property int settingsConfigVersion: 18
493:        settings.configVersion = 17;
    493:        settings.configVersion = 17;
```

so the installed package's migration chain tops out at `configVersion = 18`, not
33 — there is no step above it in that release.

**Shipped value: `18`.** Written into
`/etc/skel/.config/DankMaterialShell/settings.json` and recorded here, because the
next reader must know it was measured and not copied — and because §4.12's
warning is exactly this: *a stale value is a downgrade, not an error, so
re-read it before each build.*

Three consequences recorded honestly:

- The git tree (§36) and the installed package (§18) **disagree**. The
  repository is ahead of the release the COPR serves. The installed package is
  the authority, because it is what reads this file at first start.
- `33` would have been wrong in **both** directions: too high for the installed
  `dms`, whose migration chain stops at 18, and asserting a version the shipped
  binary does not implement.
- This is the mechanism working as designed, not a defect. It is exactly why §4.12
  calls the value a dated reading rather than a pin, and why the number is written
  at **authoring time** — the §4.5 `RUN` runs *after* `files.yaml`, so it cannot
  inject into this file.

The other two keys are unchanged from the plan, and are a precaution rather than a
proven fix — re-confirmed here: `grep -rn platform_theme` over the whole DMS tree
returns **nothing**, so no template demonstrably writes that key. Both stay
`false` so no unexamined template runs against `QT_QPA_PLATFORMTHEME=gtk3`, and
the outcome is settled by observation (criterion 5), not by argument.

**No `currentThemeCategory` is written**, and adding one would buy nothing: the
property carries its own literal default (`"generic"`), nothing binds it to the
settings file, `applyStoredTheme` overwrites it in memory, and its persist is
gated on a `savePrefs` that this call passes as `false`.

### 3.10 `cli-policy.json` — the key that does the work

Shipped verbatim:
`{"policy_version": 1, "immutable_system": false, "blocked_commands": []}`.

`immutable_system: false` is the **operative** key, not the empty list: the gate
returns on it *before* it ever reaches the matching loop. The list is
belt-and-braces.

It is required and not optional — the gate reads `/usr/share/dms/cli-policy.json`
first, then `/etc/dms/cli-policy.json`, this base reads immutable **twice over**
(`/run/ostree-booted` first, then `VARIANT_ID` carrying `kinoite`), and the
shipped defaults block four commands including `setup`, which covers
`setup headless …` by exact-or-prefix. **Verified against the installed package:
`dms` ships no `/usr/share/dms/` at all**, so the image-written file is the only
policy `dms` will ever read, and without it the §4.5 `RUN` fails outright.

`sync` is deliberately **not** blocked upstream, so criterion 12b is untouched by
this file.

`files.yaml` lands **before** `niri-config.yaml` — the one module whose content
depends on a file another module wrote.

### 3.11 `systemd-system.yaml` — enable greetd, disable plasmalogin, never the alias

`system: {enabled: [greetd], disabled: [plasmalogin.service]}`, and
**`display-manager.service` must not appear under `disabled:`**. This is the
single most boot-fatal line in the recipe:

- The base ships a DM enabled:
  `/etc/systemd/system/display-manager.service -> /usr/lib/systemd/system/plasmalogin.service`.
- `greetd.service` activates **only** through that alias — `[Install]
  Alias=display-manager.service`, no `WantedBy=` — so the alias link is its only
  activation.
- The BlueBuild `systemd` module runs its `enabled:` loop **before** its
  `disabled:` loop (confirmed by reading `modules/systemd/systemd.sh:35-46`:
  `systemctl -f enable` at line 38, `systemctl disable` at line 44). Disabling
  the alias therefore **deletes the symlink `enable greetd` just created**, and
  `graphical.target` — whose only DM boot path is `Wants=display-manager.service`
  — resolves to nothing. The image boots to a black screen with no login.
- Disabling **only** the alias would also be a vacuous pass, because the base may
  have `plasmalogin.service` enabled directly and a `plasmalogin.service` racing
  greetd for VT1 is the same unsettled boot.

`-f` is applied to `enable` only, never to `disable` — noted so the asymmetry is
not mistaken for a typo. `plasma-login-manager` keeps shipping, so the Plasma
fallback binaries exist either way, which is what criterion 6 and criterion 13
need. **No `dms-greeter enable` step was added**: the module already does the
equivalent, and §4.8 makes `dms-greeter enable` a **first-boot check**, not a
build step — it labels nothing, it enables greetd and sets `graphical.target`.

**No sysusers file for `greeter` is shipped**, and no `semanage` step either. The
RPM installs `/usr/lib/sysusers.d/dms-greeter.conf` *and* creates the group and
user in `%pre` with `-r`; redeclaring the line would make two sources of truth
for one system user and fight the RPM at every boot. DRM access needs no group:
`card*` comes through the logind ACL at `70-uaccess.rules:46` and `renderD*`
world-accessibly through `50-udev-default.rules:61` — **different rules**, so do
not assume one covers both.

### 3.12 `os-release.yaml` runs last of the eight

`properties: {ID: kinrin, ID_LIKE: fedora}` in one map, module position eighth —
last of the eight, immediately before `signing`. Two reasons, both load-bearing:

- The whole `dnf` transaction and the `dms setup` inside `niri-config.yaml` must
  still read `ID=fedora`. Nothing keys off the new `ID` where the answer would
  differ: `isVoidSetup()` looks `ID` up in `distros.Registry` and only accepts
  `FamilyVoid`, a family only `"void"` registers (`void.go:25-26`, CONFIRMED) —
  so `ID=kinrin` returns exactly what `ID=fedora` returned.
- The module serialises values **with quotes** (`os-release.nu:31`,
  `$'($in.key)="($in.value)"'`), which is why both post-build greps tolerate
  optional quotes: a bare `^ID=kinrin` fails on a correct build.

---

## 3a. A self-audit that found real defects, and what it changed

The finished tree was handed to an independent reviewer with instructions to be
adversarial and to check every claim in these notes against the clones. It found
nine defects and five false claims. All are fixed; recording the list is the
point, because four of the nine were invisible to every gate the plan defines.

**Fixed — these would each have shipped:**

1. **`build.yml` named an image the build never produces.** Ten steps read
   `ghcr.io/${OWNER,,}/kinrin:latest` while the recipe `name:` is
   `kinrin-distro` (§2.5), so `bluebuild` tags `ghcr.io/bacondroid/kinrin-distro:latest`.
   Every in-image gate, the `podman save` and both `skopeo copy` sources pointed
   at a name nothing built. Now `${REPO,,}`, which is the same string by
   construction rather than by coincidence — and the string `kinrin` no longer
   appears anywhere in `build.yml` outside a comment.
2. **Criterion 28b printed instead of asserting.** It ran
   `jq -r '.transports.docker | keys[]'` and stopped there. A mismatch would
   print and pass. It now asserts `has("ghcr.io/${REPO,,}")` with `jq -e`, so
   the one check that exists to catch a name mismatch actually fails on one.
3. **The monitor could never fire.** `$GITHUB_OUTPUT` was passed into the probe
   container as a *host* path while the file was bind-mounted at `/out`, so the
   probe wrote to a path that does not exist inside the container, produced no
   step outputs at all, and `if: steps.probe.outputs.landed == 'true'` was
   never true. Fixed by having the probe print tagged lines on **stdout** and the
   host turn them into step outputs — which also removes a bind-mount permission
   problem under rootless podman for no benefit.
4. **The monitor never asked Fedora anything.** It enabled the COPR and asked
   whether the COPR still answered, which means a **broken, moved or expired
   COPR reads as "landed"** — exactly the signal §9 assigns to the monthly
   *build*, not to this job. It now resolves four names: `dms` and `dms-greeter`
   against the COPR, and `dms` plus `DankMaterialShell` against official Fedora
   alone, and asserts no COPR is still enabled before the Fedora probes run so
   they cannot answer from a leftover repo. **Verified by running it:**
   `dms-1.6.0/1/1.6.2` and `dms-greeter-1:1.6.0/1/1.6.2` still resolve from the
   COPR, `DankMaterialShell-1.4.4-2.fc44` is already in Fedora, `landed=false` —
   the job correctly declines to open an issue today.
5. **`TESTING.md` was missing criteria 13 and 17** — the greeter's session list,
   and the live theme change that is the whole point of the skel `config.kdl`
   copy. Both added; all 41 numbered criteria are now present.
6. **Criterion 11 was a one-liner.** §4.8 makes it the check that settles
   `dms-greeter enable`: `systemctl get-default` reporting `graphical.target`,
   greetd enabled, and **both** `plasmalogin.service` and `sddm.service`
   disabled or not-found. Checking only the `display-manager.service` symlink
   passes vacuously. The four commands are now in the criterion.
7. **The README claimed `cosign.pub` was committed** when it is not (§5).
   *Since resolved*: the key pair was generated, the public half committed, and
   the README rewritten to match. Both the README claim and the underlying gap
   were real at the time.
8. **The README's rollback section was not labelled §7**, which PROMPT asks for
   by name.
9. **`--skip-validation` on the build job** and the two pinned tool installs
   were unrecorded deviations from §6's own command text. Now recorded, in the
   section above.

**False claims in these notes, corrected:**

- `post_build.sh` was given as `cli/scripts/post_build.sh`. It is
  `scripts/post_build.sh` at the root of the `blue-build/cli` repository — there
  is no `cli/` prefix, that repository *is* the CLI crate. The content claim
  (line 22 is a single `rm -rf /tmp/* /var/* /opt`, line 23 recreates `/opt`) was
  and is exact.
- "exactly one `def: false` among the **26** `matugenTemplate*` entries" — there
  are **27** such keys; 26 carry a boolean `def` and
  `matugenTemplateNeovimSettings` carries a compound object default. The
  load-bearing half, exactly one scalar `def: false`, is unchanged.
- "the other **21** module types are unversioned" — there are 24 module
  directories, 2 carry a `versions:` list, so **22** are unversioned.
- A cross-reference pointed at §2.1 for the `configVersion` discussion, which is
  in §3.9.

One finding the reviewer raised was checked and **rejected**: it reported the
`ThemeBrowser.qml` `listInstalledThemes` callback as `:217-223`. Re-read, the
callback spans **`:216-222`** — `:216` is the call, `:222` its closing `});` —
so the note as written was correct.

## 4. Things the plan states that were checked here and hold

Recorded so a future reader knows they are not merely inherited:

- **The base is Kinoite, which is KDE.** `dolphin`, `konsole`, `plasma-workspace`,
  `plasma-workspace-common`, `kwin` and `plasma-discover` are already installed
  in `quay.io/fedora/fedora-kinoite:latest`; **`kate` is the only genuine
  addition** among the KDE apps, and criterion 5 checks it for that reason. The
  packages are declared explicitly anyway.
- **`xwayland-satellite` is redundant, not needed.** `niri-26.04` already carries
  `Requires: xwayland-satellite >= 0.7`. Declared anyway — an explicit dependency
  survives a future niri relaxing it. Criterion 27.
- **`steam-devices` is the genuinely missing one.** Without it no gamepad is
  recognised and criterion 22 fails with no explanation.
- **`plasma-workspace` is the package that ships
  `/usr/share/wayland-sessions/plasma.desktop`** — not
  `plasma-workspace-common`, which is the easy one to drop. Criterion 6's build
  check is **two commands** for the same reason: the session file and the command
  resolve separately, and either can be missing while the other works.
- **Weak deps stay at their default and nothing is set.** `danksearch` and
  `matugen` are both `Recommends:` (`dms.spec:27,28`, CONFIRMED), and matugen
  absent means the whole of §4.12 dies silently at first login with no error and
  a fallback theme nobody chose. If it ever needs setting, the key is
  `install-weak-deps` inside `install:` — hyphens — **not** `install_weak_deps`,
  which is not in the schema. Confirmed in the module's own schema
  (`modules/dnf/dnf.tsp:175-177`), defaulting to `true`.
- **`repos:` is a mapping, never a list of records.** `nonfree:` and `copr:` are
  two keys at the same level and `- avengemedia/dms` is an **item of the `enable:`
  list**; a `- copr:` entry breaks the build. The module enables the COPR through
  the dnf5 plugin (`dnf copr enable <owner>/<project>`), so no COPR URL is
  hard-coded anywhere and the `:latest` base cannot pin itself to a Fedora
  release.
- **`opencode` is not shipped.** No RPM and no Flatpak exists for it, and the only
  channel is an install script that writes into the user's home. Nothing goes in
  `dnf.yaml` or in the image.
- **`orca.yaml` takes the RPM, never the AppImage**, and **one** `snippets:`
  entry, with both guards transcribed: `test -n "$url"` (an empty-match check)
  **and** the `case` binding the URL to the one download prefix the live
  `releases/latest` response uses (an origin check). `test -n` alone is not an
  origin check — it accepts any well-formed URL. The guard binds origin, it does
  not authenticate; closing that needs a signature check, which would be new
  design rather than a minimal fix. The module takes `releases/latest`, so
  nothing is pinned, and no `pipefail` (not POSIX, and every failure mode already
  collapses to an empty `$url`).
- **No `dnf update` during the build**, ever: kernel and bootloader do not behave
  well mid-build. Confirmed the module never runs one — `grep` for `dnf update`
  over both BlueBuild trees returns nothing; the nearest thing is `dnf distro-sync`
  in the `replace` path, which this recipe does not use.
- **Cleanup is `dnf clean all` then `rm -rf /var/cache/dnf /var/cache/yum`, and
  nothing wider.** The tempting `rm -rf /var/{log,cache,lib}/*` glob hits
  `/var/lib/rpm` and destroys the RPM database, which makes the image
  unverifiable. Confirmed the module itself never runs `dnf clean all`: package
  cache removal happens only because `post_build.sh:22` does `rm -rf /var/*`.
- **`opencode` is not in `install:`, and `danksearch` is not either.**
  `danksearch` arrives as a plain `Recommends:` pull, which the `dnf` module does
  by default. The COPR ships a **second enabled stanza**,
  `[coprdep:copr.fedorainfracloud.org:avengemedia:danklinux]`, which we do not
  declare; `dms-greeter` comes from it, and `danksearch` from it **or** from
  Fedora — the repo that satisfied the transaction was not recorded, so its origin
  stays unverified and nothing turns on the answer.
- **The COPR URL form is not ours to choose.** The module shells out to the dnf5
  COPR plugin rather than composing a URL, so the Pulp move is handled by the
  plugin and the version-parameterised-form fallback in §11/§4.0 is not needed
  here. It is recorded anyway, because a first-build 404 is the symptom that
  fallback addresses.
- **`DMS_DISABLE_MATUGEN` — conditional branch, not an open question.** The
  greeter no longer poses it: `dms-greeter sync` symlinks the theme into
  `/var/cache/dms-greeter/`, so the greeter renders Dracula **without ever running
  matugen**, and there is nothing to disable. No `colors.kdl` under
  `/var/lib/greeter` exists to look for. Criterion 35 covers the session side
  only.
- **Criterion 12 fails by design on a fresh image.** The greeter renders its own
  default theme until `dms-greeter sync` has run, and 12b is what runs it — so 12
  is a continuation of 12b, checked last. The fix is to run 12b, **never** to
  touch `theme.json` or the skel: editing a theme file to make 12 pass proves
  nothing about the greeter and leaves the shipped theme wrong. `TESTING.md` says
  so where a tester will read it.

---

## 5. Build record

Recorded at build time, because §6/§7's rollback needs the digest of the build
being left, and a date tag is only a record — the digest is what resolves.

| | |
|---|---|
| BlueBuild | `0.9.37` (`394cfac7` / `7d51cca7`) |
| Base resolved | `quay.io/fedora/fedora-kinoite:latest` → `sha256:662e517ea7a6e2f813e525a310130789919dd3ed09f3f849c1d8a9cd0d17431a` |
| Fedora | 44 |
| `dms` installed | `1.6.2-1.fc44` |
| `niri` installed | `26.04-1.fc44` |
| Build date tag | *none locally* — the `id: meta` step lives in the publish job, which could not run without a keypair. In CI it produced `2026-10-01` (§6) |
| Local build tag | `ghcr.io/bacondroid/kinrin:latest_linux_amd64` |
| Local image digest | `sha256:566c0b521c02cd2bc30b96794509c506a090aa42efc8cf0b8f8343fad86295c0` |
| Image size | 10.9 GB uncompressed, 2116 packages |
| Local build wall time | ~23 min |

**The local tag says `kinrin`, the repository's recipe says `kinrin-distro`.**
That is a property of the *preflight copy*, not of the deliverable: the
preflight tree was taken before §2.5 renamed the recipe, so it builds and tags
under the old name. Nothing in this repository is inconsistent — `git ls-files`
shows one recipe, and it says `kinrin-distro`. It is called out because a reader
comparing the local tag with the recipe would otherwise think the two had
drifted again, which is the exact §10 failure mode this build already fixed once.

### The four in-image gates, run against the built image

```
PASS  niri validate --config /etc/niri/config.kdl (in-image)
PASS  files.yaml presence chain, 13 paths
PASS  os-release ID=kinrin
PASS  os-release ID_LIKE=fedora
=== 4 passed, 0 failed ===
```

Read out of the same image, because the plan asks for observation rather than
assertion:

```
--- default binds survived the prepended include (criterion 2b) ---
Mod+Space    1
Mod+N        1
Mod+Alt+L    1
--- include is line 1 and optional ---
include optional=true "../local.kdl"
--- terminal bind corrected to konsole, no criterion covers this ---
9:    Mod+T hotkey-overlay-title="Open Terminal" { spawn "konsole"; }
ghostty occurrences: 0
--- greetd: the alias must point at greetd, and never be disabled ---
/usr/lib/systemd/system/greetd.service
--- flatpak: the mask is the mechanism that survives ---
/dev/null
system remotes: []
--- os-release, verbatim ---
ID="kinrin"
ID_LIKE="fedora"
```

Every one of those is a plan claim confirmed by execution rather than by
reading:

- **`display-manager.service` resolves to `greetd.service`.** This is the
  boot-fatal line of §3: the base ships the alias pointing at `plasmalogin`, and
  it is the `systemd` module's `enabled:` pass that repoints it. Had
  `display-manager.service` been listed under `disabled:`, this would read
  `/usr/lib/systemd/system/plasmalogin.service` or resolve to nothing at all, and
  the image would boot with no login screen.
- **`os-release` values are quoted** — `ID="kinrin"`, not `ID=kinrin`. That is
  `os-release.nu:31` serialising with quotes, and it is exactly why the
  post-build greps tolerate optional quotes; a bare `^ID=kinrin` would fail on a
  correct build.
- **The flatpak mask is `/dev/null` and `flatpak remotes --system` is empty** —
  criterion 2c's two halves, and the marker in `/var` is irrelevant because
  `post_build.sh:22` clears it.
- **`Mod+T` spawns `konsole` and no `ghostty` survives.** No criterion in §8
  covers this bind, which is why it was checked here and in the container
  rehearsal.
- **The three default binds survived** the prepended include, which is what
  criterion 2b exists to protect.

### Criterion 28b could **not** be satisfied here, and the reason matters

The built image *does* contain `/etc/containers/policy.json` and
`/etc/containers/registries.d/` — but those are **the base image's**, not the
`signing` module's:

```console
$ podman run --rm <image> rpm -qf /etc/containers/policy.json
containers-common-0.67.2-1.fc44.noarch
$ podman run --rm <image> jq -c '.transports.docker' /etc/containers/policy.json
null
```

`.transports.docker` is `null`, so **no `ghcr.io/<owner>/<repo>` key exists** —
which is precisely what criterion 28b asserts. This is not a near-miss to be
softened: the file's presence is the base's, and a gate that only checked
`test -f /etc/containers/policy.json` would have passed on an image whose
verification policy says nothing about this repository. The CI step therefore
does both — `test -f` **and** `jq -e --arg r "ghcr.io/${REPO,,}" '.transports.docker
| has($r)'` — and on this image the second would fail, correctly.

The `signing` module ran in no build *up to this point*, because no `cosign.pub`
existed yet. §6 records the first build that did exercise it, in CI.

### Deviations from the plan's own CI text, and why

- **`--skip-validation` on the build job's `bluebuild build`.** §6's job-2
  command does not carry it. It is deliberate and harmless: the `validate` job
  already ran `bluebuild validate` on the same commit and the build job is
  `needs: validate`, so the re-check would be a duplicate network round-trip to
  `schema.blue-build.org` for no new information. It is recorded here because the
  plan's §6 command is quoted exactly and this is a change to it. The flag is
  real (`cli/src/commands/build.rs:190-193`), not invented.
- **Two install steps the plan does not mention at all**: BlueBuild is pinned and
  installed in the `validate` and `build` jobs, and cosign is pinned and installed
  in the `publish` job. Neither tool is present on a GitHub runner, so without
  them the workflow fails at its first command. Both are pinned — bluebuild by
  image **digest** and asserted by version string, cosign by version and checked
  against the checksum upstream publishes beside the release.
- **`docker run` rather than a bare `dnf` in `monitor-fedora.yml`.** An
  `ubuntu-latest` runner has no dnf, so the probe runs inside a `fedora:44`
  container. Verified locally: it reports `dms` and `dms-greeter` still resolving
  from the COPR, `DankMaterialShell` already in Fedora, and `landed=false` — so
  the job correctly declines to open an issue today.

Verified by execution on this machine:

- **the full bootc build**, end to end, of the eight `from-file:` modules in the
  order §5 requires — ~23 min, 2116 packages, 10.9 GB, four of the six gates
  green inside the built image (§ above);
- `bluebuild validate recipes/recipe.yaml` → valid, **before** the build.
- `bluebuild generate` → the Containerfile, with `stage-files`, the thirteen
  `files.yaml` pairs, and all nine module RUNs in the specified order.
- §4.5 and §4.2 rehearsed in a container before committing to a 20-minute build:
  the eight files deployed, the include prepended, `Mod+T` corrected to `konsole`,
  the three default binds intact, both `install` copies byte-identical, and
  `niri validate` green on the shipped path.
- §4.12's fetch and `jq` shape assertion.
- The `dms`-provided facts: `dms.service`'s unit text, `niri.service`'s presence,
  `dms` shipping no `/usr/share/dms/`, and `settingsConfigVersion`.

**Not verifiable from here, and not claimed:**

- Anything in §8 that needs a real desktop: no GPU, no graphical session, no
  gamepad, no game. §8 is a manual checklist and is kept as one in `TESTING.md` —
  it is deliberately **not** converted into fake automation.
- Criterion 22 (no gamepad) and criterion 15 (no target Intel GPU) — both stay
  open, as §10 has them.
- The `cosign` key pair itself: `cosign generate-key-pair` was **blocked by the
  host's secret-path safety guard**, which refuses access to `*.key` paths. Per
  the guard's own instruction — "do not retry this operation or attempt any
  workaround" — nothing was retried and nothing was worked around. At that moment
  `cosign.pub` was **not** in this tree, so the `signing` module — which exits 1 at
  the **last** module without it, after the whole 20-minute build — was not
  exercised by the local build recorded in §5. It was committed later and does run
  now; §6 is the evidence. Generating the pair is a
  prerequisite of the first publication, not a build step (§2.4), so this changes
  nothing in the recipe; it does mean the local run proves seven of the eight
  module files, and that is stated rather than glossed.

  **The mechanism is visible in the generated Containerfile, not inferred.**
  `bluebuild generate` produced the nine module RUNs in the order §5 requires —
  `dnf`, `script` (flatpak), `files`, `systemd`, `script` (niri-config),
  `script` (theme), `script` (orca), `os-release`, `signing`, the last being the
  inline entry — and the key stage came out **empty**:

  ```dockerfile
  FROM scratch AS stage-keys
  # Main image
  ```

  No `COPY cosign.pub /keys/kinrin-distro.pub`, because `has_cosign_file()`
  (`template/src/lib.rs:100-103`) found no `cosign.pub` in the working directory.
  The build therefore reaches the last module, finds nothing at
  `/etc/pki/containers/kinrin-distro.pub`, and exits 1 at
  `modules/signing/signing.sh:25-27`. That is the failure the plan predicts, and
  it is a property of the generated Containerfile rather than a prediction about
  it. The generated Containerfile also carries the three `stage-files` /
  `dst=/tmp/files,rw` mounts and all thirteen `files.yaml` pairs, which is the
  other unpinned BlueBuild fact from §1.2 seen in the output rather than in the
  source.
  Consequently the local preflight build was run with `- type: signing` removed,
  so the other eight modules could be exercised end to end. That removal is a
  **local test artefact only**: `recipes/recipe.yaml` in this repository keeps
  `- type: signing` last, exactly as §5 requires, and the CI workflow builds the
  unmodified recipe.

### One gate of mine was broken; the image was fine

Criterion 28b asserts the policy key rather than printing it. It was written as

```sh
podman run --rm --pull=never "$IMAGE" sh -c \
  'jq -e --arg r "ghcr.io/${REPO,,}" ".transports.docker | has(\$r)" /etc/containers/policy.json'
```

The single quotes are the defect. `${REPO,,}` is a bash-only case-folding expansion,
so inside single quotes it survives to the container's `sh`, which does not know
it: `$r` arrived as `ghcr.io/`, `has()` correctly returned `false`, and the gate
failed against an image whose `/etc/containers/policy.json` was already correct —
it listed `ghcr.io/bacondroid/kinrin-distro` as a key, with
`registries.d/bacondroid-kinrin-distro.yaml` beside it.

`jq` is now passed as argv rather than through `sh -c`, so bash expands before the
container ever sees the argument. Worth recording because the failure presented as
a build problem and was not one.

### cosign does not read skopeo's credentials

The push succeeded, the digest was captured, and the sign step failed:

```
Pushing signature to: ghcr.io/bacondroid/kinrin-distro
Error: signing [...]: signing digest: failed to upload layer: POST
https://ghcr.io/v2/bacondroid/kinrin-distro/blobs/uploads/: UNAUTHORIZED:
unauthenticated: User cannot be authenticated with the token provided.
```

Two different credential stores in one job. `skopeo login` writes
containers-image's `$XDG_RUNTIME_DIR/containers/auth.json`; cosign reads
`$DOCKER_CONFIG/config.json`. The publish job now also runs `docker login`, which
both tools read.

### The handover no longer round-trips through a podman store

`podman load` in the publish job succeeded, and the very next step failed:

```
Loaded image: ghcr.io/bacondroid/kinrin-distro:latest
Error during unshare(...): Operation not permitted
```

`skopeo copy --all containers-storage:...` reaches podman's store through
`dial-stdio`, which needs a user namespace the runner does not grant that code
path. So the failure was not the image, the login, or the artifact: it was the
`containers-storage:` read, on a runner where podman itself worked fine one line
earlier.

The fix removes the dependency instead of working around it. bluebuild's
`--archive` already produced a gzipped OCI archive on disk, so that file is now
the artifact and the publish job reads it as `oci-archive:` — no `podman save`,
no `podman load`, and no podman in the publish job at all. Same image, one fewer
copy, and a transport that is a file read.

The build job still loads the archive into podman, because the gates have to run
against a real local image; only the *handover* changed.

### `sha256sum --check` needs the file's real name

The cosign install step downloaded the release binary as `cosign`, then verified
it with `grep 'cosign-linux-amd64$' checksums.txt | sha256sum --check --status`.
That check takes the filename *from the checksum line* and looks it up in the
working directory, so it failed with `sha256sum: cosign-linux-amd64: No such file
or directory` — on a checksum that was correct and a download that was intact. The
binary is now saved under its release name and only renamed by `install`.

### `--build-driver docker` plus `--archive`, forced by upstream's own source

The plan's §6 CI text assumes the image bluebuild built is sitting in the local
podman store when the gates start, so that `--pull=never` gates and a
`podman save` handover can share one storage. On a GitHub runner that never
happens, and not because of anything in this repository:

- `process/drivers/docker_driver.rs:556-558` passes `--load` **only** when
  `GITHUB_ACTIONS` is unset:

  ```rust
  ImageRef::Remote(_remote)
      if get_env_var(GITHUB_ACTIONS).is_err()
      && opts.platform.len() <= 1 => "--load",
  ```

  Upstream expects the result to be pushed. Without `--push` the image stays in
  the buildx builder's content store, which is exactly what the failing run
  showed: bluebuild logged `Finished building:` with all five tags while
  `docker images` on the same runner listed only the runner's own images and
  `moby/buildkit:buildx-stable-1`.
- `--archive` is the supported escape: it switches the driver to
  `--output type=oci,dest=FILE`, so the result is a file on disk instead of
  something in a daemon nobody reads. The load step reads the ref back out of
  `podman load`'s own stdout, because that output path applies no `-t` tag and
  the name is therefore not knowable in advance. The file is written as
  `<name>.tar.gz` (bluebuild's `ARCHIVE_SUFFIX`), so the glob must match
  `.tar.gz` and not `.tar`.

So the build job gains `--build-driver docker --archive`, plus one load step, and
everything downstream kept the plan's text — the `--pull=never` gates above all.
The handover it originally proposed, `podman save` plus `skopeo copy` from
`containers-storage:`, was then replaced too; see below. `--archive` is implemented only in the docker driver
(`podman_driver.rs` has no `LocalTar` arm), so `--build-driver docker` is
load-bearing for this reason, not as a preference.

Worth recording as method, because it cost six cycles: the podman version and
the podman-in-podman path (`podman_driver.rs:588`) are both real and both were
worth knowing, but neither caused the missing image. Three symptoms — "image not
known", a 403, and "no image after the build" — were read as three environment
differences when they were one upstream behaviour. The runner reports that podman
is 4.9.3 in a job that finishes in under a minute; reading a version number would
have cost one cycle instead of three.

### The publication, and why the first attempt at it closed the tab

The publication is one script — since run, and verified in §6: `~/Projects/kinrin-publish.sh`,
run as a script. `README.md` § "Publish it" carries the reasoning.

**Why a file and not a paste.** The first attempt was a block starting with
`set -euo pipefail`, pasted into an interactive shell. Nothing ran: no
`cosign.pub`, no secret, nothing committed, and the tab was gone. In an
interactive shell `set -e` terminates the *shell* on the first non-zero exit, so
one failure silently discards the rest of the sequence and takes the terminal
with it. Inside a script the same `set -e` can only end the script, which is
where the error message actually lands. That is the whole reason the sequence is
a file. It is idempotent, refuses to regenerate a key whose public half is
already committed (that would orphan the secret CI holds), and has a `--dry-run`
mode — itself tested here, because a dry run that asserts a state it did not
create is worse than no dry run.

**`COSIGN_PASSWORD=""` was never the problem**, which is worth recording because
it was my first suspicion and it was wrong. cosign v3.1.3, read at tag `v3.1.3`
(`11926fa5bbbbde47e88fc006b625a17769b743b2`):

```go
// cmd/cosign/cli/generate/generate_key_pair.go:130-147
func readPasswordFn(confirm bool) func() ([]byte, error) {
	pw, ok := env.LookupEnv(env.VariablePassword)
	switch {
	case ok:
		return func() ([]byte, error) { return []byte(pw), nil }
	case cosign.IsTerminal():
		return func() ([]byte, error) { return cosign.GetPassFromTerm(confirm) }
	default:
		return func() ([]byte, error) { return io.ReadAll(os.Stdin) }
	}
}
```

The guard is `case ok:` — **presence, never non-emptiness**. `os.LookupEnv`
returns `("", true)` for a present-but-empty variable, so `COSIGN_PASSWORD=""`
takes that arm and there is no prompt. Upstream asserts it:
`generate_key_pair_test.go:38-47` sets `COSIGN_PASSWORD` to the empty string and
requires `readPasswordFn(true)` to return an empty slice. Absent the variable,
the prompt reads `syscall.Stdin` — the controlling terminal — **twice**
(`pkg/cosign/common.go:28-53`), which is why the prefix form (which exports) is
required rather than `COSIGN_PASSWORD=""` followed by a semicolon, which does
not.

**And piping blank lines as a belt-and-braces would have been actively
harmful**, which is the part worth having checked rather than guessed: the only
prompt that reads piped stdin is the overwrite confirm, whose default is **N**
(`internal/ui/prompt.go:44-65`, "Are you sure you would like to continue? [y/N] "),
so empty input declines and aborts the command.

The generated key is an `ENCRYPTED SIGSTORE PRIVATE KEY` PEM
(`pkg/cosign/keys.go:205-213`, `encrypted.Encrypt` with no empty-passphrase
short-circuit) — scrypt'd over an empty passphrase, i.e. wrapped but trivially
recoverable. That is why the publish job needs no `COSIGN_PASSWORD` secret to
match, and why the README states the trade-off rather than calling it secure.
A passphrase-protected key needs `COSIGN_PASSWORD` added to the `Sign` step's
`env:` block, or the run blocks on a prompt that never comes.

`readPasswordFn` is byte-identical between v2.6.5 and v3.1.3 apart from the
`cosign/v2/…` → `cosign/v3/…` import rewrite: no behaviour change on this point.

**Visible in the API as well as the code:** with no packages scope the CLI
cannot even list packages — `gh api /users/BaconDroid/packages` returns "You need
at least read:packages scope to list packages" — which is why the visibility step
is documented as a browser action rather than presented as something that was
tried and worked.

Three details that are not obvious and are the difference between this working
and not:

- **`COSIGN_PASSWORD=""` is required**, not optional. `cosign
  generate-key-pair` otherwise blocks on an interactive password question, which
  in a non-interactive shell is a hang, not a prompt. It also produces an
  **unencrypted** key — which is why the publish job needs no
  `COSIGN_PASSWORD` secret to match. The trade-off is real and is stated in the
  README: the private half rests in a GitHub secret with no passphrase on top.
  Generate with a passphrase instead and add `COSIGN_PASSWORD` to the `Sign`
  step's `env:` block in `build.yml`, or the run blocks on a prompt that never
  comes.
- **`git add cosign.pub` is named, never a blanket add.** `.gitignore` lists
  `kinrin.tar` and `kinrin-oci.tar.gz` and nothing else — PROMPT requires the first
  and forbids ignoring `*.pub` — so nothing stops a `git add -A` from staging `cosign.key` between the
  two commands above. Naming the file is the whole mitigation.
- **`shred -u cosign.key` before the commit**, not after. The private half is on
  disk from step 1 until step 2 completes; deleting it immediately closes the
  window rather than leaving it open until the commit happens to run.

Afterwards the GHCR package must be made **public** in the browser — GHCR creates
it private, and the repository being public does not change that. The CLI token
in use carries `gist, read:org, repo, workflow` and **no packages scope**, so
`gh api` on the package endpoint is refused (`You need at least read:packages
scope`). That is an environment limit, stated here rather than presented as a
step that was tried and worked.

## 6. Published and verified

> The releases created during this session (`v44.1.0` … `v44.1.5`) were deleted
> when the trim in §7 was reverted, and their tags removed with them, so the
> version numbering restarts. The runs, the digests and the verifications below
> were real and remain a record of what was checked; the releases that pointed at
> them are gone.

Run `36821596275` — `validate`, `build` and `publish` all green — published and
signed the image, and it was then checked from outside CI:

```sh
skopeo inspect --format '{{.Digest}}' docker://ghcr.io/bacondroid/kinrin-distro:latest
cosign verify --key cosign.pub "ghcr.io/bacondroid/kinrin-distro@<that digest>"
podman pull docker://ghcr.io/bacondroid/kinrin-distro:latest
podman run --rm <image> sh -c 'niri validate --config /etc/niri/config.kdl'
```

What that established, in order:

- the digest for that run was
  `sha256:4f386308575ee33fd135dc03a2a78abb6fee9d5294d17b4b4d4ceeaa3a27e655`, and
  both `latest` and `2026-10-01` resolved to it;
- `cosign verify` passed all three checks: the cosign claims, the transparency-log
  entry, and the signature against the committed `cosign.pub`;
- a deliberately falsified digest was **rejected**, which is the part that
  matters — a verification that cannot fail proves nothing;
- the pulled image runs: `ID="kinrin"`, `ID_LIKE="fedora"`, `niri` reports
  `config is valid`, and `/etc/containers/policy.json` carries the
  `ghcr.io/bacondroid/kinrin-distro` key. The `optional include not found` warnings
  are the `optional=true` includes, absent on a fresh system by design.

**The digest above is that run's, and it is not a constant.** Every green run
republishes and moves `:latest` and the dated tag, and the workflow has no path
filter, so any push to `main` rebuilds. The authoritative digest is the one the
publish job prints in its log, in the `Capture digest` step — never a value copied
out of this file.

## 7. A trim that was measured, then reverted

An intermediate revision removed Discord, the Orca module and the whole compiler
toolchain to try to fit the ISO under GitHub's 2 GiB release-asset cap. It was
reverted after measurement, and the measurements are worth keeping because they
close off a whole class of ideas:

| Candidate | Raw | **Real gain, zstd** |
| --------- | --- | -------------------- |
| Locales (617 Mo, 699 languages) → `en`+`fr` | 591 Mo | ~110 Mo |
| `man` (8 877 pages, already `.gz`) | 43 Mo | ~19 Mo |
| `steam` + `steam-devices` (20 Mo of RPM) | 20 Mo | ~10 Mo |
| kde/plasma in full | 748 Mo | ~250 Mo |

Everything at once is ~650 Mo against a **2 740 Mo** gap. There is no path to
2 GiB that leaves a working desktop in place.

Two findings that generalise:

- **Steam is nearly free in the image.** The RPMs total 20 Mo; the ~1 Go client
  is downloaded on first launch. Removing it saved ~10 Mo and removed the main
  reason the image exists.
- **Raw sizes mislead.** Locales compress 617 Mo down to 161 Mo, so keeping 25 Mo
  buys ~110 Mo, not the 591 Mo the raw number suggests. Anything proposed as a
  size reduction must be measured *compressed*, with the codec the artefact
  actually uses.

A "download the locales during installation" script was also proposed and
rejected on grounds independent of size: it breaks offline installation, is not
idempotent, and buys nothing since `glibc-langpack-fr` is already in the enabled
repositories.

### What survived from that pass

**`plasma-discover-packagekit`.** `plasma-discover` pulls in only the Qt library,
never an engine, so `/usr/libexec/packagekitd` was absent and a search returned
nothing — Discover was installed and inert. The correct package is
`plasma-discover-packagekit`, which requires `PackageKit` and pulls the daemon
in; it is *not* `packagekit`, because RPM names are case-sensitive, and that
typo failed a build before the repositories were queried.

## 8. The ISO: measured, and why it is not a release asset

`bluebuild generate-iso image <ref>` builds the installer and the job reports its
size. The `iso` job prints it on every green build; the figures below come from
run `36899441370`, which built the **trimmed** revision described in §7 and has
since been reverted, so they are a floor rather than the current value:

| Quantity | Value |
| -------- | ----- |
| ISO (`deploy.iso`) | 5 092 212 736 B = **4.74 GiB** |
| artifact `kinrin-iso` | 5 050 159 141 B (zipped) |
| GitHub release-asset cap | 2 GiB |
| ISO structure | valid — `CD001` at offset 32769, volume `kinrin-x86_64-latest` |

Re-measured on the restored full recipe, run `36920786901`:

| Revision | ISO | artifact (zipped) |
| -------- | --- | ----------------- |
| trimmed (§7, reverted) | 5 092 212 736 B = 4.74 GiB | 5 050 159 141 B |
| **full recipe, current** | 5 757 272 064 B = **5.36 GiB** | 5 712 607 966 B |

So restoring Discord, Orca and the toolchain cost 0.62 GiB, and the guard behaved
correctly: `attachable=false`, a warning, and a release carrying `cosign.pub`
only — not a late failure with no explanation. The gap to the 2 GiB cap is now
3.36 GiB. The release job therefore publishes
`cosign.pub` only and says so with a warning, rather than calling
`gh release create` with an oversized file — that would fail *after* the release
exists, leaving a release with no ISO and no error to explain it.

### The size reductions that were measured and rejected

Every figure below is zstd on the real directory, which is the same codec the
installer squashes with. Raw sizes are misleading here and I quoted one earlier
without saying so:

| Candidate | Raw | **Real gain** |
| --------- | --- | ------------- |
| Locales (617 Mo, 699 languages) → `en`+`fr` | 591 Mo | **~110 Mo** |
| `man` (8 877 pages, already `.gz`) | 43 Mo | **~19 Mo** |
| `steam` + `steam-devices` (20 Mo of RPM) | 20 Mo | **~10 Mo** |
| kde/plasma in full | 748 Mo | ~250 Mo |

Locales compress 617 Mo down to 161 Mo — keeping 25 Mo of them buys about 110 Mo,
not the 591 Mo the raw figure suggests. `man` pages are already gzipped, so they
are close to incompressible.

**Steam is nearly free.** The RPMs total 20 Mo; the ~1 Go client is downloaded on
first launch, not embedded. Removing Steam to save space removes the main reason
the image exists for roughly nothing.

Cumulatively, everything above is ~650 Mo against a 2 740 Mo gap. There is no
path to 2 GiB that leaves a working desktop in place.

### Why there is no "download the locales during install" script

It was proposed and it is the wrong design, independent of the size arithmetic:
an installer that needs the network to finish leaves users on an offline machine
with a half-installed system, is not idempotent, and gains nothing — since
`glibc-langpack-fr` is already in the enabled repositories and
`dnf install glibc-langpack-xx` does the same job with no script.

### What survives of the trim

Not the size: the image is back to the full recipe and the ISO is larger than the
figure above. What survives is the machinery, which is the part that was missing
before any trimming was attempted — `generate-iso` running from the published
image, the measured size surfaced as a job output, the release attaching the ISO
when it fits and warning when it does not, and the download link in the release
notes. Before that, there was no ISO at all.

## 9. Steam/Proton tuning adopted from Bazzite

Read from `ublue-os/bazzite` (the org is no longer `UniversalBlue/*`, which 404s)
and filtered against this image: Kinoite + niri + DMS, not GNOME/KDE, not a Deck.

### Applied — two overlays, in the image

| File | Contents |
| ---- | -------- |
| `/usr/lib/sysctl.d/70-kinrin-gaming.conf` | `vm.max_map_count=2147483642`, `kernel.split_lock_mitigate=0` |
| `/etc/security/limits.d/60-kinrin-memlock.conf` | `memlock 2147484`, hard and soft |

`vm.max_map_count` matters because the default 65530 makes large titles fail to
start rather than merely degrade. `split_lock_mitigate=0` trades a security
mitigation for throughput — that is Bazzite's deliberate trade for a gaming
image, recorded rather than applied silently.

Both keys were checked with `sysctl -n` on the real kernel (`7.2.4-ogc3.1.fc44`)
before being written. `systemd-sysctl` ignores an unknown key without warning,
so a typo is indistinguishable from a setting that does nothing.

The presence gate was extended to cover both new destinations: 15 of 15 now.
A staged file that no gate checks is the false green PLAN §3.2 rules out.

### Applied — host-side, not in the image

**Steam shader precaching.** Steam precaches shaders single-threaded unless
`unShaderBackgroundProcessingThreads` is set in
`~/.steam/steam/steam_dev.cfg`. Bazzite writes it from a wrapper; there is no
image-side equivalent, and `~/.steam` is machine state on Atomic.

```sh
mkdir -p ~/.steam/steam
sed -i 's/^unShaderBackgroundProcessingThreads.*//' ~/.steam/steam/steam_dev.cfg
echo "unShaderBackgroundProcessingThreads $(( $(nproc) > 16 ? 16 : $(nproc) - 2 ))" \
  >> ~/.steam/steam/steam_dev.cfg
```

### Refused — `ntsync`

Bazzite loads `ntsync` from `modules-load.d/wine-ntsync.conf` to cut busyspin in
Proton games. **Fedora 44's kernel does not have it**:

```
modinfo ntsync  -> Module ntsync not found
```

`kyber` and `bfq` are absent too, so Bazzite's scheduler files have nothing to
bind to either. Writing the line would have produced a boot warning and no
benefit — cargo-culting a config from an image with a different kernel. It
becomes valid if the kernel ships it.

### Refused — the `extest` preload

Bazzite ships `libextest.so` and `LD_PRELOAD`s it for Wayland sessions, which is
what makes Steam Input and the Steam controller work there. Tempting for niri,
and PROMPT §826-832 rules it out in as many words: *"Do not ship it
speculatively… Host-side only: do not bake it into the image."* The reason is
persistence — a library under `/usr/lib64` is wiped by `bootc switch`, whereas
`/usr/local` is a symlink to `/var/usrlocal` and survives. The remedy already
documented in `TESTING.md` stays host-side and stays there until criterion 22
reproduces on real hardware, which it has not.

### Deliberately not taken

gamescope/MangoHud/umu from Terra's third-party repo, `nice -8` for Proton
(Bazzite keeps that in `deck/shared`, so it does not apply it to its own desktop
images either), Sunshine (its virtual monitor uses `kscreen-doctor`, KWin-only),
Waydroid, the whole gamescope session / `steamos-manager` stack, and every
Deck-specific preset.
