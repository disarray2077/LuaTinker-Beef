import { useEffect, useRef } from "react";
import { Console } from "./Console.jsx";
import { validPath } from "../files.js";

export function Preview({ runtime, workspace, pane, messages }) {
  const host = useRef(null);
  useEffect(() => {
    let mounted = true;
    async function initialize() {
      await runtime.initialize(host.current);
      await workspace.initialize();
      if (!mounted) return;
      runtime.setStatus("Ready");
      const entry = new URLSearchParams(location.search).get("run");
      if (entry === null) return;
      if (validPath(entry) || !workspace.isEntryFile(entry)) {
        runtime.log("Cannot run Lua entry: " + entry, true);
        const url = new URL(location.href);
        url.searchParams.delete("run");
        history.replaceState(null, "", url.href);
        return;
      }
      await workspace.selectEntry(entry);
      await workspace.run();
    }
    initialize().catch((error) => runtime.log(error.stack || error, true));
    return () => {
      mounted = false;
    };
  }, [runtime, workspace]);
  return (
    <section
      id="preview-panel"
      className={`pane ${pane === "preview" ? "active" : ""}`}
      role="tabpanel"
      aria-label="Run preview"
    >
      <div className="pane-header">
        <h2>Preview</h2>
      </div>
      <div ref={host} className="canvas-wrap" />
      <Console messages={messages} workspace={workspace} />
    </section>
  );
}
