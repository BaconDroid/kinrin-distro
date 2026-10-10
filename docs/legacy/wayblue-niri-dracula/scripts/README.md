# Script contract

Installer modules live here. `install-wayblue-niri-dracula.sh` provisions the
base setup; `apply-dracula-theme.sh` is the final, post-reboot theme phase.

## Installation order

Run the base installer first. Stage any optional Fedora Qt6 RPM replacements
with `rpm-ostree`, then reboot. Run `scripts/apply-dracula-theme.sh` only after
the reboot as the final theme phase, validate that the applications start and
are themed correctly, and only then remove their equivalent Flatpaks. The
KDE 6.11 mapping and fallback procedure are maintained in
[`docs/dracula-application.md`](../docs/dracula-application.md).

Each script should:

- validate the current Wayblue/Niri state before acting;
- be safe to run repeatedly (idempotent);
- support an explicit dry-run mode that makes no changes;
- create named, restorable backups before modifying user or system files;
- avoid secrets and use generic `$HOME` paths;
- report package sources, trust decisions, changed files, and failures clearly;
- fail safely and document a tested rollback command or procedure.

Scripts should not silently replace existing configuration, assume a particular snapshot date or digest, or require interactive prompts for normal operation. A future test harness should cover fresh, repeat, interrupted, reboot/login, and rollback scenarios.
