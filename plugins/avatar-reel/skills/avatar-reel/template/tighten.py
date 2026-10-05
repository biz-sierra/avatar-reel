#!/usr/bin/env python3
"""FALLBACK ONLY — vo.mjs already squeezes pauses before HeyGen. Use this when a head is already rendered
and you still hear dead air: tightens pauses AFTER the render, no credits.
Measures real silences in audio/vo.wav, trims each to target, and cuts the SAME frames out of head_raw.mp4
(25fps grid, 1–3 frame dissolve at each cut to hide the head-pose jump) so lip sync holds.
Originals are kept as *_orig; the tightened files take the canonical names, so the anchored timeline.mjs
re-resolves on its own. Then: node build_gfx.mjs && node assemble.mjs v2
"""
import json, re, subprocess
import os, shutil
for a, b in [("audio/vo.wav", "audio/vo_orig.wav"), ("head_raw.mp4", "head_orig.mp4"), ("audio/words.json", "audio/words_orig.json")]:
    if not os.path.exists(b): shutil.copy2(a, b)    # first run only: never lose the untouched render
SRC_VO, SRC_HEAD = "audio/vo_orig.wav", "head_orig.mp4"
FR = 1 / 25                                      # head_raw frame duration
TARGET = {"sentence": 0.22, "comma": 0.14, "mid": 0.10}   # silence left behind, seconds
NOISE, MIN = -35, 0.10
# Filler sounds to drop (an "uh", a drawn-out "thuuh"), in ORIGINAL vo seconds: python3 tighten.py 47.05-47.25 [more…]
# Silence detection can't see these, so you name them. Find one by ear, then test candidate spans with a transcriber
# (e.g. faster-whisper) until it hears the line clean; cutting the MIDDLE of a stretched word usually beats either end.
import sys
FILLERS = [tuple(map(float, a.split("-"))) for a in sys.argv[1:] if re.fullmatch(r"[\d.]+-[\d.]+", a)]

def sh(*a): return subprocess.run(a, capture_output=True, text=True, check=True)
words = json.load(open("audio/words_orig.json"))
err = subprocess.run(["ffmpeg", "-i", SRC_VO, "-af", f"silencedetect=noise={NOISE}dB:d={MIN}", "-f", "null", "-"], capture_output=True, text=True).stderr
S = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
E = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
vo_end = words[-1]["end"]
cuts = []                                         # (start, end) removed, source seconds
for s, e in zip(S, E):
    prev = [w for w in words if w["start"] < s + 0.05]; nxt = [w for w in words if w["start"] >= s + 0.05]
    if not prev or not nxt: continue              # leave lead-in / tail alone
    t = prev[-1]["text"]
    kind = "sentence" if t.endswith((".", "?", "!")) else "comma" if t.endswith(",") else "mid"
    rem = round(((e - s) - TARGET[kind]) / FR) * FR
    if rem < FR: continue
    cs = round((s + ((e - s) - rem) / 2) / FR) * FR
    cuts.append((round(cs, 4), round(cs + rem, 4), kind, t, nxt[0]["text"], round(e - s, 3)))
for fs, fe in FILLERS:
    nx = [w for w in words if w["start"] >= fs - 0.3]
    cuts.append((fs, fe, "filler", "", nx[0]["text"] if nx else "", round(fe - fs, 3)))
cuts.sort()

def M(t):                                          # source time -> tightened time
    sh_ = 0.0
    for cs, ce, *_ in cuts:
        if t >= ce: sh_ += ce - cs
        elif t > cs: return round(cs - sh_, 3)
    return round(t - sh_, 3)

keeps, t = [], 0.0
for cs, ce, *_ in cuts: keeps.append((t, cs)); t = ce
keeps.append((t, None))
def trims(stream, a):
    parts = []
    for i, (k0, k1) in enumerate(keeps):
        end = f":end={k1}" if k1 is not None else ""
        fade = ",afade=t=in:d=0.008" if i and "filler" in cuts[i - 1][2] else ""   # filler cuts land mid-voicing: no click
        if k1 is not None and "filler" in cuts[i][2]: fade += f",afade=t=out:st={k1 - k0 - 0.008:.4f}:d=0.008"
        if a: parts.append(f"[0:a]atrim=start={k0}{end},asetpts=PTS-STARTPTS{fade}[a{i}]")
        else: parts.append(f"[0:v]trim=start={k0}{end},setpts=PTS-STARTPTS[v{i}]")
    lab = "a" if a else "v"
    return ";".join(parts) + ";" + "".join(f"[{lab}{i}]" for i in range(len(keeps))) + f"concat=n={len(keeps)}:v={0 if a else 1}:a={1 if a else 0}[o]"
def head_graph():
    # Hide the head-pose jump at each cut with a 2–3 frame dissolve. The incoming piece starts XF early
    # (frames from inside the removed silence, mouth closed; 1 frame when the cut is tiny), so the overlap eats no kept frames: sync holds.
    parts, segs = [], []
    for i, (k0, k1) in enumerate(keeps):
        xf = 0.0
        if i:
            rem = cuts[i - 1][1] - cuts[i - 1][0]
            xf = 3 * FR if rem >= 4 * FR else 2 * FR if rem >= 3 * FR else FR
            if "filler" in cuts[i - 1][2]: xf = FR       # removed frames are mid-word: keep the blend short
        end = f":end={k1}" if k1 is not None else ""
        parts.append(f"[0:v]trim=start={round(k0 - xf, 4)}{end},setpts=PTS-STARTPTS[v{i}]")
        segs.append((xf, (k1 if k1 is not None else 1e9) - k0))
    lab, t = "v0", segs[0][1]
    for i in range(1, len(segs)):
        xf, ln = segs[i]; nxt = f"x{i}"
        parts.append(f"[{lab}][v{i}]xfade=transition=fade:duration={xf:.2f}:offset={t - xf:.4f}[{nxt}]")
        lab, t = nxt, t + ln
    return ";".join(parts), lab
sh("ffmpeg", "-y", "-v", "error", "-i", SRC_VO, "-filter_complex", trims("a", True), "-map", "[o]", "-c:a", "pcm_s16le", "audio/vo.wav")
g, lab = head_graph()
sh("ffmpeg", "-y", "-v", "error", "-i", SRC_HEAD, "-filter_complex", g, "-map", f"[{lab}]", "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-r", "25", "-an", "head_raw.mp4")

json.dump([{**w, "start": M(w["start"]), "end": M(w["end"])} for w in words], open("audio/words.json", "w"))

json.dump([dict(zip(["cut_start", "cut_end", "kind", "before", "after", "silence_was"], c)) for c in cuts], open("audio/cutmap.json", "w"), indent=1)
for cs, ce, kind, a, b, was in cuts: print(f"{cs:6.2f}  {was:.2f}s → {was-(ce-cs):.2f}s  [{kind:8}] {a} | {b}")
dur = lambda f: float(sh("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f).stdout)
print(f"removed {sum(c[1]-c[0] for c in cuts):.2f}s over {len(cuts)} pauses · vo {dur(SRC_VO):.2f}→{dur('audio/vo.wav'):.2f} · head {dur(SRC_HEAD):.2f}→{dur('head_raw.mp4'):.2f}")
