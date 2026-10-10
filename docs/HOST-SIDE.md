# Host-side customizations

Two things from the predecessor project (`legacy/wayblue-niri-dracula/`) are
**not** baked into the image. KinRin ships a generic artefact; these are personal
or hardware-specific, so they belong to the installed machine.

---

## 1. Bilingual locale (en_CA UI, fr_CA regional formats)

Rule, as the predecessor recorded it:

- `LANG=en_CA.UTF-8` — UI language, English (Canada).
- `fr_CA.UTF-8` — numeric, date, currency, measurement and paper formats.
- If the preferred locale is missing, fall back to `fr_CA.UTF-8` for the
  language, or `en_CA.UTF-8` for the regional formats. Validate with `locale -a`.

Apply on the installed system (`localectl` write is system-wide and needs root):

```bash
sudo localectl set-locale \
  LANG=en_CA.UTF-8 \
  LC_NUMERIC=fr_CA.UTF-8 LC_TIME=fr_CA.UTF-8 \
  LC_MONETARY=fr_CA.UTF-8 LC_MEASUREMENT=fr_CA.UTF-8 LC_PAPER=fr_CA.UTF-8
```

**Why it is not in the image.** A system-wide locale would force Canadian formats
on every user of the image, and `localectl`'s answer is `/etc/locale.conf`, which
is not a per-user file. If it were ever wanted at image level, the place is a
skeleton file under `files/` — for example
`files/etc/skel/.config/environment.d/` — but that is a deliberate decision for a
personal image, not a default.

---

## 2. IdeaPad Flex 5 accelerometer auto-rotate

The IdeaPad Flex 5 15ALC05 exposes an accelerometer. Rotation is driven over
D-Bus by `monitor-sensor` (from `iio-sensor-proxy`), so it needs **no root, no
`input` group, and no raw event-device access**. The display transform is applied
with `niri msg output eDP-1 transform …`.

The archived script and its user unit:

- `legacy/wayblue-niri-dracula/scripts/ideapad-tablet.sh`
- `legacy/wayblue-niri-dracula/scripts/ideapad-tablet.service`

### The package is the catch

The script exits cleanly if `monitor-sensor` is absent, but it cannot rotate
anything without `iio-sensor-proxy`. That package is **not installed by KinRin**.
Two ways to get it, and the project's rule picks one:

- **Preferred (fits the image):** add `iio-sensor-proxy` to
  [`recipes/modules/dnf.yaml`](../../recipes/modules/dnf.yaml) and rebuild. KinRin
  is "rebuilt, never patched", so this is the route that stays consistent.
- **One-off (for a single machine):** layer it with `rpm-ostree install
  iio-sensor-proxy` and reboot. This is a layer, which the project deliberately
  avoids — acceptable for one laptop, but it is exactly the kind of drift the
  BlueBuild model exists to remove.

### Install the script and unit (per user)

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp legacy/wayblue-niri-dracula/scripts/ideapad-tablet.sh        ~/.local/bin/
cp legacy/wayblue-niri-dracula/scripts/ideapad-tablet.service   ~/.config/systemd/user/
chmod +x ~/.local/bin/ideapad-tablet.sh
systemctl --user enable --now ideapad-tablet.service
```

The unit is `PartOf=graphical-session.target` and `After=niri.service`. The script
takes `NIRI_SOCKET` from the environment, or discovers it under `$XDG_RUNTIME_DIR`
when systemd starts it before niri has exported its environment.

If the panel rotates 90° off, swap the `right-up` / `left-up` mappings in the
script.
