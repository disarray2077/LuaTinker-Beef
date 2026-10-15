import { useLayoutEffect, useRef, useState } from "react";

export function WorkspaceDialog({ request }) {
  const box = useRef(null);
  const field = useRef(null);
  const [error, setError] = useState("");
  useLayoutEffect(() => {
    box.current.showModal();
    if (request.path !== undefined && request.path !== null)
      field.current.focus();
    const dialog = box.current;
    return () => dialog.close();
  }, [request]);
  const hasPath = request.path !== undefined && request.path !== null;
  function submit(event) {
    event.preventDefault();
    const value = hasPath ? field.current.value.replaceAll("\\", "/") : true;
    const error = request.validate?.(value);
    if (error) {
      setError(error);
      field.current.focus();
      return;
    }
    request.finish(value);
  }
  return (
    <dialog
      ref={box}
      aria-labelledby="dialog-title"
      onCancel={(event) => {
        event.preventDefault();
        request.finish(null);
      }}
    >
      <form method="dialog" onSubmit={submit}>
        <h2 id="dialog-title">{request.title}</h2>
        <p>{request.message || ""}</p>
        <input
          ref={field}
          hidden={!hasPath}
          defaultValue={request.path || ""}
          aria-label="File path"
          autoComplete="off"
        />
        <p id="dialog-error" className="error" role="alert">
          {error}
        </p>
        <div className="dialog-actions">
          <button type="button" onClick={() => request.finish(null)}>
            Cancel
          </button>
          <button type="submit" className="primary">
            {request.confirm || "Confirm"}
          </button>
        </div>
      </form>
    </dialog>
  );
}
