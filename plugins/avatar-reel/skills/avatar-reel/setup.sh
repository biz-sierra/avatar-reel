#!/bin/bash
# One-time setup for avatar-reel. Writes $AVATAR_REEL_HOME/config.json (default ~/.config/avatar-reel) and installs Playwright there.
#
#   bash setup.sh --voice-id <elevenlabs voice id> --avatar /path/to/still-9x16.png [--accent "#00BF63"] [--face-top 60] [--speed 1.17]
#   bash setup.sh check      # verify tools, config and keys
#   bash setup.sh keys       # store API keys in the macOS Keychain. Run this in YOUR OWN terminal: it reads them hidden,
#                            # so they never pass through a chat. (Linux/other: export ELEVENLABS_API_KEY / HEYGEN_API_KEY instead.)
set -e
H="${AVATAR_REEL_HOME:-$HOME/.config/avatar-reel}"
ok(){ printf '  \033[32m✓\033[0m %s\n' "$1"; }; bad(){ printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

keys() {
  [ "$(uname)" = "Darwin" ] || { echo "Not macOS: put ELEVENLABS_API_KEY and HEYGEN_API_KEY in your shell profile instead."; exit 1; }
  [ -t 0 ] || { echo "Run this in your own terminal (it needs to read the keys hidden):  bash \"$0\" keys"; exit 1; }
  for n in elevenlabs heygen; do
    read -r -s -p "$(echo $n | tr a-z A-Z) API key (enter to skip): " k; echo
    [ -n "$k" ] && security add-generic-password -U -s "avatar-reel-$n" -a "$USER" -w "$k" && ok "saved avatar-reel-$n to Keychain"
  done
}

check() {
  FAIL=0; echo "Tools:"
  command -v node >/dev/null && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ] && ok "node $(node -v)" || bad "node 18+ (https://nodejs.org)"
  command -v python3 >/dev/null && ok "python3" || bad "python3"
  python3 -c "import PIL" 2>/dev/null && ok "Pillow" || bad "Pillow  →  python3 -m pip install --user pillow"
  command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null && ok "ffmpeg + ffprobe" || bad "ffmpeg  →  brew install ffmpeg  /  apt install ffmpeg"
  [ -d "$H/node_modules/playwright" ] && ok "playwright in $H" || bad "playwright (re-run setup.sh with your settings)"
  echo "Config ($H/config.json):"
  if [ -f "$H/config.json" ]; then
    node -e '
      const c=require(process.argv[1]); const fs=require("fs");
      console.log(c.voice_id ? "  \x1b[32m✓\x1b[0m voice_id "+c.voice_id : "  \x1b[31m✗\x1b[0m voice_id missing");
      console.log(c.avatar_still && fs.existsSync(c.avatar_still) ? "  \x1b[32m✓\x1b[0m avatar_still "+c.avatar_still : "  \x1b[31m✗\x1b[0m avatar_still missing or not found");
      console.log("    accent "+(c.accent||"#00BF63")+" · face_top "+(c.face_top??60)+" · speed "+(c.speed??1.17)+" · expressiveness "+(c.expressiveness||"medium"));' "$H/config.json"
  else bad "no config yet"; fi
  echo "API keys:"
  for n in elevenlabs heygen; do
    V=$(echo $n | tr a-z A-Z)_API_KEY
    if [ -n "${!V}" ]; then ok "$V (env)"
    elif [ "$(uname)" = "Darwin" ] && security find-generic-password -s "avatar-reel-$n" -a "$USER" >/dev/null 2>&1; then ok "$n (Keychain)"
    else bad "$n key: run  bash \"$0\" keys  in your own terminal, or export $V"; fi
  done
  [ "$FAIL" = 0 ] && echo "Ready." || { echo "Fix the ✗ items above."; exit 1; }
}

case "$1" in keys) keys; exit;; check) check; exit;; -h|--help|"") sed -n 2,8p "$0" | sed 's/^# \{0,1\}//'; exit;; esac

VOICE=""; AVATAR=""; ACCENT="#00BF63"; FACE=60; SPEED=1.17
while [ $# -gt 0 ]; do case "$1" in
  --voice-id) VOICE="$2"; shift 2;; --avatar) AVATAR="$2"; shift 2;; --accent) ACCENT="$2"; shift 2;;
  --face-top) FACE="$2"; shift 2;; --speed) SPEED="$2"; shift 2;; *) echo "unknown option $1"; exit 1;; esac; done
[ -n "$VOICE" ] && [ -n "$AVATAR" ] || { echo "need --voice-id and --avatar (see --help)"; exit 1; }
AVATAR="$(cd "$(dirname "$AVATAR")" && pwd)/$(basename "$AVATAR")"; [ -f "$AVATAR" ] || { echo "avatar still not found: $AVATAR"; exit 1; }
mkdir -p "$H"
[ -f "$H/config.json" ] && cp "$H/config.json" "$H/config.backup.json" && echo "(previous config saved as config.backup.json)"
node -e 'const [f,v,a,c,t,s]=process.argv.slice(1); require("fs").writeFileSync(f, JSON.stringify({voice_id:v, avatar_still:a, accent:c, face_top:+t, speed:+s, expressiveness:"medium", broll_dir:"", caption_font:""}, null, 2)+"\n")' \
  "$H/config.json" "$VOICE" "$AVATAR" "$ACCENT" "$FACE" "$SPEED"
ok "wrote $H/config.json"
if [ ! -d "$H/node_modules/playwright" ]; then
  echo "Installing Playwright + Chromium into $H (one time, ~150 MB)…"
  (cd "$H" && [ -f package.json ] || echo '{"private":true,"type":"module"}' > "$H/package.json"; cd "$H" && npm install --silent playwright && npx --yes playwright install chromium)
fi
check
