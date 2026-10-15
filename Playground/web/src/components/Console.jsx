import { useLayoutEffect, useRef } from "react";

function Message({ message, workspace }) {
  const locations =
    /(^|[\s("'`])((?:\/workspace\/|\.{1,2}\/)[^\r\n:'"<>()[\]{}]+?|[^\s:'"<>()[\]{}]+):([1-9]\d*)(?=[:\s)\]]|$)/gm;
  const parts = [];
  let cursor = 0;
  for (const match of message.text.matchAll(locations)) {
    const path = workspace.resolveSourcePath(match[2]);
    const row = Number(match[3]);
    if (!path || !Number.isSafeInteger(row)) continue;
    const start = match.index + match[1].length;
    parts.push(message.text.slice(cursor, start));
    const label = `${match[2]}:${match[3]}`;
    parts.push(
      <a
        key={start}
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
    cursor = start + label.length;
  }
  parts.push(message.text.slice(cursor));
  return <div className={message.failed ? "error" : ""}>{parts}</div>;
}

export function Console({ messages, workspace }) {
  const output = useRef(null);
  useLayoutEffect(() => {
    output.current.scrollTop = output.current.scrollHeight;
  }, [messages]);
  return (
    <div
      ref={output}
      id="output"
      role="log"
      aria-live="polite"
      aria-label="Console output"
    >
      {messages.map((message, index) => (
        <Message key={index} message={message} workspace={workspace} />
      ))}
    </div>
  );
}
