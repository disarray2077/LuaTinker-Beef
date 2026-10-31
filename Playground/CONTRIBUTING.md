# Updating bundled examples

When changing existing files under `Playground/dist`, stage the examples, then run
this command from the repository root before committing:

```sh
npm --prefix Playground/web run templates:update
```

Stage `Playground/web/src/template-update-hashes.json` with the examples. The
script records their previous versions from `HEAD` and does not stage files.

CI checks the entire pushed range. If a change was already committed, run the
update command with the base revision reported by CI:

```sh
npm --prefix Playground/web run templates:update -- --base <revision>
```

For a local read-only check of the latest commit:

```sh
npm --prefix Playground/web run templates:check
```
