# Instructions for the current branch rebuild

These instructions apply only to the current work: manually reapplying and reviewing the changes from `playground_draft` onto `playground` to produce a more deliberate implementation and commit history. They are not permanent repository policy.

## Porting groups and order

Use the following order as the starting plan, with one focused commit per group. Bring relevant binding tests alongside each group's implementation. Review the draft's final design without replaying intermediate implementations that were later replaced. Deliberate revisions may change dependencies or require adjusting later groups. Shared files may be extended across groups.

| Order | Group | Description |
| --- | --- | --- |
| 1 | Property setter fix | Correct the reflected setter's value type and cover writable and read-only property bindings. |
| 2 | Userdata safety | Consolidate allocation-header tagging and checked wrapper extraction. |
| 3 | Code generation refactor | Introduce shared invocation and overload generators and the cleaned-up CodeWriter, preserving existing behavior. |
| 4 | Ref/out arguments | Add value-by-ref binding and explicit ref/out argument hints. |
| 5 | Numeric arguments | Add integer, enum, float/double hints and overload diagnostics. |
| 6 | Typed null arguments | Add typed null-pointer hints and their conversion rules. |
| 7 | Span conversion | Add fixed input spans from Lua tables and caller-scoped GetSpan conversion. |
| 8 | AutoTink policy | Consolidate method exclusions, unsupported-constructor filtering, and binding policy in the extension module. |
| 9 | Owned values | Add primitive reference cells and owned structs using the reviewed inline userdata design. |
| 10 | Constructed class ownership | Add inline storage for Lua-constructed classes and conditional leak-tracking roots. |
| 11 | Pointer/string conversion | Add exact pointer matching, typed wrappers for void pointers, char8 pointer arguments, and explicit C-string conversion. |
| 12 | Callable values | Bind callable function pointers and live namespace fields. |
| 13 | Coroutine runtime | Share state with the main thread, propagate resume errors, and add the draft's GC stepping workaround with its documented limitations. |
| 14 | Native SDL Playground | Add the native entry point, final SDL bindings, and basic renderer demo. |
| 15 | OpenGL Playground | Add explicit contexts, entry-point validation, enums, and the finished shader demo. |
| 16 | Image and audio support | Add image and mixer bindings, dependencies, and resource ownership. |
| 17 | WebAssembly support | Add platform configuration, browser execution, and WasmSample. |
| 18 | Browser workspace | Add the editor, folder tree, persistence, reset/download controls, and entry-point selection. |
| 19 | Bundled games | Add the final Rope, modular Breakout, and SpaceGame implementations with resources and preload entries. Split into one commit per game if needed for review. |
| 20 | Documentation and archives | Consolidate final README/TODO updates, ignores, maintenance reviews, and saved experiment patches. Preserve archived patches as artifacts rather than applying them. |

## Review and reporting rules

- Treat `playground_draft` as the baseline for review, not an implementation that must be copied exactly. Deliberate revisions may require corresponding changes in later steps.
- For all tests brought over or changed during this work, focus assertions on LuaTinker's bindings and observable interop behavior. Remove assertions whose only purpose is to validate a bound dependency's implementation or invariants.
  - Keep suitable existing dependency types as binding targets. Removing dependency-behavior assertions does not imply replacing the target with a custom fixture. Review assertions individually and make the smallest relevant change.
  - Preserve meaningful negative binding coverage, including rejected writes to read-only properties. Do not remove such coverage merely because the property belongs to a dependency.
- In the user-facing reply, report changes from the draft baseline, including implementation differences and assertions or scenarios added, removed, or changed, with reasons. Identify a different baseline explicitly if one is used. Distinguish test-scope changes from intentional changes to the binding contract, and report validation results and execution blockers separately.
- Keep this file limited to instructions for this work. Do not record review history or individual change reports here.
