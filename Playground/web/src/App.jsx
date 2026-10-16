import { useEffect, useSyncExternalStore } from "react";
import { FileTree } from "./components/FileTree.jsx";
import { Editor } from "./components/Editor.jsx";
import { Preview } from "./components/Preview.jsx";
import { WorkspaceDialog } from "./components/WorkspaceDialog.jsx";
import { Workbench } from "./components/Workbench.jsx";

export function App({ runtime, workspace }) {
  const state = useSyncExternalStore(
    workspace.subscribe,
    workspace.getSnapshot,
  );
  const execution = useSyncExternalStore(
    runtime.subscribe,
    runtime.getSnapshot,
  );
  const ready =
    state.initialized &&
    execution.phase !== "loading" &&
    execution.phase !== "failed";
  useEffect(() => {
    const resize = () =>
      document.documentElement.style.setProperty(
        "--app-height",
        `${window.visualViewport?.height || window.innerHeight}px`,
      );
    window.visualViewport?.addEventListener("resize", resize);
    window.addEventListener("resize", resize);
    resize();
    return () => {
      window.visualViewport?.removeEventListener("resize", resize);
      window.removeEventListener("resize", resize);
    };
  }, []);
  return (
    <>
      <header>
        <h1>LuaTinker Playground</h1>
        <span
          id="status"
          role="status"
          data-state={execution.failed ? "failed" : "ready"}
        >
          {execution.status}
        </span>
        <div className="run-tools">
          <label htmlFor="entry-select">Entry</label>
          <select
            id="entry-select"
            aria-label="Lua entry file"
            value={state.entry || ""}
            disabled={!ready}
            onChange={(event) => {
              const entry = event.target.value || null;
              workspace.perform(() => workspace.selectEntry(entry));
            }}
          >
            <option value="">Select Lua entry</option>
            {state.entries.map((entry) => (
              <option key={entry} value={entry}>
                {entry}
              </option>
            ))}
          </select>
          <button
            className="primary"
            type="button"
            disabled={!ready || execution.phase === "starting"}
            onClick={() => workspace.perform(workspace.run)}
          >
            Run
          </button>
          <button
            type="button"
            disabled={!["starting", "running"].includes(execution.phase)}
            onClick={runtime.stop}
          >
            Stop
          </button>
        </div>
      </header>
      <nav id="mobile-tabs" role="tablist" aria-label="Workspace panes">
        {[
          ["files", "Files"],
          ["editor", "Code"],
          ["preview", "Run"],
        ].map(([pane, label]) => (
          <button
            key={pane}
            type="button"
            role="tab"
            aria-controls={`${pane}-panel`}
            aria-selected={state.pane === pane}
            tabIndex={state.pane === pane ? 0 : -1}
            onClick={() => workspace.selectPane(pane)}
          >
            {label}
          </button>
        ))}
      </nav>
      <Workbench>
        <FileTree workspace={workspace} state={state} />
        <Editor workspace={workspace} state={state} output={runtime.output} />
        <Preview runtime={runtime} workspace={workspace} pane={state.pane} />
      </Workbench>
      {state.dialog && <WorkspaceDialog request={state.dialog} />}
    </>
  );
}
