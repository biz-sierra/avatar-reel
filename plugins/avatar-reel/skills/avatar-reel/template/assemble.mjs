// Cut the reel: per-segment renders (FULL / SPLIT / CUT) -> concat -> karaoke captions -> VO (-14 LUFS target) -> out/<slug>-<ver>.mp4 + out/qc-sheet.png
// node assemble.mjs [v2]
import { execSync } from "node:child_process"; import { writeFileSync, mkdirSync, rmSync } from "node:fs";
import { segs, END } from "./timeline.mjs"; import { SLUG, LIB, BROLL, ACCENT, FACE_TOP } from "./reel.config.mjs";
const sh = c => execSync(c, { stdio: ["ignore", "pipe", "pipe"] }).toString();
const VER = process.argv[2] || "v1", FPS = 30, HEAD = "head_raw.mp4", OUT = `out/${SLUG}-${VER}.mp4`;
const clipPath = src => { const [k, n] = src.split(":"); return k === "lib" ? `"${LIB}/broll/${n}.mp4"` : k === "broll" ? `"${BROLL}/${n}.mp4"` : `clips/${n}.mp4`; };
mkdirSync("segs", { recursive: true }); mkdirSync("out", { recursive: true });
const list = [];
segs().forEach((s, i) => {
  const N = Math.round(s.t1 * FPS) - Math.round(s.t0 * FPS), d = (N / FPS + 0.5).toFixed(3);
  const out = `segs/s${String(i).padStart(2, "0")}.mp4`;
  const headIn = `-ss ${s.t0.toFixed(3)} -t ${d} -i ${HEAD}`;
  const norm = "fps=30,setsar=1,tpad=stop_mode=clone:stop_duration=2";
  let inputs, fc;
  if (s.mode === "CUT") { // full-frame b-roll (9:16 crop)
    inputs = `-ss ${s.opts.ss ?? 0} -i ${clipPath(s.src)}`; fc = `[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,${norm}[v]`;
  } else if (s.mode === "FULL") { // face fills the frame
    inputs = headIn; let f = `[0:v]scale=1080:1920,${norm}`;
    if (s.opts.zoom) { const z = s.opts.zoom, W = Math.round(1080 * z / 2) * 2, H = Math.round(1920 * z / 2) * 2; f += `,scale=${W}:${H},crop=1080:1920:${(W - 1080) / 2}:${FACE_TOP}`; }
    if (s.opts.grey) f += ",hue=s=0,eq=contrast=1.12:brightness=-0.03";
    if (s.opts.ui) { inputs += ` -i gfx/out/${s.opts.ui}.mov`; fc = `${f}[b];[1:v]fps=30[u];[b][u]overlay=0:0[v]`; } else fc = `${f}[v]`;
  } else { // SPLIT: panel 0-640 on top, head (source y FACE_TOP..FACE_TOP+1280) below, accent rule between
    inputs = headIn;
    const head = `[0:v]scale=1080:1920,${norm},crop=1080:1280:0:${FACE_TOP},pad=1080:1920:0:640:black[h]`;
    let panel;
    if (/^(lib|clip|broll):/.test(s.src)) { inputs += ` -ss ${s.opts.ss ?? 0} -i ${clipPath(s.src)}`; panel = `[1:v]scale=1138:640:force_original_aspect_ratio=increase,crop=1080:640,${norm}[p]`; }
    else if (s.src === "replay") { // greyscale replay of an earlier head moment + "remember this guy?" pill
      inputs += ` -ss ${s.opts.from ?? 0} -t ${d} -i ${HEAD} -i gfx/out/callback.mov`;
      panel = `[1:v]scale=1080:1920,${norm},crop=1080:640:0:${FACE_TOP + 170},hue=s=0,eq=contrast=1.12[pg];[2:v]fps=30[cb];[pg][cb]overlay=0:0[p]`;
    } else { inputs += ` -i gfx/out/${s.opts.key || s.src}.mp4`; panel = `[1:v]${norm}[p]`; }
    fc = `${head};${panel};[h][p]overlay=0:0,drawbox=x=0:y=634:w=1080:h=6:color=0x${ACCENT.replace("#", "")}:t=fill[v]`;
  }
  sh(`ffmpeg -y -v error ${inputs} -filter_complex "${fc}" -map "[v]" -frames:v ${N} -an -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -r 30 ${out}`);
  list.push(`file '${out.replace("segs/", "")}'`); process.stdout.write(`${i}:${s.mode}/${s.src || ""} `);
});
writeFileSync("segs/concat.txt", list.join("\n") + "\n");
sh(`cd segs && ffmpeg -y -v error -f concat -safe 0 -i concat.txt -c copy ../out/body_nocap.mp4`);
sh(`python3 captions.py`);
sh(`ffmpeg -y -v error -i out/body_nocap.mp4 -i out/caption_track.mov -i audio/vo.wav -filter_complex "[0:v][1:v]overlay=0:0:eof_action=pass[v];[2:a]aresample=48000,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000,apad[a]" -map "[v]" -map "[a]" -t ${END} -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart ${OUT}`);
rmSync("out/body_nocap.mp4");
// QC: 24-frame contact sheet + loudness
rmSync("out/qc", { recursive: true, force: true }); mkdirSync("out/qc");
for (let k = 0; k < 24; k++) sh(`ffmpeg -y -v error -ss ${(0.4 + k * (END - 0.8) / 23).toFixed(2)} -i ${OUT} -frames:v 1 -vf scale=270:-1 out/qc/${String(k).padStart(2, "0")}.png`);
sh(`ffmpeg -y -v error -pattern_type glob -i 'out/qc/*.png' -filter_complex tile=12x2 -frames:v 1 out/qc-sheet.png`); rmSync("out/qc", { recursive: true });
const lufs = execSync(`ffmpeg -v info -i ${OUT} -af ebur128 -f null - 2>&1 | grep -A1 "Integrated loudness" | tail -1`, { shell: "/bin/bash" }).toString().trim();
console.log(`\n${OUT}  ${sh(`ffprobe -v error -show_entries format=duration -of csv=p=0 ${OUT}`).trim()}s  ${lufs}  -> QC: out/qc-sheet.png`);
