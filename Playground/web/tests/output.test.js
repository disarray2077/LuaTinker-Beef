import assert from "node:assert/strict";
import { test } from "node:test";
import { createOutput } from "../src/output.js";

test("Sparse output is published immediately", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const output = createOutput();
  output.append("first", false);
  assert.equal(output.getSnapshot().messages.at(-1).text, "first");
  t.mock.timers.tick(16);
  output.append("second", false);
  assert.equal(output.getSnapshot().messages.at(-1).text, "second");
});

test("Frequent output is published in batches and retains the latest messages", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const output = createOutput();
  let updates = 0;
  output.subscribe(() => updates++);
  for (let i = 0; i < 10000; i++) output.append(String(i), false);
  assert.equal(updates, 1);
  t.mock.timers.tick(16);
  assert.equal(updates, 2);
  const { messages, dropped } = output.getSnapshot();
  assert.equal(messages.length, 1000);
  assert.equal(messages[0].text, "9000");
  assert.equal(messages.at(-1).text, "9999");
  assert.equal(dropped, 9000);
});

test("Clearing output discards pending messages from the previous run", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const output = createOutput();
  output.append("old run", false);
  output.append("queued old output", false);
  output.clear();
  output.append("new run", true);
  t.mock.timers.tick(16);
  assert.equal(output.getSnapshot().dropped, 0);
  assert.deepEqual(
    output.getSnapshot().messages.map(({ text, failed }) => ({ text, failed })),
    [{ text: "new run", failed: true }],
  );
});

test("Editor error subscriptions ignore ordinary output updates", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const output = createOutput();
  const empty = output.getErrors();
  output.append("ordinary output", false);
  assert.equal(output.getErrors(), empty);

  output.append("/workspace/main.lua:2: failure", true);
  output.flush();
  const errors = output.getErrors();
  assert.equal(errors.length, 1);
  assert.equal(errors[0].text, "/workspace/main.lua:2: failure");

  output.append("more output", false);
  output.flush();
  assert.equal(output.getErrors(), errors);
  output.clear();
  assert.equal(output.getErrors().length, 0);
});
