# Wayblue Niri Dracula

Personal Wayblue/Niri provisioning notes, AI-consumable plans, and reversible
scripts. It stores curated configuration and upstream-derived overlays, never
secrets or an unreviewed machine snapshot.

## Intended goals

- Record the known Wayblue Niri baseline and deliberate desktop choices.
- Evolve toward small, reversible provisioning modules for Niri, DMS, Dracula styling, SDDM, and locales.
- Consume the official MIT-licensed Dracula DMS theme while keeping local changes in separate overlays.
- Evaluate cross-shell theme ports using the documented, source-pinned evidence method in [`docs/theme-evaluation.md`](docs/theme-evaluation.md).
- Keep the project understandable and safe to publish if it later becomes public.

## Upstream theme policy

Future modules must use official upstream themes whenever available. Add a local overlay only for missing or incomplete coverage; never silently fork or modify a copied upstream theme. Every overlay must document its upstream provenance, exact version or revision, license, and the reason the overlay is needed.

## Safety stance

Any future installer should be idempotent, offer a dry-run mode, create clearly named backups, and provide a tested rollback path. Changes should be explicit about package sources and trust boundaries, and should validate the current system before making assumptions.

Do not store passwords, tokens, private keys, machine-specific identifiers, or other secrets here. Use generic `$HOME` paths in examples. Do not hardcode a snapshot date or image digest as a substitute for current validation.

## Documentation status

The notes distinguish confirmed observations from work in progress. They are a planning baseline, not an assertion that the current machine still matches every item.

The temporary KDE 6.11 Qt6 RPM fallback is staged pending reboot and
application/theme validation. Follow the ordering in
[`docs/dracula-application.md`](docs/dracula-application.md) before removing
equivalent Flatpaks.
