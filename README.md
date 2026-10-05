# Avatar Reel

A free [Claude Code](https://claude.com/claude-code) plugin that turns a script into a **9:16 talking-head reel with your own AI avatar**: your cloned voice, a lip-synced head, picture panels that change with every sentence, karaoke captions, and a tight, continuous cadence with no dead air.

You talk to Claude. Claude writes and locks the script with you, then renders the reel.

```
script (locked with you)  →  your voice clone (ElevenLabs)  →  lip-synced head (HeyGen)
        →  phrase-anchored edit: full-face lines + split-screen picture panels (motion graphics / B-roll)
        →  karaoke captions  →  out/<name>-v1.mp4  +  a 24-frame QC sheet
```

Built by [Sierra Exclusive](https://github.com/biz-sierra) for our own short-form content, and shared free.

## What you need

| | |
|---|---|
| **Claude Code** | with plugin support |
| **ElevenLabs** account | a voice clone of **your own** voice (Instant or Professional) + an API key |
| **HeyGen** account | API credits (about 3 credits per second of video, so ~150 for a 50-second reel) |
| **One photo of you** | 9:16, at least 1080×1920, looking straight into the lens, mouth fully visible |
| **Tools** | macOS or Linux · Node 18+ · Python 3 with Pillow · ffmpeg |

Optional: any image→video generator, for new B-roll clips when a script needs a new picture.

> Only clone a voice and a face that you own, or have written consent to use.

## Install

In Claude Code:

```
/plugin marketplace add biz-sierra/avatar-reel
/plugin install avatar-reel@sierra-exclusive
```

## Set up (once)

Ask Claude: **"set up avatar reel"**. It runs the setup check, asks for your voice ID and photo path, and installs what it needs (Playwright + Chromium, about 150 MB, into `~/.config/avatar-reel`).

**Your API keys never go in the chat.** Add them yourself, in your own terminal:

- **macOS:** `bash ~/.claude/plugins/cache/sierra-exclusive/avatar-reel/*/skills/avatar-reel/setup.sh keys` (saves them to the Keychain, input hidden)
- **Anywhere:** add `export ELEVENLABS_API_KEY=…` and `export HEYGEN_API_KEY=…` to your shell profile

## If something doesn't work

Ask Claude to **"run the avatar reel doctor"**. It checks your tools, ffmpeg, the video renderer, your config, your API keys and voice (free, read-only calls; it never spends credits or shows your keys) and the reel you're working on. Then it repairs what it safely can: it installs missing pieces, relinks broken folders and resets bad settings. You can also run it yourself:

```
bash ~/.claude/plugins/cache/sierra-exclusive/avatar-reel/*/skills/avatar-reel/doctor.sh --fix
```

## Make a reel

Ask Claude something like:

> "Make an avatar reel. Here's my script: …"
> "Write me a 45-second reel that breaks the belief that more reviews is all a local business needs, then make it with my avatar."

Claude will:
1. **Lock the script with you first.** Nothing that costs money runs until you say it's good.
2. Make the voiceover and let you listen (pennies).
3. Render the head on HeyGen (the step that costs credits).
4. Plan a picture for every line, render the graphics, cut the reel, and check every frame on a QC sheet.

You get `out/<name>-v1.mp4` in a `<name>-reel/` folder. Re-cutting the timing or rewriting the graphics afterwards costs nothing.

## What's in the box

- **The method:** script rules that keep a reel human and believable (no label as line one, a peer example, a countable cost, one picture running through the whole script, an 8th-grade reading level, an accuracy pass), pacing rules for the edit, and what makes an avatar read as a real person (eyeline, blinks in the first line, a real beat on the heavy lines).
- **The cadence:** pauses measured on the real silence and squeezed to 0.22s after a sentence, 0.14s after a comma and 0.10s mid-phrase.
- **15+ motion-graphic scenes** you edit per reel (toggles, AI answer cards, schema/code splits, forms, maps, incoming calls…), rendered frame-accurate from HTML/CSS.
- **A B-roll library:** a building-inspector character series (door, chained gate, blueprint, walking in).
- **Free fixes after rendering:** trim leftover dead air or an "uh" from the voice *and* the lip-synced video together, without re-rendering.
- **Niche clones:** turn one finished reel into a version for another trade by re-rendering a single sentence (~12 credits instead of ~150).
- **A full worked example:** `examples/the-gate/`, with the script and its complete anchored timeline.

## Costs

| Step | Cost |
|---|---|
| Voiceover (ElevenLabs) | pennies |
| Head (HeyGen) | ~3 API credits per second of video |
| Graphics, edit, captions, re-cuts | free (runs on your machine) |
| New B-roll clips | whatever your image/video generator charges |

## License

Free. [CC BY-NC 4.0](LICENSE) with one added permission:

- ✅ **Make videos with it for anything:** your business, your personal brand, your clients. The videos are yours.
- ✅ Share it, fork it, adapt it, with attribution to Seth Gillen / Sierra Exclusive.
- ❌ Don't sell the plugin itself, or a repackaged version of it.
