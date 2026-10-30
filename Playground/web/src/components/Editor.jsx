import { useLayoutEffect, useRef, useSyncExternalStore } from "react";
import { textOf } from "../files.js";
import { createEditor } from "../editor/codemirror.js";

export function Editor({ workspace, state, output }) {
  const host = useRef(null);
  const editor = useRef(null);
  const errors = useSyncExternalStore(output.subscribe, output.getErrors);
  const record = state.files.get(state.selected);
  const binary = !!record && textOf(record) === null;
  const disabled = !state.writable || !record || binary;
  useLayoutEffect(() => {
    const instance = createEditor(host.current, workspace);
    editor.current = instance;
    return () => instance.destroy();
  }, [workspace]);
  useLayoutEffect(() => {
    editor.current.sync({
      path: record && !binary ? state.selected : null,
      text: binary ? "" : state.draft,
      disabled,
      files: state.files,
      location: state.location,
      errors,
    });
  }, [state, errors, record, binary, disabled]);
  return (
    <section
      id="editor-panel"
      className={`pane ${state.pane === "editor" ? "active" : ""}`}
      role="tabpanel"
      aria-label="Code"
    >
      <div className="pane-header">
        <h2>{state.selected || "Code"}</h2>
        <button
          type="button"
          aria-label="Undo to previous run snapshot"
          disabled={disabled || !state.canUndo}
          onClick={() => workspace.moveSnapshot(-1)}
        >
          Undo run
        </button>
        <button
          type="button"
          aria-label="Redo run snapshot"
          disabled={disabled || !state.canRedo}
          onClick={() => workspace.moveSnapshot(1)}
        >
          Redo run
        </button>
        <button
          type="button"
          className="mobile-indent"
          disabled={disabled}
          onClick={() => editor.current.indent(false)}
        >
          Indent
        </button>
        <button
          type="button"
          className="mobile-indent"
          disabled={disabled}
          onClick={() => editor.current.indent(true)}
        >
          Outdent
        </button>
      </div>
      <div id="editor-wrap" hidden={binary}>
        <div ref={host} id="editor" />
      </div>
      <div id="binary-message" hidden={!binary}>
        Binary file — download or replace it from Files.
      </div>
      <div
        id="save-status"
        role="status"
        className={state.saveFailed ? "error" : ""}
      >
        {state.saveStatus}
      </div>
    </section>
  );
}
