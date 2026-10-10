# KinRin documentation

This directory holds the specification and design history that the image in this
repository implements. The root [`README.md`](../README.md), [`NOTES.md`](../NOTES.md)
and [`TESTING.md`](../TESTING.md) cite sections of the plan as **`PLAN §…`** — that
plan is [`PLAN.md`](PLAN.md) here.

| File | What it is |
|---|---|
| [`PLAN.md`](PLAN.md) | The specification. Every `PLAN §n` reference in the root docs resolves here. ~1000 lines, one paragraph per line (line numbers are not stable across revisions). |
| [`DOSSIER.md`](DOSSIER.md) | The rationale and history behind the plan's decisions, including the dead ends. Read this when a decision in the plan looks arbitrary. |
| [`PROMPT.md`](PROMPT.md) | The original build prompt that produced this repository. |
| [`HOST-SIDE.md`](HOST-SIDE.md) | Machine-specific customizations deliberately kept out of the image (Ideapad auto-rotate, bilingual locale), carried over from an earlier project. |
| [`legacy/wayblue-niri-dracula/`](legacy/wayblue-niri-dracula/) | Full archive of the predecessor project. See its [`ARCHIVED.md`](legacy/wayblue-niri-dracula/ARCHIVED.md). |

## Provenance

KinRin grew out of two earlier efforts, both consolidated here:

- the **specification** (`PLAN.md`, `DOSSIER.md`, `PROMPT.md`), previously in a
  separate repository. It was moved here so the plan and the image it describes
  live together, and so the `PLAN §…` references in the root docs resolve in-repo.
- **`wayblue-niri-dracula`**, a *post-install* customization of the upstream
  Wayblue Niri image. KinRin supersedes it by building its own image instead of
  layering on an existing one. The predecessor is archived verbatim under `legacy/`
  so nothing is lost; the two items from it worth keeping are documented as
  host-side steps in [`HOST-SIDE.md`](HOST-SIDE.md).

Nothing under `docs/` is part of the build. The image is defined entirely by
[`recipes/`](../recipes) and [`files/`](../files) at the repository root.
