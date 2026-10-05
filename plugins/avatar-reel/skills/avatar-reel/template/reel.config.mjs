// Per-reel config. SLUG is stamped by new-reel.sh; everything about YOU comes from the user config written by setup.sh:
//   $AVATAR_REEL_HOME/config.json   (default ~/.config/avatar-reel/config.json)
import { readFileSync, existsSync } from "node:fs"; import { homedir, platform } from "node:os"; import { execSync } from "node:child_process";
export const SLUG = "__SLUG__";
export const HOME = process.env.AVATAR_REEL_HOME || `${homedir()}/.config/avatar-reel`;
const CFG = `${HOME}/config.json`;
if (!existsSync(CFG)) { console.error(`No ${CFG}. Run the skill's setup.sh first.`); process.exit(1); }
const C = JSON.parse(readFileSync(CFG, "utf8"));
export const VOICE = C.voice_id;                       // your ElevenLabs voice clone id
export const SPEED = C.speed ?? 1.17;                  // ElevenLabs speed (0.7–1.2); 1.17 + the pause squeeze = the standard cadence
export const AVATAR_STILL = C.avatar_still;            // 9:16 still of you, looking into the lens, mouth fully visible
export const ACCENT = C.accent ?? "#00BF63";           // brand color: panel rule, active caption word, highlights
export const FACE_TOP = C.face_top ?? 60;              // SPLIT mode crops the head from this y (1080x1920 space): set so your face sits in the lower 2/3
export const BROLL = C.broll_dir || "";                // optional folder of your own clips, used as "broll:<name>" in timeline.mjs
export const EXPRESSIVENESS = C.expressiveness ?? "medium"; // HeyGen: low | medium | high
export const LIB = "./lib";                            // the skill's clip library, copied into each reel by new-reel.sh

// API keys: env var first, then (macOS) the Keychain entry setup.sh can create.
export function apiKey(name) {                        // name: "elevenlabs" | "heygen"
  const env = process.env[`${name.toUpperCase()}_API_KEY`];
  if (env) return env.trim();
  if (platform() === "darwin") {
    try { return execSync(`security find-generic-password -s "avatar-reel-${name}" -a "$USER" -w`, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch {}
  }
  console.error(`Missing ${name} API key. Set ${name.toUpperCase()}_API_KEY or re-run setup.sh.`); process.exit(1);
}
