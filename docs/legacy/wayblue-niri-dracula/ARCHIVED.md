# Archived: wayblue-niri-dracula

This directory is a verbatim copy of the `wayblue-niri-dracula` repository,
archived here before that repository was deleted. The original was private.

## What the predecessor was

`wayblue-niri-dracula` was a **post-install customisation** of the upstream
Wayblue Niri image (`ghcr.io/wayblueorg/niri`, Fedora 44): `rpm-ostree` layering
plus idempotent scripts that

- themed DMS, Qt 6 (Kvantum + qt6ct), tmux and OpenCode with Dracula;
- replaced SDDM with the DMS greeter (`greetd` + `dms-greeter`);
- installed the DMS package tree from the `avengemedia` COPR;
- carried personal tweaks: IdeaPad accelerometer auto-rotate, a bilingual
  `en_CA`/`fr_CA` locale rule, display scale and fonts.

KinRin supersedes it: it **builds its own image** with BlueBuild instead of
layering on someone else's, so the installer scripts in `scripts/` are
historical. They are **not** how KinRin works. `install-wayblue-niri-dracula.sh`
and `apply-dracula-theme.sh` encode the manual, reversible procedure that was
performed on one machine; KinRin bakes the equivalent configuration into
`recipes/` and `files/` at build time.

## What was kept

The archive is complete except for the original `.gitignore` (secrets and
state-file rules, irrelevant to a documentation archive).

Two items remain directly useful and are documented in
[`../../HOST-SIDE.md`](../../HOST-SIDE.md):

- the **IdeaPad Flex 5 accelerometer auto-rotate** (`scripts/ideapad-tablet.sh`
  and `scripts/ideapad-tablet.service`);
- the **bilingual locale rule** (`en_CA.UTF-8` UI, `fr_CA.UTF-8` regional
  formats).

Everything else here — the Wayblue baseline notes, the theme-evaluation
methodology, the upstream-PR assessments, the Unraid AI-stack plan — is retained
for history only.
