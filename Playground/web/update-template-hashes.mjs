import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const manifest = "Playground/web/src/template-update-hashes.json";
const prefix = "Playground/dist/";
const decoder = new TextDecoder("utf-8", { fatal: true });
let root;
const git = (...args) =>
  execFileSync("git", args, { cwd: root, stdio: ["pipe", "pipe", "pipe"] });

function sourceOf(bytes) {
  try {
    const source = decoder.decode(bytes);
    return source.includes("\0") ? null : source.replaceAll("\r\n", "\n");
  } catch {
    return null;
  }
}

function updateHashes() {
  let check = false,
    base;
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--check") check = true;
    else if (args[i] === "--base" && args[i + 1]) base = args[++i];
    else throw new Error(`Unknown or incomplete argument: ${args[i]}`);
  }
  root = git("rev-parse", "--show-toplevel").toString().trim();
  const head = spawnSync("git", ["rev-parse", "--verify", "--quiet", "HEAD"], {
    cwd: root,
  });
  if (head.status === 1) return;
  if (head.status !== 0) throw new Error("Cannot resolve HEAD.");
  if (
    !base &&
    check &&
    git("rev-list", "--parents", "-n", "1", "HEAD").toString().trim().split(" ")
      .length === 1
  )
    return;
  base ||= check ? "HEAD^" : "HEAD";
  const comparison = check ? [base, "HEAD"] : ["--cached", base];
  const changed = git(
    "diff",
    ...comparison,
    "--no-renames",
    "--name-only",
    "--diff-filter=M",
    "-z",
    "--",
    prefix,
  )
    .toString()
    .split("\0")
    .filter(Boolean);
  const predecessors = [];
  for (const file of changed) {
    const previous = sourceOf(git("show", `${base}:${file}`));
    const current = sourceOf(git("show", check ? `HEAD:${file}` : `:${file}`));
    if (previous === null || current === null || previous === current) continue;
    predecessors.push([
      file.slice(prefix.length),
      createHash("sha256").update(previous).digest("hex"),
    ]);
  }
  if (!predecessors.length) return;

  const destination = path.join(root, manifest);
  const committed = check
    ? spawnSync("git", ["show", `HEAD:${manifest}`], { cwd: root })
    : null;
  const source = check
    ? committed.status === 0
      ? committed.stdout.toString()
      : "{}"
    : existsSync(destination)
      ? readFileSync(destination, "utf8")
      : "{}";
  const hashes = JSON.parse(source);
  const missing = predecessors.filter(
    ([file, hash]) => !hashes[file]?.includes(hash),
  );
  if (check && missing.length) {
    throw new Error(
      `Missing predecessor hashes for ${missing.map(([file]) => file).join(", ")}. Run npm --prefix Playground/web run templates:update -- --base ${base}, then stage ${manifest} and commit it.`,
    );
  }
  if (!missing.length) return;
  for (const [file, hash] of missing) (hashes[file] ||= []).push(hash);
  mkdirSync(path.dirname(destination), { recursive: true });
  writeFileSync(destination, JSON.stringify(hashes, null, 2) + "\n");
  console.log(
    `Updated ${manifest} from ${base}. Stage this file with your example changes.`,
  );
}

try {
  updateHashes();
} catch (error) {
  console.error(`Template hashes: ${error.message}`);
  process.exitCode = 1;
}
