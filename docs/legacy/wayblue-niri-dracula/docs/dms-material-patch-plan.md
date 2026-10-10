# DMS hardcoded Material-color → Dracula patch plan

Status: planning. Do NOT edit `/usr` or DMS source directly yet. This is the
next-phase work after the DMS Dracula base is validated visually.

## Why
DMS renders some roles with hardcoded Material Design colors instead of theme
roles. These are visible but outside the `dracula-local-overlay.json` palette,
so they cannot be changed by the theme JSON. They are legitimate coverage only
if no equivalent Dracula role exists; otherwise they should be patched to the
Dracula equivalent.

## Confirmed hardcoded Material roles (from earlier audit)
- `BluetoothService.qml`: codec quality colors
  - high quality  → green
  - medium quality → orange
  - balanced       → blue
  - basic          → gray
  These are separate from `Theme.warning` (yellow) and must stay distinct.
- Temperature / resource widgets:
  - warning threshold → orange
  - critical threshold → red

## Dracula mapping (semantic, not 1:1 hex copy)
| Material role            | Dracula color | hex          | note |
|--------------------------|---------------|--------------|------|
| high quality / success   | green         | `#50FA7B`    | already used as `success` in overlay |
| medium quality / warning | orange        | `#FFB86C`    | distinct from `warning` yellow |
| balanced / info          | cyan          | `#8BE9FD`    | info role |
| basic / surface          | comment gray  | `#6272A4`    | low-emphasis |
| critical / error         | red           | `#FF5555`    | error role |

Rule: keep each role semantically distinct; do not collapse green/orange/red
into one color. A color may serve multiple compatible roles (e.g. green =
success + highest quality).

## Implementation path (upstream-first)
1. Fork `AvengeMedia/DankMaterialShell` (or use local fork `atomic-rebase-fork`
   pattern). Do NOT patch `/usr` on the running system.
2. Replace the hardcoded hex values in the identified QML files with either:
   - the existing DMS `Theme` role when one matches (preferred), or
   - a new Dracula role added to `Theme.qml` + the overlay JSON.
3. Build/install the forked DMS via COPR or local layering (same pattern as the
   current DMS 1.5.3 layer).
4. Keep `DMS_DISABLE_MATUGEN=1`; verify `dms doctor --json` and visual check.
5. Optionally open an upstream PR against `AvengeMedia/DankMaterialShell` and/or
   propose the Dracula role additions to `dracula/dms` if that repo accepts
   community themes.

## Open questions (deferred to user)
- Exact QML line numbers in the forked tree (re-audit after fork clone).
- Whether upstream wants the new roles or prefers the hex literals.
- Whether to also patch the GTK/Qt Dracula layers for parity (separate task).
