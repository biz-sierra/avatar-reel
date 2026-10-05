#!/bin/bash
# avatar-reel doctor: finds what's broken and fixes what it safely can.
#
#   bash doctor.sh                 # diagnose the machine, config and API keys
#   bash doctor.sh <reel-dir>      # ...plus one reel build folder (or run it from inside the reel folder)
#   bash doctor.sh --fix [...]     # also apply the automatic fixes (installs, relinks, config repairs)
#
# Key checks use free, read-only API calls. Nothing here spends credits, and keys are never printed.
SKILL="$(cd "$(dirname "$0")" && pwd)"
H="${AVATAR_REEL_HOME:-$HOME/.config/avatar-reel}"
FIX=0; REEL=""
for a in "$@"; do case "$a" in --fix) FIX=1;; -h|--help) sed -n 2,8p "$0" | sed 's/^# \{0,1\}//'; exit;; *) REEL="$a";; esac; done
[ -z "$REEL" ] && [ -f reel.config.mjs ] && REEL="$PWD"
ERR=0; WARN=0; FIXED=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; ERR=$((ERR+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
fixd() { printf '  \033[36m⚙\033[0m fixed: %s\n' "$1"; FIXED=$((FIXED+1)); ERR=$((ERR>0?ERR-1:0)); }
hint() { printf '      → %s\n' "$1"; }
OS="$(uname)"
pkg() { [ "$OS" = "Darwin" ] && echo "brew install $1" || echo "sudo apt install $2"; }

echo "System"
if command -v node >/dev/null && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ]; then ok "node $(node -v)"
else bad "Node 18+ not found"; hint "install from https://nodejs.org (or: $(pkg node nodejs))"; fi

if command -v python3 >/dev/null; then ok "python3 $(python3 -c 'import sys;print(sys.version.split()[0])')"
  if python3 -c "import PIL" 2>/dev/null; then ok "Pillow"
  else bad "Pillow (Python imaging) missing: captions can't render"
    if [ $FIX = 1 ]; then
      if python3 -m pip install --user --quiet pillow 2>/dev/null || python3 -m pip install --quiet pillow 2>/dev/null; then fixd "installed Pillow"
      else hint "pip refused (managed Python). Try: $(pkg pillow python3-pil)  or  python3 -m pip install --user --break-system-packages pillow"; fi
    else hint "run with --fix, or: python3 -m pip install --user pillow"; fi
  fi
else bad "python3 not found"; hint "$(pkg python python3)"; fi

if command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null; then
  ok "ffmpeg $(ffmpeg -version | head -1 | awk '{print $3}')"
  F=$(ffmpeg -hide_banner -filters 2>/dev/null); E=$(ffmpeg -hide_banner -encoders 2>/dev/null); miss=""
  for f in silencedetect loudnorm xfade atempo ebur128 tpad; do echo "$F" | grep -qw "$f" || miss="$miss $f"; done
  for e in libx264 qtrle aac; do echo "$E" | grep -qw "$e" || miss="$miss $e"; done
  [ -z "$miss" ] && ok "ffmpeg has every filter/encoder the pipeline uses" || { bad "ffmpeg build is missing:$miss"; hint "install a full build: $(pkg ffmpeg ffmpeg) (xfade needs ffmpeg 4.3+)"; }
else bad "ffmpeg/ffprobe not found"; hint "$(pkg ffmpeg ffmpeg)"; fi

echo "Renderer (Playwright + Chromium in $H)"
mkdir -p "$H"
if [ ! -d "$H/node_modules/playwright" ]; then
  bad "Playwright not installed"
  if [ $FIX = 1 ] && command -v npm >/dev/null; then
    [ -f "$H/package.json" ] || echo '{"private":true,"type":"module"}' > "$H/package.json"
    (cd "$H" && npm install --silent playwright >/dev/null 2>&1) && fixd "installed Playwright" || hint "npm install failed. Check your network, then: cd \"$H\" && npm install playwright"
  else hint "run with --fix"; fi
fi
if [ -d "$H/node_modules/playwright" ]; then
  if (cd "$H" && node -e 'import("playwright").then(async({chromium})=>{const b=await chromium.launch();await b.close()}).catch(e=>{console.error(e.message.split("\n")[0]);process.exit(1)})' >/dev/null 2>"$H/.doctor.err"); then ok "Chromium launches"
  else bad "Chromium won't launch: $(head -1 "$H/.doctor.err")"
    if [ $FIX = 1 ]; then (cd "$H" && npx --yes playwright install chromium >/dev/null 2>&1) && fixd "downloaded Chromium (re-run doctor to confirm)" || hint "cd \"$H\" && npx playwright install chromium"
      [ "$OS" != "Darwin" ] && hint "Linux: also run  cd \"$H\" && sudo npx playwright install-deps chromium"
    else hint "run with --fix (downloads Chromium, ~95 MB)"; fi
  fi
  rm -f "$H/.doctor.err"
fi
curl -s -m 5 -o /dev/null -w '%{http_code}' https://fonts.googleapis.com/css2?family=DM+Sans | grep -q 200 && ok "Google Fonts reachable (graphics use DM Sans)" || warn "can't reach Google Fonts: graphics will render in a fallback font (offline or blocked)"

echo "Config ($H/config.json)"
CFG="$H/config.json"
if [ ! -f "$CFG" ]; then bad "no config yet"; hint "bash \"$SKILL/setup.sh\" --voice-id <id> --avatar <path>"
elif ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$CFG" 2>/dev/null; then
  bad "config.json is not valid JSON"
  if [ $FIX = 1 ] && [ -f "$H/config.backup.json" ]; then cp "$H/config.backup.json" "$CFG" && fixd "restored config.backup.json"; else hint "re-run setup.sh with your settings"; fi
else
  get() { node -p "const c=require(process.argv[1]); c[process.argv[2]] ?? ''" "$CFG" "$1"; }
  setc() { node -e 'const f=process.argv[1],c=JSON.parse(require("fs").readFileSync(f,"utf8"));c[process.argv[2]]=isNaN(+process.argv[3])||process.argv[3]===""?process.argv[3]:+process.argv[3];require("fs").writeFileSync(f,JSON.stringify(c,null,2)+"\n")' "$CFG" "$1" "$2"; }
  V=$(get voice_id); [ -n "$V" ] && ok "voice_id set" || { bad "voice_id missing"; hint "setup.sh --voice-id <your ElevenLabs voice id> --avatar …"; }
  A=$(get avatar_still)
  if [ -f "$A" ]; then
    D=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$A" 2>/dev/null); W=${D%x*}; HH=${D#*x}
    if [ -n "$W" ] && [ "$W" -gt 0 ]; then
      R=$(node -p "Math.abs($W/$HH - 9/16) < 0.03")
      [ "$R" = "true" ] && ok "avatar still ${D} (9:16)" || warn "avatar still is ${D}, not 9:16: HeyGen will crop it (fit: cover). Re-export at 1080x1920 for predictable framing."
      [ "$HH" -lt 1920 ] && warn "avatar still is under 1920px tall: the head will look soft. Upscale it or use a bigger image."
    else bad "can't read avatar still: $A"; fi
  else bad "avatar still not found: ${A:-<empty>}"; hint "setup.sh --avatar <path>, or edit avatar_still in config.json"; fi
  AC=$(get accent)
  if [ -n "$AC" ] && ! echo "$AC" | grep -qE '^#[0-9A-Fa-f]{6}$'; then
    bad "accent \"$AC\" isn't a #RRGGBB color (ffmpeg needs 6 hex digits)"
    [ $FIX = 1 ] && setc accent "#00BF63" && fixd "accent reset to #00BF63"
  else ok "accent ${AC:-#00BF63}"; fi
  EX=$(get expressiveness); case "$EX" in ""|low|medium|high) ;; *) bad "expressiveness \"$EX\" must be low, medium or high"; [ $FIX = 1 ] && setc expressiveness medium && fixd "expressiveness → medium";; esac
  SP=$(get speed); [ -n "$SP" ] && node -e "process.exit(($SP>=0.7&&$SP<=1.2)?0:1)" 2>/dev/null || { [ -n "$SP" ] && { bad "speed $SP is outside ElevenLabs' 0.7–1.2"; [ $FIX = 1 ] && setc speed 1.17 && fixd "speed → 1.17"; }; }
  FONT=$(get caption_font)
  if [ -n "$FONT" ] && [ ! -f "$FONT" ]; then bad "caption_font not found: $FONT"; [ $FIX = 1 ] && setc caption_font "" && fixd "caption_font cleared (auto-detect)"; fi
  FOUND=$(for f in "$(get caption_font)" "/System/Library/Fonts/Supplemental/Arial Black.ttf" "/usr/share/fonts/truetype/msttcorefonts/Arial_Black.ttf" "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"; do [ -n "$f" ] && [ -f "$f" ] && { echo "$f"; break; }; done)
  if [ -n "$FOUND" ]; then ok "caption font $(basename "$FOUND")"
  else
    bad "no caption font found"
    ALT=$(command -v fc-list >/dev/null && fc-list : file style | grep -iE 'black|heavy|extrabold|bold' | head -1 | cut -d: -f1)
    if [ $FIX = 1 ] && [ -n "$ALT" ]; then setc caption_font "$ALT" && fixd "caption_font → $ALT"; else hint "set caption_font in config.json to a heavy .ttf (Arial Black, Montserrat Black, DejaVu Sans Bold)"; fi
  fi
  BR=$(get broll_dir); [ -n "$BR" ] && [ ! -d "$BR" ] && warn "broll_dir not found: $BR (only matters if a timeline uses broll:…)"
fi

echo "API keys (free read-only checks; keys are never printed)"
key() { local v; v=$(printenv "$(echo "$1" | tr a-z A-Z)_API_KEY"); [ -z "$v" ] && [ "$OS" = "Darwin" ] && v=$(security find-generic-password -s "avatar-reel-$1" -a "$USER" -w 2>/dev/null); echo "$v"; }
EK=$(key elevenlabs)
if [ -z "$EK" ]; then bad "ElevenLabs key not found"; hint "in your own terminal: bash \"$SKILL/setup.sh\" keys   (or export ELEVENLABS_API_KEY)"
else
  C=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H "xi-api-key: $EK" https://api.elevenlabs.io/v1/user)
  case "$C" in 200) ok "ElevenLabs key works";; 401) bad "ElevenLabs rejected the key (401)"; hint "make a new key at elevenlabs.io → API Keys, then re-run setup.sh keys";;
    000) warn "couldn't reach ElevenLabs (network?)";; *) warn "ElevenLabs answered $C (the key may lack the user_read permission: that's fine if TTS works)";; esac
  if [ -n "$V" ]; then
    C=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H "xi-api-key: $EK" "https://api.elevenlabs.io/v1/voices/$V")
    case "$C" in 200) ok "voice $V is in this account";; 400|404) bad "voice $V isn't in this ElevenLabs account"; hint "copy the voice ID from elevenlabs.io → Voices → your clone";; 000) ;; *) warn "voice lookup answered $C (key may lack voices_read)";; esac
  fi
fi
HK=$(key heygen)
if [ -z "$HK" ]; then bad "HeyGen key not found"; hint "in your own terminal: bash \"$SKILL/setup.sh\" keys   (or export HEYGEN_API_KEY)"
else
  Q=$(curl -s -m 10 -H "X-Api-Key: $HK" https://api.heygen.com/v2/user/remaining_quota)
  CR=$(echo "$Q" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const v=j.data?.details?.api??j.data?.remaining_quota;console.log(v??(j.error?"ERR:"+(j.error.message||j.error.code||"error"):"?"))}catch{console.log("ERR:unreadable")}})')
  case "$CR" in ERR:*) bad "HeyGen rejected the key: ${CR#ERR:}"; hint "HeyGen → Settings → API: copy the key (API credits are separate from the web plan)";;
    "?") warn "HeyGen key accepted but credits unreadable";;
    *) ok "HeyGen key works ($CR API credits)"; node -e "process.exit($CR<200?0:1)" 2>/dev/null && warn "under ~200 credits: a 50s reel needs ~150";; esac
fi

if [ -n "$REEL" ]; then
  REEL="$(cd "$REEL" 2>/dev/null && pwd)"; echo "Reel ($REEL)"
  if [ ! -f "$REEL/reel.config.mjs" ]; then bad "not a reel folder (no reel.config.mjs)"; hint "make one with: bash \"$SKILL/new-reel.sh\" <slug>"
  else
    cd "$REEL"
    if ! grep -q "AVATAR_REEL_HOME" reel.config.mjs; then
      bad "reel.config.mjs is from an older template"
      [ $FIX = 1 ] && { cp reel.config.mjs reel.config.old.mjs; sed "s#__SLUG__#$(basename "$REEL" | sed 's/-reel$//')#" "$SKILL/template/reel.config.mjs" > reel.config.mjs && fixd "regenerated reel.config.mjs (old one kept as reel.config.old.mjs)"; }
    fi
    if [ ! -e node_modules/playwright ]; then
      bad "node_modules link is broken (ERR_MODULE_NOT_FOUND: playwright)"
      [ $FIX = 1 ] && { rm -f node_modules; ln -s "$H/node_modules" node_modules && fixd "relinked node_modules → $H/node_modules"; }
    else ok "node_modules link"; fi
    if [ ! -d lib/broll ]; then bad "lib/ (clip library) missing"; [ $FIX = 1 ] && cp -R "$SKILL/library" lib && fixd "copied the clip library into lib/"; else ok "clip library"; fi
    for f in reel-lib.mjs vo.mjs heygen.mjs build_gfx.mjs assemble.mjs captions.py timeline.mjs tighten.py gfx/gfx.html; do
      [ -f "$f" ] || { bad "missing $f"; [ $FIX = 1 ] && mkdir -p "$(dirname "$f")" && cp "$SKILL/template/$f" "$f" && fixd "restored $f from the template"; }
    done
    S=$(cat audio/script.txt 2>/dev/null)
    if [ -z "$S" ] || echo "$S" | grep -q "^Paste the LOCKED script"; then warn "audio/script.txt still has the placeholder: paste the locked script before node vo.mjs"; fi
    dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null; }
    if [ -f audio/vo.wav ]; then ok "voiceover $(printf '%.1f' "$(dur audio/vo.wav)")s"
      [ -f audio/words.json ] || bad "audio/words.json missing: re-run node vo.mjs (captions and anchors need it)"
      [ -f audio/vo.mp3 ] || { bad "audio/vo.mp3 missing (HeyGen uploads it)"; [ $FIX = 1 ] && ffmpeg -y -v error -i audio/vo.wav -c:a libmp3lame -b:a 192k audio/vo.mp3 && fixd "rebuilt audio/vo.mp3"; }
    fi
    if [ -f head_raw.mp4 ]; then
      HD=$(dur head_raw.mp4); VD=$(dur audio/vo.wav)
      if [ -n "$VD" ] && node -e "process.exit(Math.abs($HD-$VD)>0.25?0:1)"; then
        bad "head_raw.mp4 (${HD%.*}s) doesn't match vo.wav (${VD%.*}s): the VO changed after HeyGen rendered, so lips won't sync"
        hint "re-render: node heygen.mjs --new  (spends credits)  ·  or regenerate the VO that matches the head"
      else ok "head matches the voiceover"; fi
    elif [ -f heygen_video_id.txt ]; then warn "HeyGen job submitted but head_raw.mp4 not downloaded: run node heygen.mjs to resume polling (no new charge)"; fi
    if [ -f audio/words.json ]; then
      T=$(node -e 'import("./timeline.mjs").then(m=>{const s=m.segs();console.log("ok "+s.length)}).catch(e=>{console.log("ERR "+e.message.split("\n")[0])})' 2>&1 | tail -1)
      case "$T" in "ok "*) ok "timeline resolves (${T#ok } cuts)";;
        *) bad "timeline: ${T#ERR }"; echo "$T" | grep -q "anchor not found" && hint "the phrase isn't in audio/words.json exactly as spoken. Check spelling, contractions and order: at() only searches forward."; esac
      if [ -e node_modules/playwright ] && echo "$T" | grep -q "^ok"; then
        GE=$(node -e '
          import("./timeline.mjs").then(async m=>{const {chromium}=await import("playwright");const {resolve}=await import("node:path");
            const sc=[...new Set(m.segs().filter(s=>s.mode==="SPLIT"&&!/^(lib|clip|broll):/.test(s.src||"")&&s.src!=="replay").map(s=>s.opts.scene||s.src))];
            const b=await chromium.launch();const bad=[];
            for(const s of sc){const p=await b.newPage();const e=[];p.on("pageerror",x=>e.push(x.message));
              await p.goto("file://"+resolve("gfx/gfx.html")+"?s="+s);await p.waitForTimeout(150);
              const okk=await p.evaluate(()=>typeof window.__seek==="function");if(e.length||!okk)bad.push(s+": "+(e[0]||"scene did not load"));await p.close();}
            await b.close();console.log(bad.length?"ERR "+bad.join(" | "):"ok "+sc.length)}).catch(e=>console.log("ERR "+e.message.split("\n")[0]))' 2>&1 | tail -1)
        case "$GE" in "ok "*) ok "every graphics scene the timeline uses loads (${GE#ok })";;
          *) bad "gfx/gfx.html: ${GE#ERR }"; hint "a JavaScript error in gfx.html stops ALL scenes from rendering. Fix the scene it names (a missing \` or }, or an undefined helper), then re-run the doctor. Or start over from the template (loses this reel's copy edits): cp \"$SKILL/template/gfx/gfx.html\" gfx/gfx.html";; esac
      fi
    fi
  fi
fi

echo
if [ $ERR = 0 ]; then printf '\033[32mAll clear.\033[0m'; else printf '\033[31m%s problem(s) left.\033[0m' "$ERR"; fi
[ $FIXED -gt 0 ] && printf ' Fixed %s.' "$FIXED"; [ $WARN -gt 0 ] && printf ' %s warning(s).' "$WARN"
[ $ERR -gt 0 ] && [ $FIX = 0 ] && printf ' Re-run with --fix to repair what can be repaired automatically.'
echo; [ $ERR = 0 ]
