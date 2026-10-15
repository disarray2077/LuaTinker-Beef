const decoder = new TextDecoder("utf-8", { fatal: true });
export const names = [
  "sdl_render.lua",
  "gl_render.lua",
  "rope/main.lua",
  "breakout/main.lua",
];
export const isFolder = (record) => record?.folder === true;
export const bytesOf = (record) => new Uint8Array(record.bytes);
export const comparePaths = (a, b) =>
  a.toLowerCase().localeCompare(b.toLowerCase()) || a.localeCompare(b);

export function hasTopLevelReturn(source) {
  // Skip Lua comments and strings before tracking block boundaries.
  const tokens =
    /--(?:\[(=*)\[[\s\S]*?\]\1\]|[^\r\n]*)|\[(=*)\[[\s\S]*?\]\2\]|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*/g;
  let depth = 0;
  for (const [token] of source.matchAll(tokens)) {
    if (["function", "if", "do", "repeat"].includes(token)) depth++;
    else if (token === "end" || token === "until")
      depth = Math.max(0, depth - 1);
    else if (token === "return" && depth === 0) return true;
  }
  return false;
}

export function validPath(path) {
  if (
    !path ||
    path.startsWith("/") ||
    path.endsWith("/") ||
    path
      .split("/")
      .some(
        (part) => !part || part === "." || part === ".." || part.includes("\\"),
      )
  ) {
    return "Use a relative path without empty, . or .. components.";
  }
  return null;
}
export function parentPaths(path) {
  const parents = [];
  for (
    let slash = path.indexOf("/");
    slash !== -1;
    slash = path.indexOf("/", slash + 1)
  )
    parents.push(path.slice(0, slash));
  return parents;
}

export function textOf(record) {
  if (!record || isFolder(record)) return null;
  try {
    const bytes = bytesOf(record);
    const text = decoder.decode(bytes);
    return text.includes("\0") ? null : text;
  } catch {
    return null;
  }
}

export function normalizeSourcePath(path) {
  const parts = [];
  for (const part of path.split("/")) {
    if (!part || part === ".") continue;
    if (part === "..") {
      if (!parts.length) return null;
      parts.pop();
    } else parts.push(part);
  }
  return parts.join("/");
}
