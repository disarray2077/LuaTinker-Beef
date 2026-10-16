import assert from "node:assert/strict";
import { test } from "node:test";
import {
  primaryErrorLocation,
  sourceLocations,
} from "../src/source-locations.js";

const resolvePath = (path) =>
  path.startsWith("/workspace/") ? path.slice("/workspace/".length) : null;
const trace = [
  "/workspace/sdl_render.lua:15: attempt to call a nil value (field 'Cr1eateWindow')",
  "stack traceback:",
  "\t/workspace/sdl_render.lua:15: in function </workspace/sdl_render.lua:14>",
  "\t[C]: in function 'xpcall'",
  "\t/workspace/sdl_render.lua:66: in main chunk",
];

for (const [name, messages] of [
  ["separate output lines", trace],
  ["one output message", [trace.join("\n")]],
]) {
  test(`Only the primary error becomes a diagnostic with ${name}`, () => {
    const errors = messages.map((text) => ({ text, failed: true }));
    const error = primaryErrorLocation(errors, resolvePath);
    assert.equal(error.path, "sdl_render.lua");
    assert.equal(error.row, 15);
    assert.equal(
      error.message,
      "attempt to call a nil value (field 'Cr1eateWindow')",
    );
    // Traceback frames still provide navigation links, including other files.
    errors.push({
      text: "\t/workspace/main.lua:8: in main chunk",
      failed: true,
    });
    assert.equal(
      primaryErrorLocation(errors, resolvePath).path,
      "sdl_render.lua",
    );
    assert.equal(
      sourceLocations(errors.at(-1).text, resolvePath)[0].path,
      "main.lua",
    );
  });
}
