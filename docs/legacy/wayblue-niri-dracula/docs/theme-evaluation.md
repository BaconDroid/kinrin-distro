# Cross-shell Dracula theme evaluation

This is the durable method for evaluating or updating Dracula theme ports across shells. It preserves the procedure, not any particular comparison result; official upstream themes may change.

## Procedure

1. Start with official upstream theme ports only. Record the exact source URL, version or tag, commit SHA, and review date for every source.
2. Preserve each upstream original unchanged. Create a separate local derived theme or overlay for deliberate local changes; never edit or silently fork upstream content.
3. Establish and verify DMS global Dracula roles first; treat them as the semantic color-role registry. Inventory visible hardcoded DMS color roles and determine complete color coverage. A canonical Dracula color may serve multiple semantically compatible roles; prevent incoherent reassignment, not duplicate use. For example: red for error and critical thermal; green for success and highest quality; orange for medium quality and elevated thermal; yellow for generic warning.
4. Normalize and compare visual parameters only when they are conceptually equivalent. Use an evidence matrix covering: colors and state roles; surfaces; text and icons; borders and separators; gradients and opacity; shadows and blur; corner radius; typography; spacing; and widgets.
5. Mark a parameter **absent**, **not exposed**, or **not comparable** when appropriate. Do not infer a value from a different parameter or from visual similarity alone.
6. For conceptual equivalents, prefer the most recurrent mapping among official ports. A single-source value may transfer only to the same target semantic role and only when no competing official mapping exists; otherwise retain the target upstream value or leave it unassigned.
7. Treat semantically meaningful, visible hardcoded Material colors in the target shell as occupied color categories. Inventory them by component and role before assigning unused Dracula colors to missing configurable roles; do not replace them merely because they are Material. Preserve distinct semantics—for example, an independently hardcoded orange codec-quality state does not require warning to change from yellow.
8. Only after the DMS-first baseline, plan justified source-level Material adjustments using the established mapping. Keep theme-JSON roles distinct from hardcoded source behavior; source changes are not an automatic theme conversion step.
9. Label each observation as **recurring evidence** (seen consistently across relevant official ports), **single-source evidence** (seen in one source), or a **local convention** (chosen for this project rather than established upstream).
10. Re-run the hardcoded-color audit and evidence matrix whenever target or upstream code changes, then review the local mapping before updating the derived theme.

The matrix is review evidence, not a timeless rule set. Keep source results tied to their recorded versions and make the procedure regenerable; do not preserve a current color matrix as permanent truth. Keep the dated source records and original upstream material alongside any derived mapping so a later review can distinguish changed upstream behavior from a changed local choice.
