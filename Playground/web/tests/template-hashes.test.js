import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const sample = "Playground/dist/forms/main.lua";
const manifest = "Playground/web/src/template-update-hashes.json";
const script = fileURLToPath(
  new URL("../update-template-hashes.mjs", import.meta.url),
);
const original = "print('old')\n";
const hashOf = (source) =>
  createHash("sha256").update(source.replaceAll("\r\n", "\n")).digest("hex");

function setup(t, { commit = true, source = original } = {}) {
  const directory = mkdtempSync(
    path.join(tmpdir(), "luatinker-template-test-"),
  );
  assert.equal(path.dirname(directory), path.resolve(tmpdir()));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const options = {
    cwd: directory,
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  };
  const git = (...args) => execFileSync("git", args, options);
  const update = (...args) =>
    execFileSync(process.execPath, [script, ...args], options);
  const write = (name, content) => {
    const destination = path.join(directory, name);
    mkdirSync(path.dirname(destination), { recursive: true });
    writeFileSync(destination, content);
  };
  const read = (name) => readFileSync(path.join(directory, name), "utf8");
  git("init", "-q");
  git("config", "user.name", "Template test");
  git("config", "user.email", "templates@example.invalid");
  git("config", "core.autocrlf", "false");
  // Keep developer-installed global hooks out of these disposable test repositories.
  mkdirSync(path.join(directory, "empty-hooks"));
  git("config", "core.hooksPath", "empty-hooks");
  write(sample, source);
  write(manifest, "{}\n");
  git("add", ".");
  if (commit) git("commit", "-qm", "Initial");
  return { git, update, write, read };
}

test("Updater reads HEAD and the index without staging or including working-tree samples", (t) => {
  const { git, update, write, read } = setup(t);
  write(sample, "print('staged')\n");
  git("add", sample);
  write(sample, "print('unstaged')\n");
  update();
  assert.deepEqual(JSON.parse(read(manifest)), {
    "forms/main.lua": [hashOf(original)],
  });
  assert.equal(git("show", `:${manifest}`), "{}\n");
  assert.equal(git("show", `:${sample}`), "print('staged')\n");
  assert.equal(read(sample), "print('unstaged')\n");
});

test("Updater preserves edits to the hash list and does not duplicate entries", (t) => {
  const { git, update, write, read } = setup(t);
  write(sample, "print('new')\n");
  git("add", sample);
  write(manifest, '{"other.lua":[]}\n');
  update();
  const expected = { "other.lua": [], "forms/main.lua": [hashOf(original)] };
  assert.deepEqual(JSON.parse(read(manifest)), expected);
  update();
  assert.deepEqual(JSON.parse(read(manifest)), expected);
});

test("A new repository has no predecessor to approve", (t) => {
  const { update, read } = setup(t, { commit: false });
  update();
  assert.deepEqual(JSON.parse(read(manifest)), {});
});

test("HEAD line endings are normalized before hashing", (t) => {
  const { git, update, write, read } = setup(t, {
    source: original.replaceAll("\n", "\r\n"),
  });
  write(sample, "print('new')\n");
  git("add", sample);
  update();
  assert.deepEqual(JSON.parse(read(manifest)), {
    "forms/main.lua": [hashOf(original)],
  });
});

test("Working-tree-only edits do not require hashes", (t) => {
  const { update, write, read } = setup(t);
  write(sample, "print('not staged')\n");
  update();
  assert.deepEqual(JSON.parse(read(manifest)), {});
});

test("CI checks committed hashes across the pushed range and never writes files", (t) => {
  const { git, update, write, read } = setup(t);
  const base = git("rev-parse", "HEAD").trim();
  for (const version of ["first", "second"]) {
    write(sample, `print('${version}')\n`);
    git("add", sample);
    git("commit", "-qm", version);
  }
  const status = git("status", "--porcelain");
  assert.throws(
    () => update("--check", "--base", base),
    /Missing predecessor hashes/,
  );
  assert.equal(read(manifest), "{}\n");
  assert.equal(git("status", "--porcelain"), status);
  update("--base", base);
  assert.throws(
    () => update("--check", "--base", base),
    /Missing predecessor hashes/,
  );
  git("add", manifest);
  git("commit", "-qm", "Record predecessor");
  update("--check", "--base", base);
  assert.deepEqual(JSON.parse(read(manifest)), {
    "forms/main.lua": [hashOf(original)],
  });
});

test("Local checks inspect the latest commit, including from a subdirectory", (t) => {
  const { git, update, write } = setup(t);
  update("--check");
  write(sample, "print('new')\n");
  git("add", sample);
  update();
  git("add", manifest);
  git("commit", "-qm", "Updated example");
  // npm runs the command inside Playground/web, rather than at the repository root.
  const root = git("rev-parse", "--show-toplevel").trim();
  execFileSync(process.execPath, [script, "--check"], {
    cwd: path.join(root, "Playground/web"),
  });
});
