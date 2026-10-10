# Customization repository — scope and visibility

Default decision (pending final user confirmation):

- **Keep the repo local and private for now.** No remote is configured and none
  should be added until the user decides.
- Purpose: reusable, version-controlled record of the Wayblue/Niri + DMS +
  Dracula setup: theme overlays, comparison methodology, installer script, and
  future patches.
- Structure:
  - `overlays/` — DMS theme JSON overlays (e.g. `dracula-local-overlay.json`).
  - `docs/` — methodology, evaluations, plans.
  - `scripts/` — installer / provisioning scripts (idempotent, reversible).
  - `README.md` — overview and safe-apply instructions.

## Open questions (deferred to user)
- Public or private? If public, which license (Dracula assets are MIT; DMS
  overlay is a derivative — confirm compatibility).
- Fork or upstream PR for the DMS Dracula overlay and the Ideapad tablet script?
- Should the installer script target a generic Wayblue/Niri audience or stay
  personal?
