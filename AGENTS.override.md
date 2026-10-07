# Instructions for the current branch rebuild

These instructions apply only to the current work: manually reapplying and reviewing the changes from `playground_draft` onto `playground` to produce a more deliberate implementation and commit history. They are not permanent repository policy.

## Porting groups and order

Use the following order as the starting plan, with one focused commit per group. Bring relevant binding tests alongside each group's implementation. Review the draft's final design without replaying intermediate implementations that were later replaced. Deliberate revisions may change dependencies or require adjusting later groups. Shared files may be extended across groups.

| Order | Group | Description |
| --- | --- | --- |
| 1 | Property setter fix | Correct the reflected setter's value type and cover writable and read-only property bindings. |
| 2 | Userdata safety | Register metatable identity internally and validate userdata families before extracting wrappers. |
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
- When a Lua lookup returns the pushed value's `LuaType` (for example, `RawGet`, `RawGetByHashCode`, or `GetGlobal`), use that return value for subsequent type checks instead of querying the same value again through `Type` or `Is*`. Forward the returned type through lookup helpers when callers need it. Reuse it only while it still describes the value being checked. Match the types the allocation path actually produces rather than mechanically preserving a broader `Is*` predicate: LuaTinker wrappers always use full userdata, so check `.UserData` without also accepting `.LightUserData`.
- Use public methods for public API access and `using internal` for access to internal methods. Do not use `[Friend]` to bypass ordinary method visibility. Reserve `[Friend]` for tests or specific extraordinary cases where accessing another class's non-public field or member is preferable and less intrusive than relaxing its visibility; explain why such an exception is justified.
- Add cleanup scopes before raising Lua errors only when actual caller-scoped resources must be disposed first. Interpolated arguments passed to the formatting overload of `SetLastError` do not themselves allocate a caller-scoped string; do not wrap such calls in an extra block merely because they use interpolation. Preserve scopes needed for explicitly scoped temporaries, including those created inside interpolated expressions.
- For all tests brought over or changed during this work, focus assertions on LuaTinker's bindings and observable interop behavior. Remove assertions whose only purpose is to validate a bound dependency's implementation or invariants.
  - Keep suitable existing dependency types as binding targets. Removing dependency-behavior assertions does not imply replacing the target with a custom fixture. Review assertions individually and make the smallest relevant change.
  - Preserve meaningful negative binding coverage, including rejected writes to read-only properties. Do not remove such coverage merely because the property belongs to a dependency.
- In the user-facing reply, report changes from the draft baseline, including implementation differences and assertions or scenarios added, removed, or changed, with reasons. Identify a different baseline explicitly if one is used. Distinguish test-scope changes from intentional changes to the binding contract, and report validation results and execution blockers separately.
- Keep this file focused on this rebuild. Briefly record noteworthy departures from `playground_draft` when they affect behavior, ownership, type identity, or assumptions that later porting groups must preserve. Include the reason, implementation status, and consequences for later work. Omit routine review history and minor edits such as inlining, comment cleanup, formatting, or error-message wording.

## Threat model

The threat model is normal Lua/Beef use, including ordinary mistakes and invalid arguments—not deliberate corruption of internal state or adversarial attempts to subvert runtime invariants. Do not add hardening, defensive branches, or extra abstractions solely for intentionally corrupted inputs; implement only the checks needed for normal behavior.

## Noteworthy design changes

### Group 2: Registry-backed metatable validation

Status: implemented in the current rebuild. This replaces the draft's allocation-header ownership and kind tagging, and its reliance on public class globals for internal type identity, with a shared metatable-based validation model. Metatables now establish ownership and type identity together, avoiding parallel allocation tags and mutable global lookups.

- Store registered class metatables in the Lua registry under private per-type keys. Constructors, methods, properties, inheritance, and conversions must retrieve them internally. Public class names remain Lua-facing access points; rebinding a global must not change internal class identity.
- Recognize LuaTinker metatables through private userdata-kind markers before reading any userdata header or payload. Reduce the header to the information needed to locate the payload.
- Relative to the public API before group 2, remove `User2Type.GetTypeDirect`, `GetTypePtr`, `UnsafeGetTypePtr`, and `UnsafeGetObject`. The draft already replaces the first three with family-specific `TryGetTypePtr` overloads; this rebuild also consolidates `UnsafeGetObject` into `GetObject` so extraction consistently validates ownership. These removals have no compatibility shims; downstream callers must migrate.
- Compare actual metatables with the registry metatable for the expected Beef type, following the existing `__parent` relationship for inheritance. Preserve borrowed and unregistered values. Reject userdata without a recognized pointer metatable before interpreting its payload.
  - Unlike the draft, indexer lookup also follows `__parent`. Indexer access uses the normal class conversion rather than requiring an exact generic wrapper type, so derived instances can use base indexers. Preserve this behavior in later indexer changes.
- Keep class registration unique: registering a different Beef type under an already registered Lua class name must not replace or reuse the existing binding. Repeated registration of a type is also rejected; extend its existing registered metatable through the binding APIs.
- Remove public `LuaTinkerState.SetClassName<T>` in favor of internal `TryRegisterClass<T>`, since registration must establish registry identity rather than just record a name. Downstream callers must use `LuaTinker.AddClass<T>`; no compatibility shim is provided. Later groups must not restore name-only registration.
- Rename `EVMTResult.OkNoMetaTable` to `OkUnregisteredType`: accepted userdata has a metatable, while the expected Beef type may be unregistered. Downstream callers must use the new enum member; no compatibility alias is provided.
- Make `CheckMetaTableValidity<T>` strictly validate LuaTinker pointer userdata, matching `EnsureValidMetaTable<T>`. It is not a general value-conversion predicate. Generic `GetValue<T>` uses a separate preliminary filter so ordinary Lua values still reach their translators. Preserve this distinction in later conversion work.
- Adapt later porting groups to this model rather than restoring draft allocation tags or global-based identity. Cover valid instances, inheritance, borrowed and unregistered values, independence from public globals, and ordinary invalid or foreign userdata. Follow the threat model above; exclude deliberate metatable or upvalue corruption.
