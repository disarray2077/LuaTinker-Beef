import assert from "node:assert/strict";
import { test } from "node:test";
import { createRuntime } from "../src/runtime.js";

async function setup(t, finishesImmediately = false) {
  const calls = [];
  const window = {};
  const document = {
    querySelector: () => ({ content: "test" }),
    createElement: () => ({ focus() {} }),
    body: {
      append() {
        Object.assign(window.Module, {
          callMain() {},
          FS: { chdir() {}, mkdirTree() {}, readdir: () => [] },
          ccall(name) {
            calls.push(name);
            if (name === "PlaygroundStart" && finishesImmediately)
              window.Module.onPlaygroundStopped();
            return 0;
          },
        });
        window.Module.onRuntimeInitialized();
      },
    },
  };
  for (const [name, value] of Object.entries({
    window,
    document,
    location: { href: "https://example.test/playground/" },
    history: { replaceState() {} },
  })) {
    const previous = Object.getOwnPropertyDescriptor(globalThis, name);
    Object.defineProperty(globalThis, name, {
      configurable: true,
      writable: true,
      value,
    });
    t.after(() => {
      if (previous) Object.defineProperty(globalThis, name, previous);
      else delete globalThis[name];
    });
  }
  const runtime = createRuntime();
  await runtime.initialize({ replaceChildren() {} });
  return { runtime, calls, module: window.Module };
}

test("Stop cancels a run waiting for workspace saves", async (t) => {
  const { runtime, calls } = await setup(t);
  let saved;
  let started = false;
  const saving = new Promise((resolve) => {
    saved = resolve;
  });
  const running = runtime.run(
    () => saving,
    () => {
      started = true;
    },
  );
  runtime.stop();
  saved({ entry: "main.lua", files: new Map() });
  await running;
  assert.equal(calls.includes("PlaygroundStart"), false);
  assert.equal(started, false);
  assert.equal(runtime.getSnapshot().status, "Stopped");
});

test("A script finishing during Start remains finished", async (t) => {
  const { runtime } = await setup(t, true);
  await runtime.run(async () => ({ entry: "main.lua", files: new Map() }));
  assert.equal(runtime.getSnapshot().phase, "idle");
  assert.equal(runtime.getSnapshot().status, "Finished");
});

test("A normal Stop clears the failed status while retaining the error output", async (t) => {
  const { runtime } = await setup(t);
  runtime.log("script error", true);
  runtime.stop();
  assert.equal(runtime.getSnapshot().status, "Stopped");
  assert.equal(runtime.getSnapshot().failed, false);
  assert.equal(runtime.output.getSnapshot().messages[0].text, "script error");
});

test("Canvas focus releases held game keys without affecting a stopped runtime", async (t) => {
  const { runtime, calls, module } = await setup(t);
  await runtime.run(async () => ({ entry: "main.lua", files: new Map() }));
  const canvas = module.canvas;
  const focus = t.mock.method(canvas, "focus");
  canvas.onpointerdown();
  assert.equal(focus.mock.callCount(), 1);

  canvas.onblur();
  assert.equal(calls.at(-1), "PlaygroundReleaseKeys");
  runtime.stop();
  const stoppedCalls = calls.length;
  canvas.onblur();
  assert.equal(calls.length, stoppedCalls);
});
