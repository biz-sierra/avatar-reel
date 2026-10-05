// Talking head: avatar still + audio/vo.mp3 -> HeyGen image->video (9:16 1080p) -> head_raw.mp4. ~3 API credits per second.
import { readFileSync, writeFileSync, existsSync } from "node:fs"; import { execSync } from "node:child_process";
import { AVATAR_STILL, EXPRESSIVENESS, apiKey } from "./reel.config.mjs";
const key = apiKey("heygen");
const H = { "X-Api-Key": key };
try { const q = await (await fetch("https://api.heygen.com/v2/user/remaining_quota", { headers: H })).json(); console.log("HeyGen API credits left:", q.data?.details?.api ?? q.data?.remaining_quota ?? "(unknown)"); } catch { console.log("(credit check failed; carrying on)"); }
let id = existsSync("heygen_video_id.txt") && process.argv[2] !== "--new" ? readFileSync("heygen_video_id.txt", "utf8").trim() : null;
if (!id) {
  const up = async (p, t) => { const r = await fetch("https://upload.heygen.com/v1/asset", { method: "POST", headers: { ...H, "Content-Type": t }, body: readFileSync(p) }); const j = await r.json(); if (!j.data) throw new Error(JSON.stringify(j).slice(0, 300)); return j.data; };
  const img = await up(AVATAR_STILL, /\.jpe?g$/i.test(AVATAR_STILL) ? "image/jpeg" : "image/png"), aud = await up("audio/vo.mp3", "audio/mpeg");
  const r = await fetch("https://api.heygen.com/v3/videos", { method: "POST", headers: { ...H, "Content-Type": "application/json" }, body: JSON.stringify({
    type: "image", image: { type: "url", url: img.url }, audio_asset_id: aud.id, aspect_ratio: "9:16", resolution: "1080p", expressiveness: EXPRESSIVENESS, fit: "cover",
    motion_prompt: "The speaker looks directly into the camera lens at eye level the entire time, talking straight to the viewer with confident, direct energy. Natural, frequent blinks and small eyebrow movements from the very first word, like a person thinking while they talk. Natural expressive mouth movement, subtle head motion. Hands rest below frame; no hand to the face, no glancing away or down." }) });
  const j = await r.json(); id = j.data?.video_id; if (!id) { console.error(JSON.stringify(j).slice(0, 400)); process.exit(1); }
  writeFileSync("heygen_video_id.txt", id); console.log("submitted", id);
}
for (let i = 0; i < 90; i++) {
  const d = (await (await fetch(`https://api.heygen.com/v1/video_status.get?video_id=${id}`, { headers: H })).json()).data;
  if (d.status === "completed") { execSync(`curl -sL "${d.video_url}" -o head_raw.mp4`); console.log("head_raw.mp4", execSync("ffprobe -v error -show_entries format=duration -of csv=p=0 head_raw.mp4").toString().trim(), "s"); process.exit(0); }
  if (d.status === "failed") { console.error(JSON.stringify(d).slice(0, 500)); process.exit(1); }
  console.log(new Date().toTimeString().slice(0, 8), d.status); await new Promise(r => setTimeout(r, 20000));
}
console.error("timed out — re-run `node heygen.mjs` to keep polling the same video id"); process.exit(1);
