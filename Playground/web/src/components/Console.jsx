import { memo, useLayoutEffect, useRef, useSyncExternalStore } from "react";
import { sourceLocations } from "../source-locations.js";

const Message = memo(function Message({ message, workspace }) {
  const locations = sourceLocations(message.text, workspace.resolveSourcePath);
  const parts = [];
  let cursor = 0;
  for (const { path, row, from, to, label } of locations) {
    parts.push(message.text.slice(cursor, from));
    parts.push(
      <a
        key={from}
        href="#editor"
        title={`Open ${path} at line ${row}`}
        onClick={(event) => {
          event.preventDefault();
          workspace.perform(() => workspace.openSourceLocation(path, row));
        }}
      >
        {label}
      </a>,
    );
    cursor = to;
  }
  parts.push(message.text.slice(cursor));
  return <div className={message.failed ? "error" : ""}>{parts}</div>;
});

export const Console = memo(function Console({ output, workspace }) {
  const { messages, dropped } = useSyncExternalStore(
    output.subscribe,
    output.getSnapshot,
  );
  const container = useRef(null);
  useLayoutEffect(() => {
    container.current.scrollTop = container.current.scrollHeight;
  }, [messages]);
  return (
    <div
      ref={container}
      id="output"
      role="log"
      aria-live="polite"
      aria-label="Console output"
    >
      {dropped > 0 && <div>{dropped} earlier messages omitted.</div>}
      {messages.map((message) => (
        <Message key={message.id} message={message} workspace={workspace} />
      ))}
    </div>
  );
});
