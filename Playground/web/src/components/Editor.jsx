import { useLayoutEffect, useRef, useState } from "react";
import { textOf } from "../files.js";

export function Editor({ workspace, state }) {
  const editor = useRef(null);
  const gutter = useRef(null);
  const lastRevision = useRef(null);
  const [lineCount, setLineCount] = useState(1);
  const record = state.files.get(state.selected);
  const binary = !!record && textOf(record) === null;
  const disabled = !state.writable || !record || binary;
  const syncGutter = () => {
    gutter.current.style.transform = `translateY(${-editor.current.scrollTop}px)`;
  };
  function changed() {
    setLineCount(editor.current.value.split("\n").length);
    workspace.edit(editor.current.value);
    syncGutter();
  }
  useLayoutEffect(() => {
    // Typing updates the textarea directly; only external revisions replace its contents.
    if (lastRevision.current === state.editorRevision) return;
    lastRevision.current = state.editorRevision;
    const field = editor.current;
    const cursor = Math.min(field.selectionStart, state.draft.length);
    const scrollTop = field.scrollTop;
    field.value = state.draft;
    field.setSelectionRange(cursor, cursor);
    field.scrollTop = scrollTop;
    setLineCount(field.value.split("\n").length);
    syncGutter();
  }, [state.editorRevision, state.draft]);
  useLayoutEffect(() => {
    if (!state.location || state.location.path !== state.selected) return;
    const field = editor.current;
    let offset = 0;
    let row = 1;
    while (row < state.location.row) {
      const next = field.value.indexOf("\n", offset);
      if (next < 0) break;
      offset = next + 1;
      row++;
    }
    field.focus();
    field.setSelectionRange(offset, offset);
    field.scrollLeft = 0;
    const height = parseFloat(getComputedStyle(field).lineHeight);
    if (Number.isFinite(height))
      field.scrollTop = Math.max(
        0,
        (row - 1) * height - field.clientHeight / 3,
      );
    syncGutter();
  }, [state.location, state.selected]);
  function indent(outdent) {
    const field = editor.current;
    if (field.disabled) return;
    const value = field.value;
    const start = field.selectionStart;
    const end = field.selectionEnd;
    const lineStart = value.lastIndexOf("\n", start - 1) + 1;
    if (!outdent && start === end)
      field.setRangeText("    ", start, end, "end");
    else {
      const lineEnd =
        end > lineStart && value[end - 1] === "\n" ? end - 1 : end;
      const slice = value.slice(lineStart, lineEnd);
      const lines = slice.split("\n");
      const changed = lines.map((line) =>
        outdent ? line.replace(/^ {1,4}/, "") : "    " + line,
      );
      const firstDelta = changed[0].length - lines[0].length;
      const totalDelta = changed.join("\n").length - slice.length;
      const scrollTop = field.scrollTop;
      field.setRangeText(changed.join("\n"), lineStart, lineEnd, "preserve");
      field.setSelectionRange(
        Math.max(lineStart, start + firstDelta),
        Math.max(lineStart, lineEnd + totalDelta),
      );
      field.scrollTop = scrollTop;
    }
    changed();
    field.focus();
  }
  function keyDown(event) {
    if (event.key === "Tab") {
      event.preventDefault();
      indent(event.shiftKey);
    }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
      event.preventDefault();
      workspace.perform(workspace.flush);
    }
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      event.preventDefault();
      workspace.perform(workspace.run);
    }
  }
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
          Undo
        </button>
        <button
          type="button"
          aria-label="Redo run snapshot"
          disabled={disabled || !state.canRedo}
          onClick={() => workspace.moveSnapshot(1)}
        >
          Redo
        </button>
        <button type="button" disabled={disabled} onClick={() => indent(false)}>
          Indent
        </button>
        <button type="button" disabled={disabled} onClick={() => indent(true)}>
          Outdent
        </button>
      </div>
      <div id="editor-wrap" hidden={binary}>
        <div id="editor-gutter" aria-hidden="true">
          <div ref={gutter}>
            {Array.from({ length: lineCount }, (_, i) => i + 1).join("\n")}
          </div>
        </div>
        <textarea
          ref={editor}
          id="editor"
          disabled={disabled}
          spellCheck={false}
          autoCapitalize="off"
          autoComplete="off"
          autoCorrect="off"
          wrap="off"
          aria-label="File editor"
          placeholder={
            state.writable
              ? "Select or create a file"
              : "Persistent storage is unavailable in this browser."
          }
          onChange={changed}
          onScroll={syncGutter}
          onKeyDown={keyDown}
        />
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
