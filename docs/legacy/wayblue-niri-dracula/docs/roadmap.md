# Roadmap

Future work should be split into small, reversible modules:

1. **Base validation** — inspect image, deployment, fallback, snapshot, layering, signatures, and package sources before changing anything.
2. **DMS installation** — make the third-party avengemedia COPR trust decision explicit, validate package identity and version, and provide removal/rollback steps.
3. **Niri integration** — install or configure the DMS integration only after checking the Niri version and existing state.
4. **Dracula theme** — consume the official MIT-licensed upstream DMS theme at a pinned revision, verify its schema before updates, evaluate cross-shell ports with the evidence matrix in `docs/theme-evaluation.md`, and apply local enhancements only through separate files under `overlays/`.
5. **SDDM and locales** — stage Qt6 theme and locale changes separately, with login and recovery checks. Validate locales with `locale -a`; prefer `en_CA.UTF-8` for UI language and `fr_CA.UTF-8` for numeric, date, currency, and measurement formats. Fall back to `fr_CA.UTF-8` for language or `en_CA.UTF-8` for regional formats when the preferred locale is unavailable. Both are currently available, so fallback is not used.
6. **KDE 6.11 fallback** — track the temporary Kvantum gap. Stage the documented Fedora Qt6 RPM replacements with `rpm-ostree`, reboot, run the final Dracula phase, and validate before removing equivalent Flatpaks; Kontainer and KTailctl remain Flatpak.

Every module should support idempotent re-runs and dry-run output, back up files before edits, avoid secrets, and describe rollback. Keep `DMS_DISABLE_MATUGEN=1` for static non-DMS app themes. Testing should cover a fresh run, a second run, interrupted execution, reboot/login behavior, package updates, upstream schema changes, overlay removal, and restoration of the prior deployment. No module should be considered complete until its rollback has been exercised.
