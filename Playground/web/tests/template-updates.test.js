import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { findTemplateUpdates } from "../src/template-updates.js";

const record = (source) => ({
  path: "forms/main.lua",
  bytes: new TextEncoder().encode(source).buffer,
});
const original = "-- original example\nprint('hello')\n";
const approved = {
  "forms/main.lua": [createHash("sha256").update(original).digest("hex")],
};
const template = record("-- updated example\n");

test("Known bundled versions update with either line ending", async () => {
  for (const source of [original, original.replaceAll("\n", "\r\n")]) {
    const existing = new Map([[template.path, record(source)]]);
    assert.deepEqual(
      await findTemplateUpdates([template], existing, approved),
      [template],
    );
    existing.set(template.path, template);
    assert.deepEqual(
      await findTemplateUpdates([template], existing, approved),
      [],
    );
  }
});

test("Edited, deleted, and folder replacements are preserved", async () => {
  for (const records of [
    [record(original + "-- user edit\n")],
    [],
    [{ path: template.path, folder: true }],
  ]) {
    const existing = new Map(records.map((entry) => [entry.path, entry]));
    assert.deepEqual(
      await findTemplateUpdates([template], existing, approved),
      [],
    );
  }
});

test("Templates without an approved predecessor never replace saved files", async () => {
  const existing = new Map([[template.path, record(original)]]);
  assert.deepEqual(await findTemplateUpdates([template], existing, {}), []);
});
