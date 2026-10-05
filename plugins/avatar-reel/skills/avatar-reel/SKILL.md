---
name: avatar-reel
description: Build a 9:16 talking-head reel with the user's own AI avatar. Locked script → their cloned voice (ElevenLabs) → HeyGen lip-synced head → phrase-anchored edit with split-screen picture panels (coded motion graphics + B-roll clips) → karaoke captions → MP4 with a tight, continuous cadence. Use when the user says "avatar reel", "make a reel with my AI avatar", "AI talking head video", "make this script into a video with my avatar", "another reel like the last one", or hands over a script for their avatar to say. The script gets locked FIRST, before any credits are spent.
---

# Avatar Reel: talking-head reel with your AI avatar

**What it makes:** the user's AI avatar talks to camera. On most lines a 1080×640 picture panel drops in on top, with an accent-colored rule under it and the face moved down below it. Each panel shows the picture for that exact sentence. Hook, empathy, turn and belief-break lines go full face. Karaoke captions sit low on the chest, with the spoken word in the accent color. Voice only, about −16 LUFS, and a hard cut at the end with no outro.

**Skill folder:** `${CLAUDE_PLUGIN_ROOT}/skills/avatar-reel/` (called `SKILL_DIR` below)
- `setup.sh`: one-time setup (config, Playwright, key check)
- `new-reel.sh`: scaffolds a reel build folder
- `template/`: the build scripts copied into each reel
- `library/broll/`: reusable B-roll clips (the building-inspector series)
- `examples/the-gate/`: a finished script plus its full anchored timeline. **Read both before building a first reel.**

---

## First run: setup (once per machine)

Run `bash "SKILL_DIR/setup.sh" check`. If anything shows ✗:

1. **Tools:** Node 18+, Python 3 with Pillow, and ffmpeg/ffprobe. The check prints the install command for anything missing.
2. **Voice:** the user needs an ElevenLabs voice clone **of their own voice** (Instant or Professional clone) and its voice ID.
3. **Avatar still:** one 9:16 image of the user, at least 1080×1920. It needs to:
   - look **straight into the lens at eye level**. A downward gaze reads as not talking to the viewer, and viewers notice.
   - show the mouth fully, with nothing in front of it.
   - be well lit and shot from the chest up.

   A real photo or an AI-generated likeness of the user both work.
4. **Config:** ask the user for the voice ID and the image path in chat, then run:
   `bash "SKILL_DIR/setup.sh" --voice-id <id> --avatar <path> [--accent "#hex"] [--face-top 60]`
   This writes `~/.config/avatar-reel/config.json` and installs Playwright plus Chromium there.
5. **API keys (ElevenLabs + HeyGen):** never ask the user to paste a key into the chat. Tell them to do one of these themselves:
   - run `bash "SKILL_DIR/setup.sh" keys` in **their own terminal** (macOS Keychain, input hidden), or
   - add `export ELEVENLABS_API_KEY=…` and `export HEYGEN_API_KEY=…` to their shell profile.

   Then re-run `check`.

Only clone a voice and likeness the user owns or has written consent to use.

## Step 0: lock the script before anything renders (hard gate)

A weak script wastes credits and an hour. So:
1. Write the script and show it to the user **in chat, in full**.
2. Iterate until they say it's good ("ok", "locked", "make it").
3. Only then run VO and HeyGen. Never start renders while the script is still being drafted.

### Script rules
- **One job per reel.** Break a belief, teach a tool, or invite an action. A belief-breaking reel has no call to action beyond "follow along."
- **No label as the first line.** The hook qualifies the viewer on its own; name the audience one beat later, inside the empathy line.
- **Use the buyer's own words** and a **countable cost** ("another month of new customers", not insider shorthand).
- **Absolve the viewer** in the middle ("That's not on you").
- **Use a peer as the example** ("the shop across town"), never an aspirational giant. A giant becomes a reason to give up.
- **Make delay expensive**, not just uncomfortable ("that gap gets wider every week").
- **Never knock your own category.** Attack the problem, not the industry you're in.
- **Every abstraction gets a picture.** One picture runs through the whole script, and the B-roll is built around it (The Gate used a building inspector who can't walk inside and only gets the paperwork).
- **8th-grade reading level or lower.** Plain words on camera. Keep jargon in a side table for the creator only (see the example). Check it:
  ```bash
  python3 - <<'EOF'   # paste the script into t; prints words, FK grade, seconds
  import re; t="""..."""
  w=re.findall(r"[A-Za-z']+",t); s=[x for x in re.split(r"[.!?]+",t) if x.strip()]
  syl=lambda x:max(1,len(re.findall(r"[aeiouy]+",x.lower()))-(1 if x.lower().endswith("e") and not x.lower().endswith("le") else 0))
  print(len(w),"words  FK %.1f"%(0.39*len(w)/len(s)+11.8*sum(map(syl,w))/len(w)-15.59),"  ~%ds"%(len(w)/4.5))
  EOF
  ```
  At speed 1.17 with the pause squeeze, a typical clone runs about **4.5 words/sec** (202 words ≈ 45s). Target 40–70s.
- **Accuracy pass before showing the user.** Every claim has to survive someone trying to prove it wrong. Tighten any overclaim and tell the user what changed and why.

## Step 1: scaffold

```bash
bash "SKILL_DIR/new-reel.sh" <slug> [parent-dir]      # → <parent-dir>/<slug>-reel/  (default: current dir)
```
Paste the locked script into `audio/script.txt`, **spelled for the ear**: `A.I.` not `AI`, numbers as words, `robots dot T X T`. Captions undo the common respellings (`A.I.`→`AI`, `Jason L D`→`JSON-LD`); add others in `captions.py`. Wrap a stretch in `[[flat]] … [[/flat]]` for a monotone "bad example" read.

## Step 2: voice + head (spends credits)

```bash
cd <slug>-reel
node vo.mjs        # ElevenLabs clone at config speed, pauses squeezed → audio/vo.wav, vo.mp3, words.json
node heygen.mjs    # prints credits left, submits, polls, downloads head_raw.mp4 (~3 API credits/sec ≈ 150 for 50s)
```

**Cadence (the standard): continuous, no dead air.**
- `vo.mjs` measures the *real* silences with ffmpeg `silencedetect` (-35 dB) and leaves:
  - **0.22s** after `. ? !`
  - **0.14s** after a comma
  - **0.10s** mid-phrase
- Don't squeeze on ElevenLabs' alignment gaps instead. They under-report silence by about 0.2s, which leaves 0.45s holes mid-sentence.
- Check before HeyGen: `ffmpeg -i audio/vo.wav -af silencedetect=noise=-35dB:d=0.12 -f null - 2>&1 | grep silence_end` should show nothing over ~0.24s except the tail.

**Let the user hear the voice before the face is rendered:** send them `audio/vo.mp3` before running `heygen.mjs`. Audio is pennies, and the head render is the expensive step.

`heygen.mjs` resumes polling the saved video ID if re-run. Use `--new` only to force a fresh render after the VO changes. Start HeyGen first, since it takes about 3–5 min, and build graphics while it runs.

### What makes an avatar read as human (feedback from a personal-brand content coach on an early render)
- **The opener is where it goes flat.** Viewers decide in the first line. Read it with the energy of the script's best line, not a neutral "announcer" tone. `heygen.mjs` asks for natural blinks and eyebrow movement *from the first word*. If the first seconds still look frozen, set `"expressiveness": "high"` in config.json.
- **Eyeline is everything.** If the avatar still looks slightly down, regenerate the still with eyes on the lens before rendering.
- **Heavy lines need a beat.** A line like "you're trying not to get burned again" shouldn't fly by at the same pace as everything around it. A real person sighs, slows down or pauses there. Keep a deliberate pause (0.4–0.6s) on those lines, and don't let the squeeze flatten it. ElevenLabs `eleven_v3` supports audio tags like `[sighs]` and `[softly]` if more emotion is needed (it has no speed setting, so apply `atempo` afterwards).

## Step 3: plan the picture for every line, then write `timeline.mjs`

One row per cut, **anchored to the spoken phrase**, so a regenerated VO never breaks the timing:
```js
[at("one setting"),        "SPLIT", "switch", { off: "@invisible" }],   // "@phrase" = seconds from cut start to that word
[at("That's not on you"),  "FULL"],
[at("Think of a building"),"SPLIT", "lib:inspector-door", { ss: 1.2 }],
```
`at()` walks forward, so a phrase said twice resolves in order. Make the second anchor more specific ("the shop across town **gets**").

Pacing rules:
- A visual change every **2–4s**. A cut under **~1s** can't be read: anchor it later or merge it.
- **FULL face** on the hook's first 1–1.5s, the empathy line, the turn, and the belief-break line. Viewers need the face at those moments.
- Repeat a motif clip on purpose. Callbacks read as story, not as reuse.
- End on a SPLIT payoff, then a hard cut with no outro.

| Mode | What | Opts |
|---|---|---|
| `FULL` | face fills the frame | `zoom: 1.14` punch-in · `grey: true` · `ui: "igui"` parody-reel overlay for a bad-example beat |
| `SPLIT` | panel on top (0–640) + face below | source = gfx scene · `lib:<clip>` · `clip:<file in clips/>` · `broll:<clip in your broll_dir>` · `replay` (`from:` sec; greyscale earlier head + "remember this guy?") |
| `CUT` | full-frame 9:16 B-roll | `broll:<name>` · `lib:<name>` · `clip:<name>` |

If the face sits too high or low under a panel, change `face_top` in config.json (the y in 1080×1920 where the SPLIT crop of the head starts).

## Step 4: graphics (`gfx/gfx.html`, free to iterate)

```bash
node build_gfx.mjs              # every scene the timeline uses
node build_gfx.mjs switch nap   # just these (by key)
```
Frames are rendered by seeking paused CSS animations, so text stays crisp. Copy that's specific to the reel (business names, chips, queries) lives in the scene code, so edit `gfx/gfx.html` **in the reel folder**, never the template. The accent color comes from config.json.

**Scene library** (params in brackets are seconds from the cut's start). The example copy is a local-SEO story with fictional businesses, so rewrite it for each reel:

| Scene | Shows |
|---|---|
| `switch` [off] | "Let AI tools read my site" toggle, ON → OFF + "Invisible to AI" |
| `site` | a demo business homepage ("what customers see") |
| `code` | homepage vs JSON-LD split ("what customers see / what Google reads") |
| `form` [fill] | "Paperwork for Google & AI" form: blank with a BLANK stamp, or `fill` → fields fill, ✓, EASY PICK |
| `robots` [fix] | robots.txt blocking GPTBot; `fix` flips it to Allow (99 = stays blocked) |
| `answer` [a] | an AI answer card naming a fictional competitor |
| `label` [c1 c2 c3] | "A hidden label on every page" + 3 chips (what / where / when) |
| `nap` [fix] | website vs Google profile; mismatches go red → match green |
| `sitemap` | page tree draws in + "Google found every page" |
| `call` | ringing phone with an incoming-call card |
| `cited` [b] | "Your site → cited / Your profile → picked" |
| `contrast` [c1 c2 c3] | vague slogan struck out → 3 fact chips |
| `rrt` [res] | a Rich Results Test-style card → "0 items detected" |
| `tri0`–`tri4` [save] | a three-corner framework device, blurred → per-corner unblur → all ✓ |
| `igui` / `callback` | overlays used by FULL `ui` and SPLIT `replay` |

Add a scene by writing a function in the `scenes` object (1080×640, dark panel, DM Sans, `var(--g)` for the accent). Use `A(name, dur, delay, extraAnimations)` for animations. **Gotchas:**
- Never write `${A(...)},out .2s ${t}s both`. `A()` ends in `;`, so the chained animation silently dies and both states overlap. Pass it as the 4th argument instead: ``A('fade',.3,0,`out .2s ${t}s both`)``.
- Don't center with `transform: translate(-50%)` on an element that runs `in`/`pop`, because the animation overwrites the transform. Use an explicit `left:`.
- Use fictional businesses only in example cards, and label them "example". Never use a real client's results unless the user supplies them and has permission to show them.

## Step 5: B-roll library + making new clips

| Clip | Good `ss` | Shows |
|---|---|---|
| `lib:inspector-door` | 1.2 | tries a storefront door, locked (a chiropractic office is visible inside, so crop it for other niches) |
| `lib:inspector-gate` | 0.3 / 0.6 / 2.3 | chained gate: walks up / rattles / steps back, shakes head |
| `lib:inspector-blueprint` | 0.8–1.0 | unrolls a blueprint and studies it |
| `lib:inspector-walks-in` | 3.7 | door opens, walks inside (2.4 = smiling at clipboard; chiro office inside) |

All 1280×720, 5s, no audio. `library/broll/inspector-base.png` is the character still. When a script needs a new picture, make new clips with any image→video model and save them in the reel's `clips/` folder (use them as `clip:<name>`):
1. Generate one 16:9 character/base still.
2. Image→video, 5s, 720p, no audio. Use the still as the start frame (same scene) or as a character reference (same character, new scene). Describe one action plus the camera, and end with "realistic, no text".
3. Check 3 frames per clip (0.5 / 2.5 / 4.5s) before use. **Check every clip for niche-specific props** before reusing it in another niche.

## Step 6: assemble, QC, deliver

```bash
node assemble.mjs [v2]   # → out/<slug>-v1.mp4 + out/qc-sheet.png, prints duration + LUFS
```
- **Read `out/qc-sheet.png`** (24 frames). Check that each line has the right panel, no text overflows, the face isn't covered, and captions aren't over the mouth.
- Fix timing in `timeline.mjs` or copy in `gfx.html`, then re-run. Neither costs credits.
- Tell the user plainly: frames were checked, **sound was not**. Lip sync and pronunciation need their ears.
- Never post on the user's behalf.

## Fixes after the head is rendered (no credits)

**Still hear dead air, or an "uh"?** Run `python3 tighten.py [START-END …]`. It trims the same pauses out of `vo.wav` and `head_raw.mp4` together, on the head's 25fps frame grid, with a 1–3 frame dissolve at each cut to hide the head-pose jump, so lip sync holds. Optional `START-END` spans (seconds in the original VO) cut filler sounds that silence detection can't see. Find the filler by ear, then test candidate spans with a transcriber (e.g. `faster-whisper`) until it hears the line clean. Cutting the **middle** of a stretched word ("thuuh") usually beats cutting either end. Originals are kept as `*_orig`, and the anchored timeline re-resolves on its own. Then: `node build_gfx.mjs && node assemble.mjs v2`.

## Niche clones (same reel, another trade)

Don't re-render the whole reel to change the niche. A chiropractor→plumber clone cost about 12 HeyGen credits:
1. Find every niche-specific line. Usually only one is spoken (the example query). The user picks the replacement line before any spend.
2. Generate 3 ElevenLabs takes of just that sentence, passing `previous_text` / `next_text` so the prosody matches the surrounding lines. Pick the one a transcriber hears cleanly with no internal pauses.
3. Render HeyGen for that line only, with 0.4s of silent pad each side. Splice the audio, the words and the head into the approved take at points on the 25fps grid that sit inside silences, with 2-frame dissolves. Shift every later timeline row by the length difference. Then run `tighten.py` → `build_gfx` → `assemble`.
4. Swap the niche copy in `gfx/gfx.html` (business names, schema @type, hours, the AI query/answer, chips, sitemap leaves, "new patient/customer" wording).
5. Check every B-roll clip for niche props. Crop them out, swap in a graphic, or make new clips.

## Costs
- **HeyGen:** about 3 API credits per second of video (about 150 for a 50s reel).
- **ElevenLabs:** pennies per reel.
- **New B-roll clips:** whatever the image/video generator charges (about 1 image + 1 video per clip). Library reuse is free.

## Don'ts
- **No music bed by default.** Talking-head reels read as more human with VO only. Add music only if the user asks.
- **No CTA on a belief-breaking reel** beyond "follow along". Offers belong in an invite reel.
- ffmpeg builds without `drawtext` are common, so all text goes in `gfx.html` or `captions.py`.
- If a build fails with `ERR_MODULE_NOT_FOUND: playwright`, the reel's `node_modules` link is broken. Re-run `setup.sh` and re-link it to `~/.config/avatar-reel/node_modules`.
