// Shared helpers: phrase anchors on audio/words.json + segment builder. Don't edit per reel; edit timeline.mjs.
import { readFileSync, existsSync } from "node:fs";
const WP = new URL("./audio/words.json", import.meta.url);
export const WORDS = existsSync(WP) ? JSON.parse(readFileSync(WP, "utf8")) : [];
const norm = t => t.toLowerCase().replace(/[^a-z0-9']/g, "");
const find = (phrase, from) => {
  const seq = phrase.split(/\s+/).map(norm);
  for (let i = from; i < WORDS.length; i++) if (seq.every((s, j) => norm(WORDS[i + j]?.text || "") === s)) return i;
  return -1;
};
let cursor = 0;
// at("one setting") -> start time of the next occurrence of that phrase (cursor moves forward, so repeats resolve in order)
export function at(phrase, off = -0.05) {
  const i = find(phrase, cursor);
  if (i < 0) throw new Error(`anchor not found (after word ${cursor}): "${phrase}"`);
  cursor = i + 1; return Math.max(0, +(WORDS[i].start + off).toFixed(2));
}
// build(): opts values written "@phrase" become seconds relative to that segment's start
export function build(rows, tail = 0.5) {
  const END = +(WORDS.at(-1).end + tail).toFixed(2);
  const segs = () => rows.map((r, i) => {
    const t0 = r[0], t1 = i + 1 < rows.length ? rows[i + 1][0] : END, opts = { ...(r[3] || {}) };
    for (const [k, v] of Object.entries(opts)) if (typeof v === "string" && v.startsWith("@")) {
      const from = WORDS.findIndex(w => w.start >= t0 - 0.02); const j = find(v.slice(1), Math.max(0, from));
      if (j < 0) throw new Error(`relative anchor not found: ${v}`); opts[k] = +(WORDS[j].start - t0).toFixed(2);
    }
    if (t1 <= t0) throw new Error(`segment ${i} has no length (${t0} -> ${t1})`);
    return { t0, t1, mode: r[1], src: r[2] ?? null, opts };
  });
  return { segs, END };
}
