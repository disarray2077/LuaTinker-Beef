# Playground web interface

The Playground React interface lives here. `src/workspace.js` owns file operations and run snapshots,
`src/storage.js` keeps the existing IndexedDB format, and `src/runtime.js` loads Emscripten
and owns the canvas and Lua sessions.

## Building

From the repository root, build the runtime and interface together:

```powershell
./scripts/build-wasm.ps1 -Emsdk F:/emsdk/emsdk -BeefBuild C:/Users/igo08/Downloads/Beef/IDE/dist/BeefBuild.exe
```

After that, frontend changes only need:

```powershell
npm --prefix Playground/web run build
```

`npm --prefix Playground/web run watch` rebuilds the interface as its source changes.
Serve `build/wasm/playground` over HTTP and open `LuaTinkerPlayground.html`.

## Useful commands

- Run `npm run lint` for ESLint and React Hooks checks, `npm run lint:fix` applies available
  lint fixes.
- Run `npm run format` to apply Prettier's formatting, and `npm run format:check` to
  check formatting without changing files.
- Run `npm test` for the Playground web interface tests.
