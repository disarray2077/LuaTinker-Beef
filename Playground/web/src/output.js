export function createOutput() {
  const limit = 1000;
  let snapshot = { messages: [], dropped: 0 };
  let pending = [];
  let timer = null;
  let count = 0;
  let nextId = 0;
  const listeners = new Set();
  const subscribe = (listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  };
  function publish(messages) {
    snapshot = { messages, dropped: count - messages.length };
    for (const listener of listeners) listener();
  }
  function flush() {
    clearTimeout(timer);
    timer = null;
    if (!pending.length) return;
    const messages = [...snapshot.messages, ...pending].slice(-limit);
    pending = [];
    publish(messages);
  }
  function append(text, failed) {
    count++;
    pending.push({ id: nextId++, text, failed });
    // Bound pending output even when a script keeps the event loop busy.
    if (pending.length >= limit * 2) pending = pending.slice(-limit);
    if (timer === null) {
      flush();
      timer = setTimeout(flush, 16);
    }
  }
  function clear() {
    clearTimeout(timer);
    timer = null;
    pending = [];
    count = 0;
    publish([]);
  }
  return { subscribe, getSnapshot: () => snapshot, append, flush, clear };
}
