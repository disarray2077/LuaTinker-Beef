import { textOf } from "./files.js";
import safeTemplateUpdates from "./template-update-hashes.json" with { type: "json" };

export async function findTemplateUpdates(
  templates,
  existing,
  approvedHashes = safeTemplateUpdates,
) {
  const updates = [];
  for (const template of templates) {
    const hashes = approvedHashes[template.path];
    if (!hashes?.length) continue;
    const source = textOf(existing.get(template.path));
    if (source === null) continue;
    const bytes = new TextEncoder().encode(source.replaceAll("\r\n", "\n"));
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
    const hash = Array.from(digest, (byte) =>
      byte.toString(16).padStart(2, "0"),
    ).join("");
    if (hashes.includes(hash)) updates.push(template);
  }
  return updates;
}
