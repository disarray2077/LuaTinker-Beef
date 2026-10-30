import { Compartment, EditorState } from "@codemirror/state";
import {
  EditorView,
  crosshairCursor,
  drawSelection,
  dropCursor,
  highlightActiveLine,
  highlightActiveLineGutter,
  highlightSpecialChars,
  keymap,
  lineNumbers,
  placeholder,
  rectangularSelection,
} from "@codemirror/view";
import {
  bracketMatching,
  indentOnInput,
  indentUnit,
} from "@codemirror/language";
import {
  defaultKeymap,
  history,
  historyKeymap,
  indentLess,
  indentMore,
} from "@codemirror/commands";
import {
  acceptCompletion,
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  completionKeymap,
} from "@codemirror/autocomplete";
import {
  highlightSelectionMatches,
  search,
  searchKeymap,
} from "@codemirror/search";
import {
  lintGutter,
  lintKeymap,
  setDiagnostics,
  setDiagnosticsEffect,
} from "@codemirror/lint";
import { oneDark } from "@codemirror/theme-one-dark";
import { luaSupport } from "./lua-language.js";
import { primaryErrorLocation } from "../source-locations.js";

export function createEditor(parent, workspace) {
  const access = new Compartment();
  const language = new Compartment();
  const documents = new Map();
  let current = null;
  let previousFiles;
  let previousErrors;
  let errorRevision = 0;
  let lastLocation;
  let syncing = false;
  const extensions = [
    lineNumbers(),
    highlightActiveLineGutter(),
    highlightSpecialChars(),
    history(),
    drawSelection(),
    dropCursor(),
    rectangularSelection(),
    crosshairCursor(),
    EditorState.allowMultipleSelections.of(true),
    EditorState.tabSize.of(4),
    indentUnit.of("    "),
    indentOnInput(),
    bracketMatching(),
    closeBrackets(),
    autocompletion(),
    highlightActiveLine(),
    highlightSelectionMatches(),
    search(),
    lintGutter(),
    placeholder("Select or create a file"),
    oneDark,
    EditorView.contentAttributes.of({
      "aria-label": "File editor",
      spellcheck: "false",
      autocorrect: "off",
      autocapitalize: "off",
      writingsuggestions: "false",
      "data-gramm": "false",
      "data-enable-grammarly": "false",
    }),
    keymap.of([
      {
        key: "Mod-s",
        run: () => {
          workspace.perform(workspace.flush);
          return true;
        },
      },
      {
        key: "Mod-Enter",
        run: () => {
          workspace.perform(workspace.run);
          return true;
        },
      },
      {
        key: "Tab",
        run: (view) => acceptCompletion(view) || indentMore(view),
        shift: indentLess,
      },
      ...closeBracketsKeymap,
      ...completionKeymap,
      ...defaultKeymap,
      ...historyKeymap,
      ...searchKeymap,
      ...lintKeymap,
    ]),
    EditorState.transactionExtender.of((transaction) =>
      transaction.docChanged ? { effects: setDiagnosticsEffect.of([]) } : null,
    ),
    EditorView.updateListener.of((update) => {
      if (!update.docChanged || syncing || !current?.path) return;
      current.text = update.state.doc.toString();
      workspace.edit(current.text);
    }),
  ];
  function createDocument(path, text, disabled, selection) {
    return {
      path,
      text,
      errorRevision: -1,
      scroll: null,
      isLua: path?.toLowerCase().endsWith(".lua") ?? false,
      state: EditorState.create({
        doc: text,
        selection,
        extensions: [
          extensions,
          access.of([
            EditorState.readOnly.of(disabled),
            EditorView.editable.of(!disabled),
          ]),
          language.of(path?.toLowerCase().endsWith(".lua") ? luaSupport : []),
        ],
      }),
    };
  }
  const view = new EditorView({
    parent,
    state: createDocument(null, "", true).state,
  });

  function sync({ path, text, disabled, files, location, errors }) {
    syncing = true;
    try {
      if (errors !== previousErrors) {
        previousErrors = errors;
        errorRevision++;
      }
      if (current) {
        current.state = view.state;
        current.scroll = view.scrollSnapshot();
      }
      if (files !== previousFiles) {
        for (const [name, document] of documents) {
          if (!files.has(name)) {
            // Renames keep the same byte buffer, including files moved with a folder.
            const renamed = [...files].find(
              ([, record]) =>
                record.bytes && record.bytes === document.record?.bytes,
            );
            documents.delete(name);
            if (!renamed) continue;
            document.path = renamed[0];
            documents.set(document.path, document);
          }
          document.record = files.get(document.path);
        }
        previousFiles = files;
      }
      let document = path ? documents.get(path) : null;
      if (!document || document.text !== text) {
        const selection = document
          ? {
              anchor: Math.min(document.state.selection.main.head, text.length),
            }
          : undefined;
        document = createDocument(path, text, disabled, selection);
        // External replacements, such as run snapshots, establish a new typing history.
        if (path && documents.has(path)) document.errorRevision = errorRevision;
        if (path) documents.set(path, document);
      }
      document.record = files.get(path);
      if (current !== document) {
        current = document;
        view.setState(document.state);
        if (document.scroll) view.dispatch({ effects: document.scroll });
      }
      if (view.state.readOnly !== disabled)
        view.dispatch({
          effects: access.reconfigure([
            EditorState.readOnly.of(disabled),
            EditorView.editable.of(!disabled),
          ]),
        });
      const isLua = path?.toLowerCase().endsWith(".lua") ?? false;
      if (current.isLua !== isLua) {
        view.dispatch({
          effects: language.reconfigure(isLua ? luaSupport : []),
        });
      }
      current.isLua = isLua;
      if (current.errorRevision !== errorRevision) {
        current.errorRevision = errorRevision;
        const diagnostics = [];
        const source = primaryErrorLocation(
          errors,
          workspace.resolveSourcePath,
        );
        if (source?.path === path && source.row <= view.state.doc.lines) {
          const line = view.state.doc.line(source.row);
          diagnostics.push({
            from: line.from,
            to: line.to,
            severity: "error",
            message: source.message,
          });
        }
        view.dispatch(setDiagnostics(view.state, diagnostics));
      }
      if (location && location !== lastLocation && location.path === path) {
        lastLocation = location;
        const row = Math.max(1, Math.min(location.row, view.state.doc.lines));
        const position = view.state.doc.line(row).from;
        view.dispatch({
          selection: { anchor: position },
          effects: EditorView.scrollIntoView(position, { y: "center" }),
        });
        view.focus();
      }
    } finally {
      syncing = false;
    }
  }
  function indent(outdent) {
    if (view.state.readOnly) return;
    (outdent ? indentLess : indentMore)(view);
    view.focus();
  }
  return { sync, indent, destroy: () => view.destroy() };
}
