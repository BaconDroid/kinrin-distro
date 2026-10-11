# Local overlay contract

This is the future location for local Dracula/DMS overlay and patch files. It currently contains no implementation and must never contain a copied checkout of the upstream theme.

Each overlay should:

- document the upstream project's provenance, exact release, tag, or commit, applicable license, and the specific reason the overlay is needed;
- state the exact upstream release, tag, or commit it targets;
- describe the upstream schema it expects and how that schema was verified;
- keep local changes separate from upstream files and limit them to deliberate enhancements;
- support review, dry-run application, removal, and rollback;
- preserve `DMS_DISABLE_MATUGEN=1` for static non-DMS application themes;
- contain no secrets or host-specific identifiers.
