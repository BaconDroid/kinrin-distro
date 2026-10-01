# Testing KinRin

PLAN §8 is a **human** checklist, meant to be run by hand on a real machine. The
monthly CI runs none of it: no GPU, no graphical session, no gamepad, no game to
buy. Four criteria (28 and 28b) are automated and live in CI instead — see
"Automated checks" at the bottom.

Everything below is numbered as in the plan, so a criterion can be cited as "§8
criterion 23" without ambiguity. Keep the numbers stable.

## Session and desktop

- [ ] **1.** niri starts.
- [ ] **2.** DMS starts with niri: bar, launcher, controller, notifications.
- [ ] **2b.** DMS shortcuts work: `Mod+Space`, `Mod+N`, `Mod+Alt+L`.
- [ ] **2c.** Default state — no remote pre-activated. `flatpak remotes --system`
      is empty, and `readlink /etc/systemd/system/flatpak-add-fedora-repos.service`
      is `/dev/null`. **The mask is the mechanism that survives into the image**,
      because `/etc` is versioned with the deployment while the marker in
      `/var` does not. If `/var/lib/flatpak/.fedora-initialized` is also there,
      that is a bonus, not the check.
- [ ] **2d.** DMS starts **exactly once** under niri and **not at all** under
      Plasma. `systemctl --user list-dependencies niri.service` shows
      `dms.service`; `graphical-session.target` is `active` in the niri session;
      the generated `config.kdl` holds no `spawn-at-startup "dms"` autostart
      (niri spells it that way, not `dms run`); and logging into Plasma starts
      no DMS.
- [ ] **3.** KDE portal selected —
      `busctl --user list | grep org.freedesktop.impl.portal.desktop` shows
      `…desktop.kde`. Then Spectacle capture, screen sharing, the file picker,
      and Discord in-call screen share. Do not check the theme here:
      `QT_QPA_PLATFORMTHEME=gtk3` forces gtk3 by design.

## Login and policy

- [ ] **4.** Polkit: the USB key action and the NetworkManager action each
      trigger **exactly one** prompt, never two, **and the prompt can actually be
      answered** — authenticate at each one. Counting alone is not a pass: a user
      outside `wheel` still gets exactly one prompt per action, so the count
      looks right while the authentication failed. This is why the session user
      must be in `wheel`. One prompt for the pair is also not a pass.
- [ ] **5.** `rpm -q dolphin konsole kate plasma-discover` all resolve — three
      of the four ship in the Kinoite base, so **`kate` is the genuine addition**
      and its presence is what proves the package list was installed — then each
      app is present and usable.
- [ ] **6.** Plasma still starts and works. Two commands, because the session
      file and the command resolve separately and either can be missing while
      the other works:
      `ls /usr/share/wayland-sessions/` lists **both** `niri.desktop` and
      `plasma.desktop`, and `test -x /usr/bin/startplasma-wayland` passes.
- [ ] **7.** PipeWire audio: playback and microphone.
- [ ] **8.** Suspend and resume.
- [ ] **8b.** Closing the laptop suspends. `plasma-workspace` pulls
      `powerdevil`, which wants to own lid and power events, so this criterion
      **observes** which of the two wins: confirm `HandleLidSwitch=suspend` is
      in `/etc/systemd/logind.conf.d/kinrin.conf` and that PowerDevil's own
      setting did not override it. Do **not** edit
      `/etc/systemd/logind.conf` to make this pass — that file is shipped by a
      package, and the drop-in is what the image ships.
- [ ] **11.** `dms-greeter` displays and lets you log in. **Then run the
      first-boot check**, because a greeter that renders is not evidence that
      the display manager wiring is right:

      ```bash
      systemctl get-default                                    # graphical.target
      systemctl is-enabled greetd                              # enabled
      systemctl is-enabled plasmalogin.service                 # disabled or not-found
      systemctl is-enabled sddm.service                        # disabled or not-found
      ```

      All four must hold. Checking only the `display-manager.service` symlink
      passes **vacuously** if the base ever enables `plasmalogin.service`
      directly — and a second display manager racing greetd for VT1 is the same
      unsettled boot. Run `dms-greeter enable` only if the target or greetd is
      actually wrong: the recipe already does the equivalent, and
      `dms-greeter enable` labels nothing, so it is a first-boot check rather
      than a build step.
- [ ] **12.** **After 12b's `dms-greeter sync`**, the greeter shows the DMS theme
      colours from the same theme file: Dracula, not a second hand-picked theme.
      No wallpaper claim — none ships. This is a **continuation of 12b, not an
      independent test**: on a freshly installed image, before any login, this
      criterion **fails by design**. Check it last, and do not "fix" it by
      editing a theme file.

### 12b. The greeter theme, by symlink

The greeter theme is **symlinked into the greeter cache, never generated
locally**. `dms-greeter sync` links three files from the session user's home
into `/var/cache/dms-greeter/`: `settings.json` and `session.json`, plus
`colors.json` from the DMS colour cache. A source that does not exist is created
empty first, so a fresh home yields three symlinks onto three `{}` files rather
than an error — and the greeter still renders the same theme without ever
running matugen.

Check, after the first login:

1. The session user is in the `greeter` group — `sync` tests for it and either
   adds it non-interactively or prompts for it. Pre-add it instead:
   `sudo usermod -aG greeter "$USER"`, then log out and back in. (This is
   unrelated to DRM access, which is a logind ACL.)
2. `dms-greeter sync`, run **as the session user** — it self-elevates and the
   cache is `chmod 2770`, so no outer `sudo` is needed.
3. `ls -l /var/cache/dms-greeter/` shows all three as **symlinks** into that
   home.

The shipped README's wording that `sync` "copies" the theme is loose; the code
and the binary both link the root files.

- [ ] **13.** The greeter is **expected** to list niri. Record whether it also
      offers Plasma — either way, the guaranteed path is `Ctrl+Alt+F3` then
      `startplasma-wayland`, so criterion 6 covers the fallback independently of
      what the greeter shows.

## Hardware

- [ ] **9.** An X11-only app starts, which also tests `xwayland-satellite`.
- [ ] **10.** niri CPU at idle: leave the session untouched for 5 minutes, then
      sample for 60 s — `top -b -d 1 -n 60 -p "$(pgrep -x niri)"`. Expect under
      2 % of one core averaged over those 60 samples with no window open. The
      5-minute settle and the 60-sample average are the method; a single `top`
      reading right after login is not a measurement.
- [ ] **14.** AMD: nothing to install. Each AMD GPU present is on `amdgpu` — a
      single-GPU AMD machine satisfies this, the wording is not tied to a second
      adapter — and `vainfo` reports a working VA-API profile.
- [ ] **15.** Intel: `libva-intel-media-driver` shipped, and `vainfo` confirms it
      **on the target GPU**. This is the one open hardware item; the package name
      is settled, its behaviour on the specific adapter is not.
- [ ] **16.** The greeter displays with no extra group: `getent group input` does
      not contain `greeter`. A black screen is read in `journalctl -u greetd`,
      not fixed with rights.
- [ ] **17.** Change the DMS theme and the **niri colours follow live**. This
      only happens because `~/.config/niri/config.kdl` exists, so niri's
      includes resolve into the home where matugen writes — that is exactly what
      the skel copy of §4.5 is for, and its absence is invisible until this
      criterion runs.
- [ ] **18.** Secure Boot, only if you use it. It tests the base, not this image.

## Games

- [ ] **19.** `steam` opens as an RPM, present without manual installation, and
      the window is not black.
- [ ] **20.** A Proton game starts, Steam having downloaded Proton itself. Check
      cursor and fullscreen — `gamescope` is **not** shipped, so this is the
      un-wrapped path.
- [ ] **21.** VRR: the game triggers the `steam_app_*` rule from `local.kdl` and
      the frame rate actually varies.
- [ ] **22.** Plugging in a gamepad does not crash Steam; then
      `getfacl /dev/uinput` shows the logind ACL on the session user, who is
      **not** in `input`. If Steam *does* crash on gamepad connect, that is a
      **host-side** `extest` preload, not an image defect: see the note at the
      bottom of this file. Apply it, re-run, and only then file the result.

## Apps and configuration

- [ ] **23.** `/etc/skel/.config/niri/dms/binds.kdl` still carries DMS's default
      keybinds **and** the prepended `include optional=true "../local.kdl"`;
      `/etc/skel/.config/niri/local.kdl` carries the window rules. Both are
      seeded at first login, niri accepts the chain, and `Mod+Space` still opens
      the launcher. A `binds.kdl` holding only the include suppresses every
      default bind — that is the failure this criterion exists to catch.
- [ ] **24.** `dnf repolist` shows `rpmfusion-free` and `rpmfusion-nonfree`, and
      `dnf repoinfo rpmfusion-free` prints an `OpenPGP` `Keys` line naming an
      `RPM-GPG-KEY-rpmfusion-free` file and `Verify packages : true`. Assert on
      those two lines, **not** on `GPG check : enabled` — dnf5 never prints it.
      Note `dnf repoinfo <unknown-id>` prints `No matches found.` and still exits
      0, so a typo cannot fail this criterion on its own.
- [ ] **25.** ~~`discord` starts and its in-call screen sharing goes through the
      portal.~~ **Not in the image** — Discord was removed for ISO size, after
      measuring that Steam must stay. Re-add it first
      (`sudo dnf install discord`), then this criterion applies unchanged; the
      portal path it exercises is in the image either way.
- [ ] **26.** `/etc/environment.d/90-dms.conf` is valid `KEY=VALUE` and
      `systemd-environment-d-generator` accepts it, and the three DMS variables
      are set in the `niri.service` and `dms.service` drop-ins **only** — no
      `environment.d` file carries them, and nothing the Plasma session inherits
      does either. A Plasma session started from a TTY inherits none; an app
      launched from DMS inherits all three. `XDG_CURRENT_DESKTOP` is in **both**
      drop-ins, not only the niri one.
- [ ] **27.** `rpm -q xwayland-satellite` resolves **and** an X11 app really
      starts under it. `steam` is not that test — the RPM is 64-bit, only its
      dependencies are 32-bit — so use criterion 9 for the X11 smoke test and
      this one for the package.
- [ ] **29.** ~~orca starts under niri, opens a worktree and renders its integrated
      terminal~~ **Not in the image** — the module that installed it was removed for
      ISO size, and it is the one removal that is not a `dnf install`, because it
      came from a GitHub release RPM rather than a repository. Restore
      `recipes/modules/orca.yaml` (steps in `NOTES.md`) before running this. Its
      RPM dependencies resolve in the image either way, and it is an Electron app,
      so GTK/sandbox behaviour depends on
      version. **opencode is not part of this criterion**: answering needs a model
      provider, credentials and a network, none of which the image supplies.
- [ ] **30.** After a theme change and then
      `dms setup headless --compositor niri --skip-existing`:
      `~/.config/niri/dms/binds.kdl` still holds
      `include optional=true "../local.kdl"`, still holds `Mod+Space`, and
      `local.kdl`'s rules still apply. Note what that flag buys you: with
      `config.kdl` already present, the command **returns without deploying
      anything**, so this is a statement about what survived, not about a
      re-deploy.
- [ ] **31.** VRR is applied by the IPC unit, not a config file:
      `niri msg outputs` shows `Variable refresh rate: supported, enabled` after
      login, on **every** output, and `niri-vrr.service` was **started by the
      `niri.service` drop-in** — it is not enabled anywhere, and a Plasma session
      never starts it. The on-demand half is not observable over IPC; it is
      covered by the per-window `variable-refresh-rate true` rule plus criterion
      21's observed frame-rate variation.
- [ ] **32.** Opt-in path: the one-liner that adds Flathub works, Flathub
      appears, then removing it leaves the system clean again.
- [ ] **33.** The built image fits twice on the OSTree partition: two
      deployments coexist, so rollback is real.
- [ ] **34.** At first login, with nothing touched, DMS is in Dracula Dark; the
      theme is listed in **Settings → Theme**; flipping DMS day/night gives
      Alucard Light. The file behind it passes the build-time shape check
      (`jq -e 'has("dark") and has("light") and (.dark.surfaceContainerLowest |
      type == "string") and (.light.surfaceContainerLowest | type == "string")'`)
      first, so a wrong copy cannot reach this point silently. The theme will
      **not** appear under **Browse Themes**: that list is remote-registry only.
- [ ] **35.** `~/.config/niri/dms/colors.kdl` and
      `~/.local/share/color-schemes/DankMatugen*.colors` exist and are rewritten
      on a theme change, and the Plasma fallback shows the same colours.

## Automated checks — criteria 28 and 28b

These run in CI and are the only four checks on the image:

- [ ] **28.** `niri validate --config /etc/niri/config.kdl` passes **inside the
      built image** — a bare call on the host is not a gate, the binary is absent
      from a CI runner and it would not see the image — and `bluebuild validate`
      passes on the recipe, and the presence chain over the `files.yaml`
      destinations passes inside the same image.
- [ ] **28b.** The signing policy covers the reference actually published. CI
      does not merely print the keys — it asserts, inside the image:
      `jq -e --arg r "ghcr.io/$OWNER/$REPO" '.transports.docker | has($r)'`.
      A mismatch means boot-time verification of the published image resolves
      nothing, and printing the key would have passed on such a mismatch.

CI adds two more: the `ID=kinrin` / `ID_LIKE=fedora` greps on `/etc/os-release`,
and `cosign verify` against the pushed digest.

## Note on criterion 22 and the `extest` preload

If criterion 22 reproduces a Steam crash on gamepad connect, the remedy is
**host-side, never baked into the image**: on Atomic `/usr/local` is a symlink to
`/var/usrlocal`, so it is machine state under `/var` — the persistence the image
relies on — and nothing needs redoing after a `bootc switch`. Take
`extest.c` from the fork `nmd2k/extest-steam-input-fix`; the object must be
**x86_64**, because a 32-bit object cannot be preloaded into Fedora's 64-bit
`steam`. Clone the shipped launcher and edit its `Exec` — never write a stub,
and never edit or mask the RPM's own file in `/usr/share/applications/`.
