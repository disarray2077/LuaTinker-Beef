import { createOutput } from "./output.js";

export function createRuntime() {
  const output = createOutput();
  let snapshot = {
    phase: "loading",
    status: "Loading…",
    failed: false,
    activeEntry: null,
  };
  let module;
  let host;
  let initialization;
  let generation = 0;
  let aborted = false;
  const listeners = new Set();
  const subscribe = (listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  };
  const getSnapshot = () => snapshot;
  function update(changes) {
    snapshot = { ...snapshot, ...changes };
    for (const listener of listeners) listener();
  }
  function setStatus(status, failed = false) {
    update({ status, failed });
  }
  function log(message, failed = false) {
    output.append(String(message), failed);
    if (failed && !snapshot.failed) setStatus("Failed", true);
  }
  function runUrl(entry) {
    const url = new URL(location.href);
    if (entry) url.searchParams.set("run", entry);
    else url.searchParams.delete("run");
    history.replaceState(null, "", url.href);
  }
  function replaceCanvas() {
    // Each run needs a fresh canvas: SDL's 2D and WebGL contexts cannot share one.
    const canvas = document.createElement("canvas");
    canvas.id = "canvas";
    canvas.width = 640;
    canvas.height = 480;
    canvas.tabIndex = 0;
    canvas.onpointerdown = () => canvas.focus({ preventScroll: true });
    canvas.onblur = () => {
      if (!aborted && ["starting", "running"].includes(snapshot.phase))
        module.ccall("PlaygroundReleaseKeys", null, [], []);
    };
    canvas.oncontextmenu = (event) => event.preventDefault();
    host.replaceChildren(canvas);
    if (module) module.canvas = canvas;
    return canvas;
  }
  function initialize(previewHost) {
    if (initialization) return initialization;
    host = previewHost;
    initialization = new Promise((resolve, reject) => {
      const version = document.querySelector(
        'meta[name="playground-build"]',
      ).content;
      module = window.Module = {
        canvas: replaceCanvas(),
        locateFile: (path, prefix) => `${prefix}${path}?v=${version}`,
        print: (...parts) => {
          console.log(...parts);
          log(parts.join(" "));
        },
        printErr: (...parts) => {
          console.error(...parts);
          log(parts.join(" "), true);
        },
        onAbort: (reason) => {
          aborted = true;
          generation++;
          update({ phase: "failed" });
          log("WASM aborted: " + reason, true);
          output.flush();
          reject(new Error(String(reason)));
        },
        onRuntimeInitialized: () => {
          module.callMain([]);
          update({ phase: "idle", status: "Ready" });
          resolve();
        },
        onPlaygroundStopped: () => {
          output.flush();
          runUrl(null);
          update({
            phase: "idle",
            ...(snapshot.failed ? {} : { status: "Finished" }),
          });
        },
      };
      const script = document.createElement("script");
      script.src = `./LuaTinkerPlayground.js?v=${version}`;
      script.onerror = () => {
        aborted = true;
        update({ phase: "failed" });
        reject(new Error("Cannot load the Playground runtime."));
      };
      document.body.append(script);
    });
    return initialization;
  }
  function templateRecords() {
    const records = [];
    const fs = module.FS;
    function collect(directory, prefix) {
      for (const name of fs.readdir(directory)) {
        if (name === "." || name === "..") continue;
        const path = directory + "/" + name;
        if (fs.isDir(fs.stat(path).mode)) collect(path, prefix + name + "/");
        else
          records.push({
            path: prefix + name,
            bytes: fs.readFile(path).slice().buffer,
          });
      }
    }
    collect("/templates", "");
    return records;
  }
  function syncWorkspace(files) {
    const fs = module.FS;
    fs.chdir("/");
    function remove(directory) {
      for (const name of fs.readdir(directory)) {
        if (name === "." || name === "..") continue;
        const path = directory + "/" + name;
        if (fs.isDir(fs.stat(path).mode)) {
          remove(path);
          fs.rmdir(path);
        } else fs.unlink(path);
      }
    }
    fs.mkdirTree("/workspace");
    remove("/workspace");
    for (const [path, record] of files) {
      const destination = "/workspace/" + path;
      if (record.folder) fs.mkdirTree(destination);
      else {
        fs.mkdirTree(destination.slice(0, destination.lastIndexOf("/")));
        fs.writeFile(destination, new Uint8Array(record.bytes));
      }
    }
  }
  function stop() {
    generation++;
    if (module && snapshot.phase !== "loading" && !aborted)
      module.ccall("PlaygroundStop", null, [], []);
    runUrl(null);
    output.flush();
    update({
      phase: aborted ? "failed" : "idle",
      status: "Stopped",
      failed: aborted,
    });
  }
  async function run(prepare, beforeStart = () => {}) {
    if (
      snapshot.phase === "loading" ||
      snapshot.phase === "starting" ||
      aborted
    )
      return;
    const current = ++generation;
    update({ phase: "starting" });
    try {
      const { entry, files } = await prepare();
      if (current !== generation) return;
      module.ccall("PlaygroundStop", null, [], []);
      beforeStart();
      output.clear();
      update({
        phase: "starting",
        activeEntry: entry,
        status: "Running",
        failed: false,
      });
      syncWorkspace(files);
      const canvas = replaceCanvas();
      if (
        module.ccall(
          "PlaygroundStart",
          "number",
          ["string"],
          ["/workspace/" + entry],
        ) === 0
      ) {
        // A script can finish synchronously and call onPlaygroundStopped during Start.
        if (snapshot.phase === "starting") {
          update({ phase: "running" });
          runUrl(entry);
        }
        canvas.focus({ preventScroll: true });
      }
    } catch (error) {
      if (current !== generation) return;
      if (!aborted) module.ccall("PlaygroundStop", null, [], []);
      log(error.stack || error, true);
    } finally {
      if (current === generation && snapshot.phase === "starting")
        update({ phase: "idle" });
    }
  }
  return {
    output,
    subscribe,
    getSnapshot,
    initialize,
    templateRecords,
    setStatus,
    log,
    run,
    stop,
    readTemplate: (path) =>
      module.FS.readFile("/templates/" + path).slice().buffer,
  };
}
