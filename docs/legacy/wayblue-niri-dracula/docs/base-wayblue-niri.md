# Base Wayblue Niri

## Recorded baseline

- Signed image: `ghcr.io/wayblueorg/niri:latest`.
- The Fedora 44 snapshot was reported as `44.20260824.0`.
- A prior unmodified Wayblue deployment was available, with an Aurora fallback pinned.
- Initial package layering included `gh` and `tmux`.
- Later layering included DMS 1.5.3 and quickshell through the avengemedia COPRs.

## Validation warning

These are current notes, not immutable provisioning inputs. Before any change, validate the image signature, deployment status, pinned fallback, Fedora snapshot, layered packages, COPR state, and available versions on the target system. Do not hardcode the recorded date or a digest without a deliberate update and verification.

Future automation should preserve the known-good deployment, keep rollback available, and report exactly what differs from this baseline.
