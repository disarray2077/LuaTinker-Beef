import { useCallback, useMemo, useRef, useState } from "react";
import { comparePaths, isFolder, parentPaths } from "../files.js";
import { ActionMenu } from "./ActionMenu.jsx";

export function FileTree({ workspace, state }) {
  const upload = useRef(null);
  const uploadFolder = useRef(null);
  const menuTrigger = useRef(null);
  const [menu, setMenu] = useState(null);
  const closeMenu = useCallback((restoreFocus = true) => {
    setMenu(null);
    if (restoreFocus) menuTrigger.current?.focus();
  }, []);
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
  function openMenu(event, kind, path = null) {
    const context = event.type === "contextmenu";
    event.preventDefault();
    if (!context && menu?.kind === kind && menu.path === path) {
      closeMenu();
      return;
    }
    const target = event.currentTarget;
    const rect = target.getBoundingClientRect();
    const trigger = target.querySelector(".tree-label") || target;
    menuTrigger.current = trigger;
    setMenu({
      kind,
      path,
      anchor: {
        x: context ? event.clientX : rect.right,
        y: context ? event.clientY : rect.bottom,
        alignRight: !context,
        trigger,
      },
    });
  }

  let menuItems = [];
  if (menu?.kind === "create")
    menuItems = [
      {
        label: "New file",
        action: () => perform(() => workspace.createItem(false)),
      },
      {
        label: "New folder",
        action: () => perform(() => workspace.createItem(true)),
      },
      { label: "Upload files", action: () => upload.current.click() },
      { label: "Upload folder", action: () => uploadFolder.current.click() },
    ];
  else if (menu?.kind === "workspace")
    menuItems = [
      {
        label: "Reset examples",
        action: () => perform(workspace.resetExamples),
        disabled: !state.writable,
      },
    ];
  else if (menu?.kind === "file") {
    const path = menu.path;
    menuItems = [
      {
        label: "Rename",
        action: () => perform(() => workspace.renameFile(path)),
        disabled: !state.writable,
      },
      ...(!folders.has(path)
        ? [
            {
              label: "Download",
              action: () => perform(() => workspace.downloadFile(path)),
            },
          ]
        : []),
      ...(state.assets.includes(path)
        ? [
            {
              label: "Reset to bundled version",
              action: () => perform(() => workspace.resetPackagedFile(path)),
              disabled: !state.writable,
            },
          ]
        : []),
      {
        label: "Delete",
        action: () => perform(() => workspace.deleteFile(path)),
        disabled: !state.writable,
        danger: true,
      },
    ];
  }

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
          className="tree-label"
          data-folder={folder}
          data-app={app}
          data-entry={entry !== null && entry === state.entry}
          title={app ? `Double-click to select ${entry}` : undefined}
          aria-current={path === state.focused}
          aria-expanded={folder && !app ? !collapsed : undefined}
          onClick={() => {
            closeMenu(false);
            perform(() => workspace.selectFile(path, { toggleFolder: !app }));
          }}
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
          <div
            className={`tree-row${folder ? " folder-row" : ""}`}
            data-focused={
              path === state.focused ||
              (menu?.kind === "file" && menu.path === path)
            }
            onContextMenu={(event) => openMenu(event, "file", path)}
            onKeyDown={(event) => {
              if (
                event.key === "ContextMenu" ||
                (event.shiftKey && event.key === "F10")
              )
                openMenu(event, "file", path);
            }}
          >
            {folder && (
              <button
                type="button"
                className="folder-toggle"
                aria-label={`${collapsed ? "Expand" : "Collapse"} ${path}`}
                aria-expanded={!collapsed}
                onClick={() => perform(() => workspace.selectFile(path))}
              >
                {collapsed ? "▸" : "▾"}
              </button>
            )}
            {button}
            <button
              type="button"
              className="row-actions"
              aria-label={`Actions for ${path}`}
              aria-haspopup="menu"
              aria-expanded={menu?.kind === "file" && menu.path === path}
              onClick={(event) => openMenu(event, "file", path)}
            >
              ⋯
            </button>
          </div>
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
        <button
          type="button"
          className="icon-button"
          aria-label="New or upload files"
          title="New or upload files"
          aria-haspopup="menu"
          aria-expanded={menu?.kind === "create"}
          disabled={!state.writable}
          onClick={(event) => openMenu(event, "create")}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
            <path
              d="M12 5v14M5 12h14"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </svg>
        </button>
        <button
          type="button"
          className="icon-button"
          aria-label="Workspace actions"
          title="Workspace actions"
          aria-haspopup="menu"
          aria-expanded={menu?.kind === "workspace"}
          onClick={(event) => openMenu(event, "workspace")}
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="currentColor"
            aria-hidden="true"
          >
            <circle cx="5" cy="12" r="1.5" />
            <circle cx="12" cy="12" r="1.5" />
            <circle cx="19" cy="12" r="1.5" />
          </svg>
        </button>
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
      {menu && (
        <ActionMenu
          anchor={menu.anchor}
          label={
            menu.kind === "file"
              ? `Actions for ${menu.path}`
              : menu.kind === "create"
                ? "New or upload files"
                : "Workspace actions"
          }
          items={menuItems}
          onClose={closeMenu}
        />
      )}
    </section>
  );
}
