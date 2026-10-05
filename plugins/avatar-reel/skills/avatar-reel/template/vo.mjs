// VO in your ElevenLabs voice clone from audio/script.txt -> audio/vo.wav + audio/words.json
// Wrap any stretch in [[flat]] ... [[/flat]] for a monotone "bad example" read.
// Pauses: squeezed on the REAL silence (ffmpeg silencedetect), not ElevenLabs' alignment gaps, which under-report
// silence by ~0.2s (an early render kept 0.45s holes that way). Left behind: 0.22s after . ? !, 0.14s after a comma,
// 0.10s mid-phrase. That's the standard cadence: continuous, no dead air. Flat parts are left alone.
import { readFileSync, writeFileSync } from "node:fs"; import { execSync } from "node:child_process";
import { VOICE, SPEED, apiKey } from "./reel.config.mjs";
const sh = c => execSync(c, { stdio: ["ignore", "pipe", "pipe"] }).toString();
const key = apiKey("elevenlabs");
const src = readFileSync("audio/script.txt", "utf8").trim();
const parts = []; src.split(/(\[\[flat\]\][\s\S]*?\[\[\/flat\]\])/).forEach(p => {
  const flat = p.startsWith("[[flat]]"); const text = p.replace(/\[\[\/?flat\]\]/g, "").trim();
  if (text) parts.push({ text, flat });
});
async function tts(text, flat) {
  const vs = flat ? { stability: 0.95, style: 0, speed: 1.0 } : { stability: 0.4, style: 0.5, speed: SPEED };
  const r = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE}/with-timestamps`, { method: "POST", headers: { "xi-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({ text, model_id: "eleven_multilingual_v2", voice_settings: { ...vs, similarity_boost: 0.8, use_speaker_boost: true } }) });
  if (!r.ok) throw new Error(r.status + " " + (await r.text()).slice(0, 300));
  const j = await r.json(); const { characters: c, character_start_times_seconds: s, character_end_times_seconds: e } = j.alignment;
  const words = []; let w = null;
  for (let i = 0; i < c.length; i++) { if (/\s/.test(c[i])) { if (w) { words.push(w); w = null; } continue; } if (!w) w = { text: "", start: s[i], end: e[i] }; w.text += c[i]; w.end = e[i]; }
  if (w) words.push(w);
  return { audio: Buffer.from(j.audio_base64, "base64"), words, dur: e.at(-1) };
}
const GAP = 0.3; let off = 0; const all = []; const list = [];
for (const [n, p] of parts.entries()) {
  const { audio, words, dur } = await tts(p.text, p.flat); writeFileSync(`audio/p${n}_raw.mp3`, audio);
  const cuts = [];
  if (!p.flat) {
    const log = sh(`ffmpeg -i audio/p${n}_raw.mp3 -af silencedetect=noise=-35dB:d=0.1 -f null - 2>&1`);
    const S = [...log.matchAll(/silence_start: ([\d.]+)/g)].map(m => +m[1]), E = [...log.matchAll(/silence_end: ([\d.]+)/g)].map(m => +m[1]);
    S.forEach((a, k) => {
      const b = E[k]; if (b === undefined) return;
      const prev = words.filter(w => w.start < a + 0.05).at(-1), next = words.find(w => w.start >= a + 0.05);
      if (!prev || !next) return;                       // leave lead-in / tail alone
      const keep = /[.?!]$/.test(prev.text) ? 0.22 : /,$/.test(prev.text) ? 0.14 : 0.10, rem = b - a - keep;
      if (rem > 0.02) { const cs = a + keep / 2; cuts.push([cs, cs + rem]); }
    });
  }
  const shiftAt = t => cuts.reduce((acc, [cs, ce]) => acc + (t >= ce ? ce - cs : t > cs ? t - cs : 0), 0);
  const nw = words.map(x => ({ text: x.text, start: +(x.start - shiftAt(x.start)).toFixed(3), end: +(x.end - shiftAt(x.end)).toFixed(3) }));
  const end = Math.min(dur, words.at(-1).end + 0.12); const keeps = []; let t = 0;
  for (const [cs, ce] of cuts) { keeps.push([t, cs]); t = ce; } keeps.push([t, end]);
  const fc = keeps.map(([a, b], i) => `[0:a]atrim=start=${a}:end=${b},asetpts=PTS-STARTPTS[k${i}]`).join(";") + ";" + keeps.map((_, i) => `[k${i}]`).join("") + `concat=n=${keeps.length}:v=0:a=1,aresample=48000[o]`;
  sh(`ffmpeg -y -i audio/p${n}_raw.mp3 -filter_complex "${fc}" -map "[o]" -ac 1 audio/p${n}.wav -loglevel error`);
  const d = parseFloat(sh(`ffprobe -v error -show_entries format=duration -of csv=p=0 audio/p${n}.wav`));
  nw.forEach(w => all.push({ text: w.text, start: +(w.start + off).toFixed(3), end: +(w.end + off).toFixed(3), flat: p.flat }));
  list.push(`file 'p${n}.wav'`); off += d;
  if (n < parts.length - 1) { sh(`ffmpeg -y -f lavfi -i anullsrc=r=48000:cl=mono -t ${GAP} audio/gap${n}.wav -loglevel error`); list.push(`file 'gap${n}.wav'`); off += GAP; }
}
writeFileSync("audio/list.txt", list.join("\n") + "\n");
sh(`cd audio && ffmpeg -y -f concat -safe 0 -i list.txt -c:a pcm_s16le vo.wav -loglevel error && ffmpeg -y -i vo.wav -c:a libmp3lame -b:a 192k vo.mp3 -loglevel error`);
writeFileSync("audio/words.json", JSON.stringify(all));
console.log(`VO ${off.toFixed(2)}s, ${all.length} words, ${parts.length} part(s)`);
console.log(all.map((w, i) => `${i}:${w.text}@${w.start.toFixed(2)}`).join(" "));
