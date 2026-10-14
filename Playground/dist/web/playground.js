if (typeof window !== 'undefined') {
  (() => {
    const names = ['sdl_render.lua', 'gl_render.lua', 'rope/main.lua', 'breakout/main.lua'];
    let assets = [];
    const $ = (id) => document.getElementById(id);
    const editor = $('editor');
    const editorLines = $('editor-lines');
    const output = $('output');
    const requestRun = new URLSearchParams(location.search).get('run');
    const state = { db: null, files: new Map(), selected: null, focused: null, collapsed: new Set(), treeScrollTop: 0, entry: null, pane: 'editor', writable: false, dirty: false, timer: null, saves: Promise.resolve(), revision: 0, ready: false, running: false, starting: false, generation: 0, activeEntry: null };
    let histories = new Map();
    let restoringSnapshot = false;
    let numberedLines = 0;
    function syncLineNumbers() {
      editorLines.style.transform = `translateY(${-editor.scrollTop}px)`;
    }
    function updateLineNumbers() {
      const value = editor.value;
      let lines = 1;
      for (let at = value.indexOf('\n'); at !== -1; at = value.indexOf('\n', at + 1)) lines++;
      if (lines !== numberedLines) {
        numberedLines = lines;
        editorLines.textContent = Array.from({ length: lines }, (_, index) => index + 1).join('\n');
      }
      syncLineNumbers();
    }
    const encoder = new TextEncoder();
    const decoder = new TextDecoder('utf-8', { fatal: true });
    const ordered = () => [...state.files.keys()].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()) || a.localeCompare(b));
    const isFolder = (record) => record?.folder === true;
    function hasTopLevelReturn(source) {
      // Skip Lua comments and strings before tracking block boundaries.
      const tokens = /--(?:\[(=*)\[[\s\S]*?\]\1\]|[^\r\n]*)|\[(=*)\[[\s\S]*?\]\2\]|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*/g;
      let depth = 0;
      for (const [token] of source.matchAll(tokens)) {
        if (['function', 'if', 'do', 'repeat'].includes(token)) depth++;
        else if (token === 'end' || token === 'until') depth = Math.max(0, depth - 1);
        else if (token === 'return' && depth === 0) return true;
      }
      return false;
    }
    function isEntryFile(path) {
      if (!path || !path.toLowerCase().endsWith('.lua')) return false;
      const source = textOf(state.files.get(path));
      return source !== null && !hasTopLevelReturn(source);
    }
    const entryFiles = () => ordered().filter(isEntryFile);
    function updateEntries() {
      const entries = entryFiles();
      if (state.entry && !entries.includes(state.entry)) {
        state.entry = null;
        const previous = $('file-list').querySelector('[data-entry=true]');
        if (previous) previous.dataset.entry = 'false';
      }
      $('entry-select').replaceChildren(new Option('Select Lua entry', ''), ...entries.map((path) => new Option(path, path)));
      $('entry-select').value = entries.includes(state.entry) ? state.entry : '';
    }

    function status(text, failed = false) {
      $('status').textContent = text;
      $('status').dataset.state = failed ? 'failed' : 'ready';
    }
    function normalizeSourcePath(path) {
      const parts = [];
      for (const part of path.split('/')) {
        if (!part || part === '.') continue;
        if (part === '..') {
          if (!parts.length) return null;
          parts.pop();
        } else parts.push(part);
      }
      return parts.join('/');
    }
    function resolveSourcePath(reference) {
      const absolute = reference.startsWith('/workspace/');
      if (reference.startsWith('/') && !absolute) return null;
      const relative = absolute ? reference.slice('/workspace/'.length) : reference;
      const root = normalizeSourcePath(relative);
      if (root && textOf(state.files.get(root)) !== null) return root;
      if (absolute) return null;
      const entry = state.activeEntry || state.entry;
      if (entry?.includes('/')) {
        const besideEntry = normalizeSourcePath(entry.slice(0, entry.lastIndexOf('/') + 1) + relative);
        if (besideEntry && textOf(state.files.get(besideEntry)) !== null) return besideEntry;
      }
      if (!root) return null;
      let unique = null;
      for (const path of state.files.keys()) {
        if (path.endsWith('/' + root) && textOf(state.files.get(path)) !== null) {
          if (unique) return null;
          unique = path;
        }
      }
      return unique;
    }

    function log(message, failed = false) {
      const text = String(message);
      const line = document.createElement('div');
      const locations = /(^|[\s("'`])((?:\/workspace\/|\.{1,2}\/)[^\r\n:'"<>()[\]{}]+?|[^\s:'"<>()[\]{}]+):([1-9]\d*)(?=[:\s)\]]|$)/gm;
      let cursor = 0;
      for (const match of text.matchAll(locations)) {
        const path = resolveSourcePath(match[2]);
        const row = Number(match[3]);
        if (!path || !Number.isSafeInteger(row)) continue;
        const start = match.index + match[1].length;
        if (start > cursor) line.append(document.createTextNode(text.slice(cursor, start)));
        const link = document.createElement('a');
        link.href = '#editor';
        link.textContent = `${match[2]}:${match[3]}`;
        link.title = `Open ${path} at line ${row}`;
        link.onclick = (event) => {
          event.preventDefault();
          perform(() => openSourceLocation(path, row));
        };
        line.append(link);
        cursor = start + link.textContent.length;
      }
      if (!cursor) line.textContent = text;
      else if (cursor < text.length) line.append(document.createTextNode(text.slice(cursor)));
      if (failed) { line.className = 'error'; status('Failed', true); }
      output.appendChild(line);
      output.scrollTop = output.scrollHeight;
    }
    Module.print = (...parts) => { console.log(...parts); log(parts.join(' ')); };
    Module.printErr = (...parts) => { console.error(...parts); log(parts.join(' '), true); };
    Module.onAbort = (reason) => {
      state.ready = state.running = state.starting = false;
      updateRunControls();
      console.error(reason);
      log('WASM aborted: ' + reason, true);
    };
    window.onerror = (message, source, line, column, error) => {
      console.error(error || message);
      log(error && error.stack ? error.stack : `${message} (${source}:${line}:${column})`, true);
      return false;
    };
    window.onunhandledrejection = (event) => {
      console.error(event.reason);
      log(event.reason && event.reason.stack ? event.reason.stack : event.reason, true);
    };

    function resize() {
      document.documentElement.style.setProperty('--app-height', `${window.visualViewport?.height || window.innerHeight}px`);
    }
    window.visualViewport?.addEventListener('resize', resize);
    window.addEventListener('resize', resize);
    resize();

    function validPath(path) {
      if (!path || path.startsWith('/') || path.endsWith('/') || path.split('/').some((part) => !part || part === '.' || part === '..' || part.includes('\\'))) {
        return 'Use a relative path without empty, . or .. components.';
      }
      return null;
    }
    function parentPaths(path) {
      const parents = [];
      for (let slash = path.indexOf('/'); slash !== -1; slash = path.indexOf('/', slash + 1)) parents.push(path.slice(0, slash));
      return parents;
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
      if (!ignored.has(path) && (state.files.has(path) || folders.has(path))) return 'A file or folder already exists at that path.';
      if (parentPaths(path).some((parent) => !ignored.has(parent) && state.files.has(parent) && !isFolder(state.files.get(parent)))) return 'A parent path is a file.';
      return null;
    }
    function missingFolders(paths) {
      const additions = new Map();
      for (const path of paths) {
        for (const parent of parentPaths(path)) {
          if (!state.files.has(parent)) additions.set(parent, { path: parent, folder: true });
        }
      }
      return [...additions.values()];
    }
    function bytesOf(record) { return new Uint8Array(record.bytes); }
    function textOf(record) {
      if (!record || isFolder(record)) return null;
      try {
        const bytes = bytesOf(record);
        const text = decoder.decode(bytes);
        return text.includes('\0') ? null : text;
      } catch { return null; }
    }
    function restoreHistories() {
      for (const [path, history] of histories) {
        const record = state.files.get(path);
        const text = record && textOf(record);
        if (text === null || text === undefined || !history.runs.length) {
          histories.delete(path);
          continue;
        }
        if (text !== (history.position === history.runs.length ? history.draft : history.runs[history.position])) {
          history.runs.splice(history.position + 1);
          history.draft = text;
          history.position = history.runs.length;
        }
      }
    }
    function historyForSelected() { return histories.get(state.selected); }
    function updateHistoryControls() {
      const history = historyForSelected();
      $('undo').disabled = editor.disabled || !history || history.position === 0;
      $('redo').disabled = editor.disabled || !history || history.position >= history.runs.length - (history.draft === null ? 1 : 0);
    }
    function noteEdit() {
      const history = historyForSelected();
      if (!history) return;
      if (history.position < history.runs.length) history.runs.splice(history.position + 1);
      const previous = history.runs.at(-1);
      history.draft = editor.value === previous ? null : editor.value;
      history.position = history.draft === null ? history.runs.length - 1 : history.runs.length;
      updateHistoryControls();
    }
    function moveSnapshot(direction) {
      const history = historyForSelected();
      if (editor.disabled || !history) return;
      const target = history.position + direction;
      const last = history.runs.length - 1 + (history.draft === null ? 0 : 1);
      if (target < 0 || target > last) return;
      history.position = target;
      const text = target === history.runs.length ? history.draft : history.runs[target];
      const cursor = Math.min(editor.selectionStart, text.length);
      const scrollTop = editor.scrollTop;
      restoringSnapshot = true;
      editor.value = text;
      editor.setSelectionRange(cursor, cursor);
      editor.scrollTop = scrollTop;
      editor.dispatchEvent(new Event('input', { bubbles: true }));
      restoringSnapshot = false;
      updateHistoryControls();
      editor.focus();
    }
    function snapshotRun() {
      const next = new Map([...histories].map(([path, history]) =>
        [path, { runs: [...history.runs], position: history.position, draft: history.draft }]));
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
      updateHistoryControls();
    }
    function tx(stores, mode, work) {
      return new Promise((resolve, reject) => {
        const transaction = state.db.transaction(stores, mode);
        let result;
        transaction.oncomplete = () => resolve(result);
        transaction.onerror = () => reject(transaction.error);
        transaction.onabort = () => reject(transaction.error || new Error('Transaction aborted'));
        try { result = work(transaction); } catch (error) { transaction.abort(); reject(error); }
      });
    }
    function getAll(store) {
      return new Promise((resolve, reject) => {
        const transaction = state.db.transaction(store, 'readonly');
        const request = transaction.objectStore(store).getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
    }
    function openDb() {
      return new Promise((resolve, reject) => {
        const request = indexedDB.open('LuaTinkerPlayground', 1);
        request.onupgradeneeded = () => {
          const db = request.result;
          db.createObjectStore('files', { keyPath: 'path' });
          db.createObjectStore('meta', { keyPath: 'key' });
        };
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
        request.onblocked = () => reject(new Error('Database is blocked'));
      });
    }
    function templateRecords() {
      const records = [];
      function collect(directory, prefix) {
        for (const name of FS.readdir(directory)) {
          if (name === '.' || name === '..') continue;
          const path = directory + '/' + name;
          const relative = prefix + name;
          if (FS.isDir(FS.stat(path).mode)) collect(path, relative + '/');
          else records.push({ path: relative, bytes: FS.readFile(path).slice().buffer });
        }
      }
      collect('/templates', '');
      assets = records.map(({ path }) => path).filter((path) => !names.includes(path));
      return records;
    }
    function setMeta(store, key, value) { store.put({ key, value }); }
    async function load() {
      const seeds = templateRecords();
      state.db = await openDb();
      const meta = await getAll('meta');
      const values = Object.fromEntries(meta.map(({ key, value }) => [key, value]));
      const existing = new Map((await getAll('files')).map((record) => [record.path, record]));
      // Earlier workspaces did not record which templates had already been offered.
      const packagedFiles = new Set(values.packagedFiles || (values.initialized
        ? ['sdl_render.lua', 'gl_render.lua', 'modules/opengl.lua', 'modules/decoded_image.lua'] : []));
      await tx(['files', 'meta'], 'readwrite', (transaction) => {
        const files = transaction.objectStore('files');
        for (const record of seeds) {
          if (packagedFiles.has(record.path) || existing.has(record.path)) continue;
          if (parentPaths(record.path).some((parent) => existing.has(parent) && !isFolder(existing.get(parent)))) continue;
          files.add(record);
        }
        const store = transaction.objectStore('meta');
        setMeta(store, 'packagedFiles', seeds.map(({ path }) => path));
        if (!values.initialized) {
          setMeta(store, 'initialized', true);
          setMeta(store, 'entry', names[0]);
          setMeta(store, 'selected', names[0]);
          setMeta(store, 'activePane', 'editor');
        }
      });
      state.writable = true;
      await refresh();
    }
    async function refresh() {
      const [records, meta] = await Promise.all([getAll('files'), getAll('meta')]);
      state.files = new Map(records.map((record) => [record.path, record]));
      state.collapsed = folderPaths();
      restoreHistories();
      const values = Object.fromEntries(meta.map(({ key, value }) => [key, value]));
      state.entry = values.entry || null;
      state.focused = values.selected || null;
      const selectedRecord = state.files.get(state.focused);
      state.selected = selectedRecord && !isFolder(selectedRecord)
        ? state.focused
        : (state.files.has(state.entry) && !isFolder(state.files.get(state.entry)) ? state.entry : ordered().find((path) => !isFolder(state.files.get(path))) || null);
      state.pane = values.activePane || 'editor';
      if (!['files', 'editor', 'preview'].includes(state.pane)) state.pane = 'editor';
      render();
    }
    function render() {
      updateEntries();
      const folders = folderPaths();
      const children = new Map();
      for (const path of new Set([...state.files.keys(), ...folders])) {
        const slash = path.lastIndexOf('/');
        const parent = slash < 0 ? '' : path.slice(0, slash);
        if (!children.has(parent)) children.set(parent, []);
        children.get(parent).push(path);
      }
      for (const paths of children.values()) {
        paths.sort((a, b) => Number(folders.has(b)) - Number(folders.has(a)) ||
          a.toLowerCase().localeCompare(b.toLowerCase()) || a.localeCompare(b));
      }
      const tree = document.createDocumentFragment();
      function focusItem(path, button) {
        state.focused = path;
        $('file-list').querySelector('button[aria-current="true"]')?.setAttribute('aria-current', 'false');
        button.setAttribute('aria-current', 'true');
        $('rename-file').disabled = $('delete-file').disabled = !state.writable || !path;
        const record = state.files.get(path);
        $('download-file').disabled = !record || isFolder(record);
      }
      function appendChildren(parent, container) {
        for (const path of children.get(parent) || []) {
          const folder = folders.has(path);
          const collapsed = folder && state.collapsed.has(path);
          const item = document.createElement('li');
          const button = document.createElement('button');
          button.type = 'button';
          const label = path.slice(parent ? parent.length + 1 : 0) + (folder ? '/' : '');
          button.textContent = (folder ? (collapsed ? '▸ ' : '▾ ') : '') + label;
          button.dataset.folder = String(folder);
          button.dataset.entry = String(!folder && path === state.entry);
          button.setAttribute('aria-current', String(path === state.focused));
          if (folder) button.setAttribute('aria-expanded', String(!collapsed));
          button.onclick = () => perform(async () => {
            await flush();
            focusItem(path, button);
            if (folder) {
              const expanded = state.collapsed.has(path);
              if (expanded) state.collapsed.delete(path);
              else state.collapsed.add(path);
              branch.hidden = !expanded;
              button.textContent = (expanded ? '▾ ' : '▸ ') + label;
              button.setAttribute('aria-expanded', String(expanded));
              return;
            }
            state.selected = path;
            if (state.db) await tx('meta', 'readwrite', (t) => setMeta(t.objectStore('meta'), 'selected', path));
            renderEditor();
            selectPane('editor');
          });
          if (!folder && path.toLowerCase().endsWith('.lua'))
            button.ondblclick = () => perform(() => selectEntry(path));
          if (!folder && (names.includes(path) || assets.includes(path))) {
            const row = document.createElement('div');
            row.className = 'file-row';
            const reset = document.createElement('button');
            reset.type = 'button';
            reset.className = 'reset-file';
            reset.dataset.resetPath = path;
            reset.textContent = 'Reset';
            reset.setAttribute('aria-label', `Reset ${path} to bundled version`);
            reset.disabled = !state.writable;
            reset.onclick = () => perform(() => resetPackagedFile(path));
            row.append(button, reset);
            item.append(row);
          } else item.append(button);
          const branch = folder ? document.createElement('ul') : null;
          if (branch) {
            branch.className = 'tree-children';
            branch.hidden = collapsed;
            appendChildren(path, branch);
            item.append(branch);
          }
          container.append(item);
        }
      }
      const root = document.createElement('li');
      const rootButton = document.createElement('button');
      rootButton.type = 'button';
      rootButton.textContent = 'Workspace /';
      rootButton.dataset.folder = 'true';
      rootButton.setAttribute('aria-current', String(state.focused === ''));
      rootButton.onclick = () => perform(async () => {
        await flush();
        focusItem('', rootButton);
      });
      root.append(rootButton);
      const rootChildren = document.createElement('ul');
      rootChildren.className = 'tree-children';
      appendChildren('', rootChildren);
      root.append(rootChildren);
      tree.append(root);
      $('file-list').replaceChildren(tree);
      $('rename-file').disabled = $('delete-file').disabled = !state.writable || !state.focused;
      const focusedFile = state.files.get(state.focused);
      $('download-file').disabled = !focusedFile || isFolder(focusedFile);
      for (const id of ['new-file', 'new-folder', 'upload-button', 'upload-folder-button', 'reset-examples']) $(id).disabled = !state.writable;
      $('upload-folder-button').hidden = !('webkitdirectory' in $('upload-folder-files'));
      $('entry-select').disabled = !state.ready;
      updateRunControls();
      renderEditor();
    }
    function renderEditor() {
      const record = state.files.get(state.selected);
      const text = textOf(record);
      $('editor-title').textContent = state.selected || 'Code';
      $('editor-wrap').hidden = Boolean(record && text === null);
      $('binary-message').hidden = !record || text !== null;
      editor.disabled = !state.writable || !record || text === null;
      editor.value = text ?? '';
      updateLineNumbers();
      editor.placeholder = state.writable ? 'Select or create a file' : 'Persistent storage is unavailable in this browser.';
      $('indent').disabled = $('outdent').disabled = editor.disabled;
      updateHistoryControls();
      $('save-status').textContent = record ? (text === null ? '' : 'Saved') : '';
      setPane(state.pane);
    }
    function setPane(pane) {
      state.pane = pane;
      for (const [name, panel] of [['files', 'files-panel'], ['editor', 'editor-panel'], ['preview', 'preview-panel']]) {
        $(panel).classList.toggle('active', pane === name);
        const tab = document.querySelector(`[data-pane="${name}"]`);
        tab.setAttribute('aria-selected', String(pane === name));
        tab.tabIndex = pane === name ? 0 : -1;
      }
      syncLineNumbers();
    }
    function selectPane(pane) {
      setPane(pane);
      if (state.db) perform(() => tx('meta', 'readwrite', (t) => setMeta(t.objectStore('meta'), 'activePane', pane)));
    }
    async function openSourceLocation(path, row) {
      if (textOf(state.files.get(path)) === null) return;
      await flush();
      if (state.db) await tx('meta', 'readwrite', (t) => setMeta(t.objectStore('meta'), 'selected', path));
      state.focused = state.selected = path;
      for (const parent of parentPaths(path)) state.collapsed.delete(parent);
      render();
      selectPane('editor');
      let offset = 0;
      let currentLine = 1;
      while (currentLine < row) {
        const next = editor.value.indexOf('\n', offset);
        if (next < 0) break;
        offset = next + 1;
        currentLine++;
      }
      editor.focus();
      editor.setSelectionRange(offset, offset);
      editor.scrollLeft = 0;
      const lineHeight = parseFloat(getComputedStyle(editor).lineHeight);
      if (Number.isFinite(lineHeight)) {
        editor.scrollTop = Math.max(0, (currentLine - 1) * lineHeight - editor.clientHeight / 3);
      }
      syncLineNumbers();
    }

    function perform(operation) {
      return Promise.resolve().then(operation).catch((error) => {
        status('Save failed: ' + error.message, true);
        $('save-status').textContent = 'Save failed: ' + error.message;
        $('save-status').classList.add('error');
      });
    }
    function queueSave() {
      clearTimeout(state.timer);
      state.timer = null;
      if (!state.dirty) return state.saves;
      const path = state.selected;
      const value = editor.value;
      const revision = state.revision;
      state.dirty = false;
      state.saves = state.saves.catch(() => {}).then(async () => {
        const record = { path, bytes: encoder.encode(value).buffer };
        await tx('files', 'readwrite', (t) => t.objectStore('files').put(record));
        state.files.set(path, record);
        updateEntries();
        if (revision === state.revision) {
          $('save-status').textContent = 'Saved';
          $('save-status').classList.remove('error');
        }
      }).catch((error) => {
        state.dirty = true;
        $('save-status').textContent = 'Save failed: ' + error.message;
        $('save-status').classList.add('error');
        throw error;
      });
      return state.saves;
    }
    async function flush() { await queueSave(); }
    $('file-list').addEventListener('scroll', () => {
      const fileList = $('file-list');
      if (fileList.offsetParent !== null) state.treeScrollTop = fileList.scrollTop;
    });
    editor.addEventListener('scroll', syncLineNumbers);
    editor.addEventListener('input', () => {
      updateLineNumbers();
      if (!restoringSnapshot) noteEdit();
      state.revision++;
      state.dirty = true;
      $('save-status').textContent = 'Saving…';
      $('save-status').classList.remove('error');
      clearTimeout(state.timer);
      state.timer = setTimeout(() => { perform(flush); }, 300);
    });

    function changeIndent(outdent) {
      if (editor.disabled) return;
      const value = editor.value;
      const start = editor.selectionStart;
      const end = editor.selectionEnd;
      const lineStart = value.lastIndexOf('\n', start - 1) + 1;
      if (!outdent && start === end) {
        editor.setRangeText('    ', start, end, 'end');
      } else {
        const lineEnd = end > lineStart && value[end - 1] === '\n' ? end - 1 : end;
        const slice = value.slice(lineStart, lineEnd);
        const lines = slice.split('\n');
        const changed = lines.map((line) => outdent ? line.replace(/^ {1,4}/, '') : '    ' + line);
        const firstDelta = changed[0].length - lines[0].length;
        const totalDelta = changed.join('\n').length - slice.length;
        const scrollTop = editor.scrollTop;
        editor.setRangeText(changed.join('\n'), lineStart, lineEnd, 'preserve');
        editor.setSelectionRange(Math.max(lineStart, start + firstDelta), Math.max(lineStart, lineEnd + totalDelta));
        editor.scrollTop = scrollTop;
      }
      editor.dispatchEvent(new Event('input', { bubbles: true }));
      editor.focus();
    }
    $('indent').onclick = () => changeIndent(false);
    $('outdent').onclick = () => changeIndent(true);
    $('undo').onclick = () => moveSnapshot(-1);
    $('redo').onclick = () => moveSnapshot(1);
    editor.addEventListener('keydown', (event) => {
      if (event.key === 'Tab') { event.preventDefault(); changeIndent(event.shiftKey); }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') { event.preventDefault(); perform(flush); }
      if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); perform(run); }
    });

    function dialog({ title, message = '', path = null, confirm = 'Confirm', validate = () => null }) {
      return new Promise((resolve) => {
        const box = $('workspace-dialog');
        const field = $('dialog-path');
        $('dialog-title').textContent = title;
        $('dialog-message').textContent = message;
        $('dialog-error').textContent = '';
        $('dialog-confirm').textContent = confirm;
        field.hidden = path === null;
        field.value = path || '';
        let settled = false;
        function finish(result) {
          if (settled) return;
          settled = true;
          box.querySelector('form').removeEventListener('submit', submit);
          $('dialog-cancel').removeEventListener('click', cancel);
          box.removeEventListener('cancel', cancel);
          if (box.open) box.close();
          resolve(result);
        }
        function cancel(event) { event.preventDefault(); finish(null); }
        function submit(event) {
          event.preventDefault();
          const value = field.hidden ? true : field.value.replaceAll('\\', '/');
          const error = validate(value);
          if (error) { $('dialog-error').textContent = error; field.focus(); return; }
          finish(value);
        }
        box.querySelector('form').addEventListener('submit', submit);
        $('dialog-cancel').addEventListener('click', cancel);
        box.addEventListener('cancel', cancel);
        box.showModal();
        if (!field.hidden) field.focus();
      });
    }
    async function createItem(folder) {
      await flush();
      const prefix = folderPaths().has(state.focused) ? state.focused + '/' : '';
      const path = await dialog({
        title: folder ? 'New folder' : 'New file', path: prefix, confirm: 'Create',
        validate: (value) => pathIssue(value)
      });
      if (path === null) return;
      const parents = missingFolders([path]);
      const record = folder ? { path, folder: true } : { path, bytes: new ArrayBuffer(0) };
      await tx(['files', 'meta'], 'readwrite', (t) => {
        const files = t.objectStore('files');
        for (const parent of parents) files.add(parent);
        files.add(record);
        if (!folder) setMeta(t.objectStore('meta'), 'selected', path);
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
      render();
      if (!folder) {
        selectPane('editor');
        editor.focus();
      }
    }
    async function renameFile() {
      await flush();
      const old = state.focused;
      if (!old) return;
      const folder = folderPaths().has(old);
      const folders = folderPaths();
      const moved = [...state.files.values()].filter((record) =>
        record.path === old || (folder && record.path.startsWith(old + '/')));
      const sources = new Set(moved.map((record) => record.path));
      const path = await dialog({
        title: folder ? 'Rename folder' : 'Rename file', path: old, confirm: 'Rename',
        validate: (value) => {
          if (value === old) return null;
          if (value.startsWith(old + '/')) return 'An item cannot move inside itself.';
          const renamed = moved.map((record) => ({ ...record, path: value + record.path.slice(old.length) }));
          if (folder && !state.files.has(old)) renamed.unshift({ path: value, folder: true });
          for (const record of renamed) {
            const issue = pathIssue(record.path, folders, sources);
            if (issue) return issue;
          }
          return null;
        }
      });
      if (path === null || path === old) return;
      const renamed = moved.map((record) => ({ ...record, path: path + record.path.slice(old.length) }));
      if (folder && !state.files.has(old)) renamed.unshift({ path, folder: true });
      const parents = missingFolders([path]);
      const entry = state.entry && (state.entry === old || (folder && state.entry.startsWith(old + '/')))
        ? path + state.entry.slice(old.length) : state.entry;
      const selected = state.selected && (state.selected === old || (folder && state.selected.startsWith(old + '/')))
        ? path + state.selected.slice(old.length) : state.selected;
      await tx(['files', 'meta'], 'readwrite', (t) => {
        const files = t.objectStore('files');
        for (const record of moved) files.delete(record.path);
        for (const parent of parents) files.put(parent);
        for (const record of renamed) files.add(record);
        const meta = t.objectStore('meta');
        setMeta(meta, 'selected', selected);
        if (entry !== state.entry) setMeta(meta, 'entry', entry);
      });
      for (const record of moved) {
        state.files.delete(record.path);
        if (histories.has(record.path)) {
          histories.set(path + record.path.slice(old.length), histories.get(record.path));
          histories.delete(record.path);
        }
      }
      for (const parent of parents) state.files.set(parent.path, parent);
      for (const record of renamed) state.files.set(record.path, record);
      state.focused = path;
      state.selected = selected;
      state.collapsed = new Set([...state.collapsed].map((folderPath) =>
        folderPath === old || folderPath.startsWith(old + '/') ? path + folderPath.slice(old.length) : folderPath));
      for (const parent of parentPaths(path)) state.collapsed.delete(parent);
      state.entry = entry;
      render();
    }
    async function deleteFile() {
      await flush();
      const path = state.focused;
      if (!path) return;
      const folder = folderPaths().has(path);
      const removed = [...state.files.keys()].filter((name) =>
        name === path || (folder && name.startsWith(path + '/')));
      const message = folder
        ? `Delete folder ${path} and its ${removed.length - Number(state.files.has(path))} nested items? This cannot be undone.`
        : `Delete ${path}? This cannot be undone.`;
      if (await dialog({ title: folder ? 'Delete folder' : 'Delete file', message, confirm: 'Delete' }) === null) return;
      const removedSet = new Set(removed);
      const paths = ordered();
      const remaining = paths.filter((name) => !removedSet.has(name));
      const next = remaining[Math.min(Math.max(paths.indexOf(path), 0), remaining.length - 1)] || null;
      const remainingFiles = remaining.filter((name) => !isFolder(state.files.get(name)));
      const selected = removedSet.has(state.selected)
        ? (remainingFiles[Math.min(Math.max(paths.indexOf(state.selected), 0), remainingFiles.length - 1)] || null)
        : state.selected;
      const entry = removedSet.has(state.entry)
        ? (remainingFiles.find((name) => name.toLowerCase().endsWith('.lua')) || null)
        : state.entry;
      await tx(['files', 'meta'], 'readwrite', (t) => {
        for (const name of removed) t.objectStore('files').delete(name);
        setMeta(t.objectStore('meta'), 'selected', selected);
        setMeta(t.objectStore('meta'), 'entry', entry);
      });
      for (const name of removed) {
        state.files.delete(name);
        histories.delete(name);
      }
      state.focused = next;
      state.selected = selected;
      for (const folderPath of [...state.collapsed]) {
        if (folderPath === path || folderPath.startsWith(path + '/')) state.collapsed.delete(folderPath);
      }
      state.entry = entry;
      render();
    }
    async function uploadFiles(event) {
      await flush();
      const files = [...event.target.files];
      const folderUpload = event.target.id === 'upload-folder-files';
      event.target.value = '';
      if (!files.length) return;
      const prefix = folderPaths().has(state.focused) ? state.focused + '/' : '';
      const folders = folderPaths();
      const incoming = new Set();
      const records = [];
      for (const file of files) {
        if (folderUpload && !file.webkitRelativePath) {
          status('This browser did not provide folder paths.', true);
          return;
        }
        const path = prefix + (folderUpload ? file.webkitRelativePath : file.name).replaceAll('\\', '/');
        if (validPath(path) || folders.has(path) || incoming.has(path)) {
          status('Invalid or duplicate upload path: ' + path, true);
          return;
        }
        incoming.add(path);
        records.push({ path, bytes: await file.arrayBuffer() });
      }
      for (const { path } of records) {
        if (parentPaths(path).some((parent) => incoming.has(parent) ||
          (state.files.has(parent) && !isFolder(state.files.get(parent))))) {
          status('Cannot upload into a file: ' + path, true);
          return;
        }
      }
      const collisions = records.filter(({ path }) => state.files.has(path));
      if (collisions.length && await dialog({ title: 'Replace files?', message: `Replace ${collisions.map(({ path }) => path).join(', ')}? All selected files will be imported.`, confirm: 'Replace' }) === null) return;
      const parents = missingFolders(records.map((record) => record.path));
      await tx(['files', 'meta'], 'readwrite', (t) => {
        const store = t.objectStore('files');
        for (const parent of parents) store.add(parent);
        for (const record of records) store.put(record);
        setMeta(t.objectStore('meta'), 'selected', records[0].path);
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
      for (const parent of parentPaths(state.selected)) state.collapsed.delete(parent);
      render();
      selectPane('editor');
    }
    async function resetPackagedFile(path) {
      await flush();
      if (await dialog({ title: 'Reset file?', message: `Replace ${path} with its bundled version? This cannot be undone.`, confirm: 'Reset file' }) === null) return;
      const record = { path, bytes: FS.readFile('/templates/' + path).slice().buffer };
      await tx('files', 'readwrite', (t) => t.objectStore('files').put(record));
      state.files.set(path, record);
      histories.delete(path);
      if (state.selected === path) {
        render();
        $('file-list').querySelector(`button[data-reset-path="${path}"]`)?.focus();
      }
      status('Restored ' + path);
    }
    async function downloadFile() {
      await flush();
      const path = state.focused;
      const record = state.files.get(path);
      if (!record || isFolder(record)) return;
      const url = URL.createObjectURL(new Blob([record.bytes], { type: 'application/octet-stream' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = path.slice(path.lastIndexOf('/') + 1);
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
    async function resetExamples() {
      await flush();
      if (await dialog({ title: 'Reset examples?', message: `Replace the entire workspace with the ${names.length} packaged Lua examples? This cannot be undone.`, confirm: 'Reset examples' }) === null) return;
      const seeds = templateRecords();
      await tx(['files', 'meta'], 'readwrite', (t) => {
        const files = t.objectStore('files');
        files.clear();
        for (const record of seeds) files.add(record);
        const meta = t.objectStore('meta');
        setMeta(meta, 'entry', names[0]);
        setMeta(meta, 'selected', names[0]);
        setMeta(meta, 'activePane', 'editor');
        setMeta(meta, 'packagedFiles', seeds.map(({ path }) => path));
      });
      state.files = new Map(seeds.map((record) => [record.path, record]));
      histories.clear();
      state.treeScrollTop = 0;
      state.focused = state.entry = state.selected = names[0];
      state.collapsed = folderPaths();
      render();
      selectPane('editor');
    }
    function updateRunControls() {
      $('run').disabled = !state.ready || state.starting;
      $('stop').disabled = !state.running && !state.starting;
    }
    function runUrl(entry) {
      const url = new URL(location.href);
      if (entry) url.searchParams.set('run', entry);
      else url.searchParams.delete('run');
      history.replaceState(null, '', url.href);
    }
    function stop() {
      state.generation++;
      if (state.ready) Module.ccall('PlaygroundStop', null, [], []);
      state.running = false;
      runUrl(null);
      updateRunControls();
      status('Stopped');
    }
    Module.onPlaygroundStopped = () => {
      state.running = false;
      runUrl(null);
      updateRunControls();
      if ($('status').dataset.state !== 'failed') status('Finished');
    };
    function syncWorkspace() {
      // Rebuild only the run's filesystem snapshot, including removed and renamed files.
      FS.chdir('/');
      function remove(directory) {
        for (const name of FS.readdir(directory)) {
          if (name === '.' || name === '..') continue;
          const path = directory + '/' + name;
          if (FS.isDir(FS.stat(path).mode)) { remove(path); FS.rmdir(path); }
          else FS.unlink(path);
        }
      }
      FS.mkdirTree('/workspace');
      remove('/workspace');
      for (const [path, record] of state.files) {
        const destination = '/workspace/' + path;
        if (isFolder(record)) FS.mkdirTree(destination);
        else {
          FS.mkdirTree(destination.slice(0, destination.lastIndexOf('/')));
          FS.writeFile(destination, bytesOf(record));
        }
      }
    }
    async function run() {
      if (!state.ready || state.starting) return;
      state.starting = true;
      const generation = ++state.generation;
      updateRunControls();
      try {
        await flush();
        if (generation !== state.generation) return;
        if (!isEntryFile(state.entry)) {
          log('Select a Lua entry file before running.', true);
          selectPane('preview');
          return;
        }
        Module.ccall('PlaygroundStop', null, [], []);
        state.running = false;
        snapshotRun();
        syncWorkspace();
        // A canvas cannot switch between SDL's 2D and WebGL contexts after creation.
        const canvas = $('canvas').cloneNode(false);
        $('canvas').replaceWith(canvas);
        Module.canvas = canvas;
        state.activeEntry = state.entry;
        output.replaceChildren();
        status('Running');
        selectPane('preview');
        if (Module.ccall('PlaygroundStart', 'number', ['string'], ['/workspace/' + state.entry]) === 0) {
          state.running = true;
          runUrl(state.entry);
          canvas.focus({ preventScroll: true });
        }
      } catch (error) {
        Module.ccall('PlaygroundStop', null, [], []);
        log(error.stack || error, true);
      } finally {
        state.starting = false;
        updateRunControls();
      }
    }
    $('new-file').onclick = () => perform(() => createItem(false));
    $('new-folder').onclick = () => perform(() => createItem(true));
    $('rename-file').onclick = () => perform(renameFile);
    $('delete-file').onclick = () => perform(deleteFile);
    $('download-file').onclick = () => perform(downloadFile);
    $('reset-examples').onclick = () => perform(resetExamples);
    $('upload-button').onclick = () => $('upload-files').click();
    $('upload-files').onchange = (event) => perform(() => uploadFiles(event));
    $('upload-folder-button').onclick = () => $('upload-folder-files').click();
    $('upload-folder-files').onchange = (event) => perform(() => uploadFiles(event));
    async function selectEntry(entry) {
      await flush();
      if (entry !== null && !isEntryFile(entry)) return;
      state.entry = entry;
      if (state.db) await tx('meta', 'readwrite', (t) => setMeta(t.objectStore('meta'), 'entry', state.entry));
      render();
    }
    $('entry-select').onchange = () => perform(() => selectEntry($('entry-select').value || null));
    $('run').onclick = () => perform(run);
    $('stop').onclick = stop;
    for (const tab of document.querySelectorAll('#mobile-tabs button')) tab.onclick = () => selectPane(tab.dataset.pane);

    render();
    Module.onRuntimeInitialized = async () => {
      Module.callMain([]);
      state.ready = true;
      try {
        await load();
      } catch (error) {
        console.error(error);
        state.db?.close();
        state.db = null;
        state.files = new Map(templateRecords().map((record) => [record.path, record]));
        state.collapsed = folderPaths();
        state.focused = state.selected = state.entry = names[0];
        state.writable = false;
        render();
        log('Persistent storage is unavailable; bundled examples are read-only.', true);
      }
      status('Ready');
      if (requestRun === null) return;
      if (validPath(requestRun) || !isEntryFile(requestRun)) {
        log('Cannot run Lua entry: ' + requestRun, true);
        runUrl(null);
        return;
      }
      state.entry = requestRun;
      updateEntries();
      await run();
    };
  })();
}
