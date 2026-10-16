import { useMemo, useRef } from "react";
import { comparePaths, isFolder, parentPaths } from "../files.js";

export function FileTree({ workspace, state }) {
  const upload = useRef(null);
  const uploadFolder = useRef(null);
  const { folders, children, apps, entries } = useMemo(() => {
    const entries = new Set(state.entries);
    const apps = new Map();
    for (const entry of entries)
      if (entry.endsWith("/main.lua"))
        apps.set(entry.slice(0, -"/main.lua".length), entry);
    const folders = new Set();
    for (const [path, record] of state.files) {
      if (isFolder(record)) folders.add(path);
      for (const parent of parentPaths(path)) folders.add(parent);
    }
    const children = new Map();
    for (const path of new Set([...state.files.keys(), ...folders])) {
      const parent = path.slice(0, Math.max(0, path.lastIndexOf("/")));
      if (!children.has(parent)) children.set(parent, []);
      children.get(parent).push(path);
    }
    for (const paths of children.values())
      paths.sort(
        (a, b) =>
          Number(apps.has(b)) - Number(apps.has(a)) ||
          Number(folders.has(b)) - Number(folders.has(a)) ||
          comparePaths(a, b),
      );
    return { folders, children, apps, entries };
  }, [state.files, state.entries]);
  const perform = workspace.perform;
  function branch(parent) {
    return (children.get(parent) || []).map((path) => {
      const folder = folders.has(path);
      const app = apps.has(path);
      const entry = app ? apps.get(path) : folder ? null : path;
      const collapsed = state.collapsed.has(path);
      const label =
        path.slice(parent ? parent.length + 1 : 0) + (folder ? "/" : "");
      const button = (
        <button
          type="button"
          data-folder={folder}
          data-app={app}
          data-entry={entry !== null && entry === state.entry}
          title={app ? `Double-click to select ${entry}` : undefined}
          aria-current={path === state.focused}
          aria-expanded={folder && !app ? !collapsed : undefined}
          onClick={() =>
            perform(() => workspace.selectFile(path, { toggleFolder: !app }))
          }
          onDoubleClick={
            entries.has(entry)
              ? () =>
                  perform(async () => {
                    if (app) await workspace.selectFile(entry);
                    await workspace.selectEntry(entry);
                  })
              : undefined
          }
        >
          {label}
        </button>
      );
      return (
        <li key={path}>
          {folder ? (
            <div className="folder-row">
              <button
                type="button"
                className="folder-toggle"
                aria-label={`${collapsed ? "Expand" : "Collapse"} ${path}`}
                aria-expanded={!collapsed}
                onClick={() => perform(() => workspace.selectFile(path))}
              >
                {collapsed ? "▸" : "▾"}
              </button>
              {button}
            </div>
          ) : !folder && state.assets.includes(path) ? (
            <div className="file-row">
              {button}
              <button
                type="button"
                className="reset-file"
                aria-label={`Reset ${path} to bundled version`}
                disabled={!state.writable}
                onClick={() => perform(() => workspace.resetPackagedFile(path))}
              >
                Reset
              </button>
            </div>
          ) : (
            button
          )}
          {folder && (
            <ul className="tree-children" hidden={collapsed}>
              {branch(path)}
            </ul>
          )}
        </li>
      );
    });
  }
  function importFiles(event, folder = false) {
    const files = [...event.target.files];
    event.target.value = "";
    perform(() => workspace.uploadFiles(files, folder));
  }
  return (
    <section
      id="files-panel"
      className={`pane ${state.pane === "files" ? "active" : ""}`}
      role="tabpanel"
      aria-label="Files"
    >
      <div className="pane-header">
        <h2>Files</h2>
      </div>
      <ul id="file-list">
        <li>
          <button
            type="button"
            data-folder="true"
            aria-current={state.focused === ""}
            onClick={() => perform(() => workspace.selectFile(""))}
          >
            Workspace /
          </button>
          <ul className="tree-children">{branch("")}</ul>
        </li>
      </ul>
      <div className="file-tools">
        <button
          type="button"
          disabled={!state.writable}
          onClick={() => perform(() => workspace.createItem(false))}
        >
          New file
        </button>
        <button
          type="button"
          disabled={!state.writable}
          onClick={() => perform(() => workspace.createItem(true))}
        >
          New folder
        </button>
        <button
          type="button"
          disabled={!state.writable || !state.focused}
          onClick={() => perform(workspace.renameFile)}
        >
          Rename
        </button>
        <button
          type="button"
          className="danger"
          disabled={!state.writable || !state.focused}
          onClick={() => perform(workspace.deleteFile)}
        >
          Delete
        </button>
        <button
          type="button"
          disabled={!state.writable}
          onClick={() => upload.current.click()}
        >
          Upload files
        </button>
        <button
          type="button"
          disabled={!state.writable}
          onClick={() => uploadFolder.current.click()}
        >
          Upload folder
        </button>
        <button
          type="button"
          aria-label="Download selected file"
          disabled={
            !state.files.has(state.focused) ||
            isFolder(state.files.get(state.focused))
          }
          onClick={() => perform(workspace.downloadFile)}
        >
          Download
        </button>
        <button
          type="button"
          disabled={!state.writable}
          onClick={() => perform(workspace.resetExamples)}
        >
          Reset examples
        </button>
        <input
          ref={upload}
          id="upload-files"
          type="file"
          multiple
          aria-label="Upload files"
          onChange={importFiles}
        />
        <input
          ref={uploadFolder}
          id="upload-folder-files"
          type="file"
          webkitdirectory=""
          multiple
          aria-label="Upload folder"
          onChange={(event) => importFiles(event, true)}
        />
      </div>
    </section>
  );
}
