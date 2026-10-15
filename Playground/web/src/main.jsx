import { createRoot } from "react-dom/client";
import { App } from "./App.jsx";
import { createRuntime } from "./runtime.js";
import { createWorkspace } from "./workspace.js";
import "./styles.css";

const runtime = createRuntime();
const workspace = createWorkspace(runtime);
window.addEventListener("error", (event) =>
  runtime.log(event.error?.stack || event.message, true),
);
window.addEventListener("unhandledrejection", (event) =>
  runtime.log(event.reason?.stack || event.reason, true),
);
createRoot(document.getElementById("app")).render(
  <App runtime={runtime} workspace={workspace} />,
);
