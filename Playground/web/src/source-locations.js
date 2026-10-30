export function sourceLocations(text, resolvePath) {
  const pattern =
    /(^|[\s("'`])((?:\/workspace\/|\.{1,2}\/)[^\r\n:'"<>()[\]{}]+?|[^\s:'"<>()[\]{}]+):([1-9]\d*)(?=[:\s)\]]|$)/gm;
  const locations = [];
  for (const match of text.matchAll(pattern)) {
    const path = resolvePath(match[2]);
    const row = Number(match[3]);
    if (!path || !Number.isSafeInteger(row)) continue;
    const from = match.index + match[1].length;
    const label = `${match[2]}:${match[3]}`;
    locations.push({ path, row, from, to: from + label.length, label });
  }
  return locations;
}

export function primaryErrorLocation(errors, resolvePath) {
  for (const error of errors) {
    const source = sourceLocations(error.text, resolvePath)[0];
    if (!source) continue;
    const message =
      error.text
        .slice(source.to)
        .split("\n")[0]
        .replace(/^[:\s]+/, "") || error.text;
    return { ...source, message };
  }
  return null;
}
