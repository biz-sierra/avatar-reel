// Render every gfx scene the timeline uses: seeked CSS animations, frame by frame -> gfx/out/<key>.mp4 (panel) / .mov (alpha).
// node build_gfx.mjs            -> all scenes      node build_gfx.mjs switch nap   -> just those keys
import { chromium } from "playwright"; import { execSync } from "node:child_process"; import { mkdirSync, rmSync } from "node:fs"; import { resolve } from "node:path";
import { segs } from "./timeline.mjs"; import { ACCENT } from "./reel.config.mjs";
const FPS = 30; const only = process.argv.slice(2); const jobs = [];
for (const s of segs()) {
  const { key, scene, ss, from, ...q } = s.opts;
  if (s.mode === "SPLIT" && !/^(lib|clip|broll):/.test(s.src)) {
    if (s.src === "replay") jobs.push({ name: "callback", q: { s: "callback", clear: 1 }, w: 1080, h: 640, dur: s.t1 - s.t0, alpha: true });
    else jobs.push({ name: key || s.src, q: { s: scene || s.src, ...q }, w: 1080, h: 640, dur: s.t1 - s.t0 });
  }
  if (s.opts.ui) jobs.push({ name: s.opts.ui, q: { s: s.opts.ui, clear: 1 }, w: 1080, h: 1920, dur: s.t1 - s.t0, alpha: true });
}
mkdirSync("gfx/out", { recursive: true });
const browser = await chromium.launch();
for (const j of jobs) {
  if (only.length && !only.includes(j.name)) continue;
  const dir = `gfx/frames_${j.name}`; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
  const page = await browser.newPage({ viewport: { width: j.w, height: j.h } });
  await page.goto("file://" + resolve("gfx/gfx.html") + "?" + new URLSearchParams({ ...j.q, accent: ACCENT }));
  await page.evaluate(() => document.fonts.ready); await page.waitForTimeout(400);
  const N = Math.ceil(j.dur * FPS);
  for (let f = 0; f < N; f++) { await page.evaluate(t => window.__seek(t), f / FPS); await page.screenshot({ path: `${dir}/${String(f).padStart(5, "0")}.png`, omitBackground: !!j.alpha }); }
  await page.close();
  const out = `gfx/out/${j.name}.${j.alpha ? "mov" : "mp4"}`;
  execSync(`ffmpeg -y -v error -framerate ${FPS} -i ${dir}/%05d.png ${j.alpha ? "-c:v qtrle -pix_fmt argb" : "-c:v libx264 -crf 16 -pix_fmt yuv420p"} ${out}`);
  rmSync(dir, { recursive: true }); console.log(out, N, "frames");
}
await browser.close();
