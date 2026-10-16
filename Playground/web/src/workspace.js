import {
  names,
  isFolder,
  textOf,
  comparePaths,
  hasTopLevelReturn,
  validPath,
  parentPaths,
  normalizeSourcePath,
} from "./files.js";
import {
  tx as transact,
  getAll as readAll,
  openDb,
  setMeta,
} from "./storage.js";

export function createWorkspace(runtime) {
  const state = {
    initialized: false,
    files: new Map(),
    collapsed: new Set(),
    focused: null,
    selected: null,
    entry: null,
    pane: "editor",
    writable: false,
    dirty: false,
    revision: 0,
    editorRevision: 0,
    draft: "",
    saveStatus: "",
    saveFailed: false,
    dialog: null,
    location: null,
  };
  let db = null;
  let assets = [];
  let histories = new Map();
  let timer = null;
  let saves = Promise.resolve();
  let snapshot;
  let fileSnapshot = new Map();
  let entries = [];
  const listeners = new Set();
  const tx = (stores, mode, work) => transact(db, stores, mode, work);
  const getAll = (store) => readAll(db, store);
  const ordered = () => [...state.files.keys()].sort(comparePaths);

  function publish(filesChanged = false) {
    if (filesChanged) {
      fileSnapshot = new Map(state.files);
      entries = ordered().filter(isEntryFile);
    }
    if (state.entry && !entries.includes(state.entry)) state.entry = null;
    const history = histories.get(state.selected);
    snapshot = {
      ...state,
      files: fileSnapshot,
      collapsed: new Set(state.collapsed),
      assets: [...names, ...assets],
      entries,
      canUndo: !!history && history.position > 0,
      canRedo:
        !!history &&
        history.position <
          history.runs.length - (history.draft === null ? 1 : 0),
    };
    for (const listener of listeners) listener();
  }
  const subscribe = (listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  };
  const getSnapshot = () => snapshot;
  function isEntryFile(path) {
    if (!path || !path.toLowerCase().endsWith(".lua")) return false;
    const source = textOf(state.files.get(path));
    return source !== null && !hasTopLevelReturn(source);
  }
  function folderPaths() {
    const folders = new Set();
    for (const [path, record] of state.files) {
      if (isFolder(record)) folders.add(path);
      for (const parent of parentPaths(path)) folders.add(parent);
    }
    return folders;
  }
  function pathIssue(path, folders = folderPaths(), ignored = new Set()) {
    const invalid = validPath(path);
    if (invalid) return invalid;
    if (!ignored.has(path) && (state.files.has(path) || folders.has(path)))
      return "A file or folder already exists at that path.";
    if (
      parentPaths(path).some(
        (parent) =>
          !ignored.has(parent) &&
          state.files.has(parent) &&
          !isFolder(state.files.get(parent)),
      )
    )
      return "A parent path is a file.";
    return null;
  }
  function missingFolders(paths) {
    const additions = new Map();
    for (const path of paths) {
      for (const parent of parentPaths(path)) {
        if (!state.files.has(parent))
          additions.set(parent, { path: parent, folder: true });
      }
    }
    return [...additions.values()];
  }
  function restoreHistories() {
    for (const [path, history] of histories) {
      const record = state.files.get(path);
      const text = record && textOf(record);
      if (text === null || text === undefined || !history.runs.length) {
        histories.delete(path);
        continue;
      }
      if (
        text !==
        (history.position === history.runs.length
          ? history.draft
          : history.runs[history.position])
      ) {
        history.runs.splice(history.position + 1);
        history.draft = text;
        history.position = history.runs.length;
      }
    }
  }

  function noteEdit() {
    const history = histories.get(state.selected);
    if (!history) return;
    if (history.position < history.runs.length)
      history.runs.splice(history.position + 1);
    const previous = history.runs.at(-1);
    history.draft = state.draft === previous ? null : state.draft;
    history.position =
      history.draft === null ? history.runs.length - 1 : history.runs.length;
  }
  function edit(value, restoring = false) {
    if (!state.writable || !state.selected) return;
    state.draft = value;
    if (!restoring) noteEdit();
    state.revision++;
    state.dirty = true;
    state.saveStatus = "Saving…";
    state.saveFailed = false;
    clearTimeout(timer);
    timer = setTimeout(() => perform(flush), 300);
    publish();
  }
  function moveSnapshot(direction) {
    const history = histories.get(state.selected);
    if (!state.writable || !history) return;
    const target = history.position + direction;
    const last = history.runs.length - 1 + (history.draft === null ? 0 : 1);
    if (target < 0 || target > last) return;
    history.position = target;
    state.editorRevision++;
    edit(
      target === history.runs.length ? history.draft : history.runs[target],
      true,
    );
  }
  function snapshotRun() {
    const next = new Map(
      [...histories].map(([path, history]) => [
        path,
        {
          runs: [...history.runs],
          position: history.position,
          draft: history.draft,
        },
      ]),
    );
    for (const [path, record] of state.files) {
      const text = textOf(record);
      if (text === null) continue;
      const history = next.get(path) || { runs: [], position: -1, draft: null };
      history.runs.splice(history.position + 1);
      if (history.runs.at(-1) !== text) history.runs.push(text);
      history.position = history.runs.length - 1;
      history.draft = null;
      next.set(path, history);
    }
    histories = next;
    publish();
  }

  const templateRecords = () => {
    const records = runtime.templateRecords();
    assets = records
      .map(({ path }) => path)
      .filter((path) => !names.includes(path));
    return records;
  };
  async function load() {
    const seeds = templateRecords();
    db = await openDb();
    const meta = await getAll("meta");
    const values = Object.fromEntries(
      meta.map(({ key, value }) => [key, value]),
    );
    const existing = new Map(
      (await getAll("files")).map((record) => [record.path, record]),
    );
    // Earlier workspaces did not record which templates had already been offered.
    const packagedFiles = new Set(
      values.packagedFiles ||
        (values.initialized
          ? [
              "sdl_render.lua",
              "gl_render.lua",
              "modules/opengl.lua",
              "modules/decoded_image.lua",
            ]
          : []),
    );
    await tx(["files", "meta"], "readwrite", (transaction) => {
      const files = transaction.objectStore("files");
      for (const record of seeds) {
        if (packagedFiles.has(record.path) || existing.has(record.path))
          continue;
        if (
          parentPaths(record.path).some(
            (parent) => existing.has(parent) && !isFolder(existing.get(parent)),
          )
        )
          continue;
        files.add(record);
      }
      const store = transaction.objectStore("meta");
      setMeta(
        store,
        "packagedFiles",
        seeds.map(({ path }) => path),
      );
      if (!values.initialized) {
        setMeta(store, "initialized", true);
        setMeta(store, "entry", names[0]);
        setMeta(store, "selected", names[0]);
        setMeta(store, "activePane", "editor");
      }
    });
    state.writable = true;
    await refresh();
  }
  async function refresh() {
    const [records, meta] = await Promise.all([
      getAll("files"),
      getAll("meta"),
    ]);
    state.files = new Map(records.map((record) => [record.path, record]));
    state.collapsed = folderPaths();
    restoreHistories();
    const values = Object.fromEntries(
      meta.map(({ key, value }) => [key, value]),
    );
    state.entry = values.entry || null;
    state.focused = values.selected || null;
    const selectedRecord = state.files.get(state.focused);
    state.selected =
      selectedRecord && !isFolder(selectedRecord)
        ? state.focused
        : state.files.has(state.entry) &&
            !isFolder(state.files.get(state.entry))
          ? state.entry
          : ordered().find((path) => !isFolder(state.files.get(path))) || null;
    state.pane = values.activePane || "editor";
    if (!["files", "editor", "preview"].includes(state.pane))
      state.pane = "editor";
    reloadEditor();
  }

  function reloadEditor() {
    state.draft = textOf(state.files.get(state.selected)) ?? "";
    state.editorRevision++;
    state.saveStatus =
      textOf(state.files.get(state.selected)) === null ? "" : "Saved";
    state.saveFailed = false;
    publish(true);
  }
  function selectPane(pane) {
    state.pane = pane;
    publish();
    if (db)
      perform(() =>
        tx("meta", "readwrite", (t) =>
          setMeta(t.objectStore("meta"), "activePane", pane),
        ),
      );
  }
  async function selectFile(path, { toggleFolder = true } = {}) {
    await flush();
    state.focused = path;
    if (path === "" || folderPaths().has(path)) {
      if (path === "") {
        publish();
        return;
      }
      if (toggleFolder) {
        if (state.collapsed.has(path)) state.collapsed.delete(path);
        else state.collapsed.add(path);
      }
      publish();
      return;
    }
    state.selected = path;
    if (db)
      await tx("meta", "readwrite", (t) =>
        setMeta(t.objectStore("meta"), "selected", path),
      );
    reloadEditor();
    selectPane("editor");
  }
  async function openSourceLocation(path, row) {
    if (textOf(state.files.get(path)) === null) return;
    await selectFile(path);
    for (const parent of parentPaths(path)) state.collapsed.delete(parent);
    state.location = { path, row };
    selectPane("editor");
  }
  function perform(operation) {
    return Promise.resolve()
      .then(operation)
      .catch((error) => {
        state.saveStatus = "Save failed: " + error.message;
        state.saveFailed = true;
        runtime.setStatus(state.saveStatus, true);
        publish();
      });
  }
  function queueSave() {
    clearTimeout(timer);
    timer = null;
    if (!state.dirty) return saves;
    const path = state.selected;
    const value = state.draft;
    const revision = state.revision;
    state.dirty = false;
    saves = saves
      .catch(() => {})
      .then(async () => {
        const record = { path, bytes: new TextEncoder().encode(value).buffer };
        await tx("files", "readwrite", (t) =>
          t.objectStore("files").put(record),
        );
        state.files.set(path, record);
        if (revision === state.revision) {
          state.saveStatus = "Saved";
          state.saveFailed = false;
        }
        publish(true);
      })
      .catch((error) => {
        state.dirty = true;
        state.saveStatus = "Save failed: " + error.message;
        state.saveFailed = true;
        publish();
        throw error;
      });
    return saves;
  }
  async function flush() {
    await queueSave();
  }
  function dialog(options) {
    return new Promise((resolve) => {
      state.dialog = {
        ...options,
        finish: (result) => {
          state.dialog = null;
          publish();
          resolve(result);
        },
      };
      publish();
    });
  }
  async function createItem(folder) {
    await flush();
    const prefix = folderPaths().has(state.focused) ? state.focused + "/" : "";
    const path = await dialog({
      title: folder ? "New folder" : "New file",
      path: prefix,
      confirm: "Create",
      validate: (value) => pathIssue(value),
    });
    if (path === null) return;
    const parents = missingFolders([path]);
    const record = folder
      ? { path, folder: true }
      : { path, bytes: new ArrayBuffer(0) };
    await tx(["files", "meta"], "readwrite", (t) => {
      const files = t.objectStore("files");
      for (const parent of parents) files.add(parent);
      files.add(record);
      if (!folder) setMeta(t.objectStore("meta"), "selected", path);
    });
    for (const parent of parents) {
      state.files.set(parent.path, parent);
      state.collapsed.add(parent.path);
    }
    state.files.set(path, record);
    state.focused = path;
    if (folder) state.collapsed.add(path);
    else state.collapsed.delete(path);
    for (const parent of parentPaths(path)) state.collapsed.delete(parent);
    if (!folder) state.selected = path;
    reloadEditor();
    if (!folder) {
      selectPane("editor");
      state.location = { path, row: 1 };
      publish();
    }
  }
  async function renameFile(old = state.focused) {
    await flush();
    if (!old) return;
    const folder = folderPaths().has(old);
    const folders = folderPaths();
    const moved = [...state.files.values()].filter(
      (record) =>
        record.path === old || (folder && record.path.startsWith(old + "/")),
    );
    const sources = new Set(moved.map((record) => record.path));
    const path = await dialog({
      title: folder ? "Rename folder" : "Rename file",
      path: old,
      confirm: "Rename",
      validate: (value) => {
        if (value === old) return null;
        if (value.startsWith(old + "/"))
          return "An item cannot move inside itself.";
        const renamed = moved.map((record) => ({
          ...record,
          path: value + record.path.slice(old.length),
        }));
        if (folder && !state.files.has(old))
          renamed.unshift({ path: value, folder: true });
        for (const record of renamed) {
          const issue = pathIssue(record.path, folders, sources);
          if (issue) return issue;
        }
        return null;
      },
    });
    if (path === null || path === old) return;
    const renamed = moved.map((record) => ({
      ...record,
      path: path + record.path.slice(old.length),
    }));
    if (folder && !state.files.has(old))
      renamed.unshift({ path, folder: true });
    const parents = missingFolders([path]);
    const entry =
      state.entry &&
      (state.entry === old || (folder && state.entry.startsWith(old + "/")))
        ? path + state.entry.slice(old.length)
        : state.entry;
    const selected =
      state.selected &&
      (state.selected === old ||
        (folder && state.selected.startsWith(old + "/")))
        ? path + state.selected.slice(old.length)
        : state.selected;
    await tx(["files", "meta"], "readwrite", (t) => {
      const files = t.objectStore("files");
      for (const record of moved) files.delete(record.path);
      for (const parent of parents) files.put(parent);
      for (const record of renamed) files.add(record);
      const meta = t.objectStore("meta");
      setMeta(meta, "selected", selected);
      if (entry !== state.entry) setMeta(meta, "entry", entry);
    });
    for (const record of moved) {
      state.files.delete(record.path);
      if (histories.has(record.path)) {
        histories.set(
          path + record.path.slice(old.length),
          histories.get(record.path),
        );
        histories.delete(record.path);
      }
    }
    for (const parent of parents) state.files.set(parent.path, parent);
    for (const record of renamed) state.files.set(record.path, record);
    state.focused = path;
    state.selected = selected;
    state.collapsed = new Set(
      [...state.collapsed].map((folderPath) =>
        folderPath === old || folderPath.startsWith(old + "/")
          ? path + folderPath.slice(old.length)
          : folderPath,
      ),
    );
    for (const parent of parentPaths(path)) state.collapsed.delete(parent);
    state.entry = entry;
    reloadEditor();
  }
  async function deleteFile(path = state.focused) {
    await flush();
    if (!path) return;
    const folder = folderPaths().has(path);
    const removed = [...state.files.keys()].filter(
      (name) => name === path || (folder && name.startsWith(path + "/")),
    );
    const message = folder
      ? `Delete folder ${path} and its ${removed.length - Number(state.files.has(path))} nested items? This cannot be undone.`
      : `Delete ${path}? This cannot be undone.`;
    if (
      (await dialog({
        title: folder ? "Delete folder" : "Delete file",
        message,
        confirm: "Delete",
      })) === null
    )
      return;
    const removedSet = new Set(removed);
    const paths = ordered();
    const remaining = paths.filter((name) => !removedSet.has(name));
    const next =
      remaining[
        Math.min(Math.max(paths.indexOf(path), 0), remaining.length - 1)
      ] || null;
    const remainingFiles = remaining.filter(
      (name) => !isFolder(state.files.get(name)),
    );
    const selected = removedSet.has(state.selected)
      ? remainingFiles[
          Math.min(
            Math.max(paths.indexOf(state.selected), 0),
            remainingFiles.length - 1,
          )
        ] || null
      : state.selected;
    const entry = removedSet.has(state.entry)
      ? remainingFiles.find((name) => name.toLowerCase().endsWith(".lua")) ||
        null
      : state.entry;
    await tx(["files", "meta"], "readwrite", (t) => {
      for (const name of removed) t.objectStore("files").delete(name);
      setMeta(t.objectStore("meta"), "selected", selected);
      setMeta(t.objectStore("meta"), "entry", entry);
    });
    for (const name of removed) {
      state.files.delete(name);
      histories.delete(name);
    }
    state.focused = next;
    state.selected = selected;
    for (const folderPath of [...state.collapsed]) {
      if (folderPath === path || folderPath.startsWith(path + "/"))
        state.collapsed.delete(folderPath);
    }
    state.entry = entry;
    reloadEditor();
  }
  async function uploadFiles(files, folderUpload = false) {
    await flush();

    if (!files.length) return;
    const prefix = folderPaths().has(state.focused) ? state.focused + "/" : "";
    const folders = folderPaths();
    const incoming = new Set();
    const records = [];
    for (const file of files) {
      if (folderUpload && !file.webkitRelativePath) {
        runtime.setStatus("This browser did not provide folder paths.", true);
        return;
      }
      const path =
        prefix +
        (folderUpload ? file.webkitRelativePath : file.name).replaceAll(
          "\\",
          "/",
        );
      if (validPath(path) || folders.has(path) || incoming.has(path)) {
        runtime.setStatus("Invalid or duplicate upload path: " + path, true);
        return;
      }
      incoming.add(path);
      records.push({ path, bytes: await file.arrayBuffer() });
    }
    for (const { path } of records) {
      if (
        parentPaths(path).some(
          (parent) =>
            incoming.has(parent) ||
            (state.files.has(parent) && !isFolder(state.files.get(parent))),
        )
      ) {
        runtime.setStatus("Cannot upload into a file: " + path, true);
        return;
      }
    }
    const collisions = records.filter(({ path }) => state.files.has(path));
    if (
      collisions.length &&
      (await dialog({
        title: "Replace files?",
        message: `Replace ${collisions.map(({ path }) => path).join(", ")}? All selected files will be imported.`,
        confirm: "Replace",
      })) === null
    )
      return;
    const parents = missingFolders(records.map((record) => record.path));
    await tx(["files", "meta"], "readwrite", (t) => {
      const store = t.objectStore("files");
      for (const parent of parents) store.add(parent);
      for (const record of records) store.put(record);
      setMeta(t.objectStore("meta"), "selected", records[0].path);
    });
    for (const parent of parents) {
      state.files.set(parent.path, parent);
      state.collapsed.add(parent.path);
    }
    for (const record of records) {
      state.files.set(record.path, record);
      histories.delete(record.path);
    }
    state.focused = state.selected = records[0].path;
    for (const parent of parentPaths(state.selected))
      state.collapsed.delete(parent);
    reloadEditor();
    selectPane("editor");
  }
  async function resetPackagedFile(path) {
    await flush();
    if (
      (await dialog({
        title: "Reset file?",
        message: `Replace ${path} with its bundled version? This cannot be undone.`,
        confirm: "Reset file",
      })) === null
    )
      return;
    const record = { path, bytes: runtime.readTemplate(path) };
    await tx("files", "readwrite", (t) => t.objectStore("files").put(record));
    state.files.set(path, record);
    histories.delete(path);
    if (state.selected === path) reloadEditor();
    else publish(true);
    runtime.setStatus("Restored " + path);
  }
  async function downloadFile(path = state.focused) {
    await flush();
    const record = state.files.get(path);
    if (!record || isFolder(record)) return;
    const url = URL.createObjectURL(
      new Blob([record.bytes], { type: "application/octet-stream" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = path.slice(path.lastIndexOf("/") + 1);
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function resetExamples() {
    await flush();
    if (
      (await dialog({
        title: "Reset examples?",
        message: `Replace the entire workspace with the ${names.length} packaged Lua examples? This cannot be undone.`,
        confirm: "Reset examples",
      })) === null
    )
      return;
    const seeds = templateRecords();
    await tx(["files", "meta"], "readwrite", (t) => {
      const files = t.objectStore("files");
      files.clear();
      for (const record of seeds) files.add(record);
      const meta = t.objectStore("meta");
      setMeta(meta, "entry", names[0]);
      setMeta(meta, "selected", names[0]);
      setMeta(meta, "activePane", "editor");
      setMeta(
        meta,
        "packagedFiles",
        seeds.map(({ path }) => path),
      );
    });
    state.files = new Map(seeds.map((record) => [record.path, record]));
    histories.clear();
    state.focused = state.entry = state.selected = names[0];
    state.collapsed = folderPaths();
    reloadEditor();
    selectPane("editor");
  }

  async function selectEntry(entry, { persist = true } = {}) {
    await flush();
    if (entry !== null && !isEntryFile(entry)) return;
    state.entry = entry;
    if (db && persist)
      await tx("meta", "readwrite", (t) =>
        setMeta(t.objectStore("meta"), "entry", entry),
      );
    publish();
  }
  async function initialize() {
    try {
      await load();
    } catch (error) {
      console.error(error);
      db?.close();
      db = null;
      state.files = new Map(
        templateRecords().map((record) => [record.path, record]),
      );
      state.collapsed = folderPaths();
      state.focused = state.selected = state.entry = names[0];
      state.writable = false;
      reloadEditor();
      runtime.log(
        "Persistent storage is unavailable; bundled examples are read-only.",
        true,
      );
    }
    state.initialized = true;
    publish();
  }
  function run() {
    return runtime.run(
      async () => {
        await flush();
        if (!isEntryFile(state.entry))
          throw new Error("Select a Lua entry file before running.");
        return { entry: state.entry, files: new Map(state.files) };
      },
      () => {
        snapshotRun();
        selectPane("preview");
      },
    );
  }
  function resolveSourcePath(reference) {
    const absolute = reference.startsWith("/workspace/");
    if (reference.startsWith("/") && !absolute) return null;
    const relative = absolute
      ? reference.slice("/workspace/".length)
      : reference;
    const root = normalizeSourcePath(relative);
    if (root && textOf(state.files.get(root)) !== null) return root;
    if (absolute) return null;
    const entry = runtime.getSnapshot().activeEntry || state.entry;
    if (entry?.includes("/")) {
      const besideEntry = normalizeSourcePath(
        entry.slice(0, entry.lastIndexOf("/") + 1) + relative,
      );
      if (besideEntry && textOf(state.files.get(besideEntry)) !== null)
        return besideEntry;
    }
    if (!root) return null;
    let unique = null;
    for (const path of state.files.keys()) {
      if (path.endsWith("/" + root) && textOf(state.files.get(path)) !== null) {
        if (unique) return null;
        unique = path;
      }
    }
    return unique;
  }

  publish();
  return {
    subscribe,
    getSnapshot,
    initialize,
    isEntryFile,
    selectFile,
    selectEntry,
    selectPane,
    openSourceLocation,
    resolveSourcePath,
    edit,
    flush,
    moveSnapshot,
    createItem,
    renameFile,
    deleteFile,
    uploadFiles,
    resetPackagedFile,
    downloadFile,
    resetExamples,
    perform,
    run,
  };
}
