#!/usr/bin/env python3
"""Karaoke captions (active word in your accent color) from audio/words.json -> out/caption_track.mov (qtrle RGBA)."""
import json, os, subprocess
from PIL import Image, ImageDraw, ImageFont
W, H, FPS = 1080, 1920, 30
CFG = json.load(open(os.path.join(os.environ.get("AVATAR_REEL_HOME", os.path.expanduser("~/.config/avatar-reel")), "config.json")))
FONT = next((f for f in [CFG.get("caption_font", ""), "/System/Library/Fonts/Supplemental/Arial Black.ttf",
             "/usr/share/fonts/truetype/msttcorefonts/Arial_Black.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"] if f and os.path.exists(f)), None)
if not FONT: raise SystemExit("No caption font found: set caption_font (a heavy .ttf) in config.json")
_a = CFG.get("accent", "#00BF63").lstrip("#")
GREEN = tuple(int(_a[i:i + 2], 16) for i in (0, 2, 4)) + (255,); WHITE = (255, 255, 255, 255); BLACK = (0, 0, 0, 255)
YC = 1745
CAP = "out/caps"; os.makedirs(CAP, exist_ok=True)
raw = json.load(open("audio/words.json"))
# display fixes: TTS spellings -> on-screen words
words, i = [], 0
while i < len(raw):
    w = dict(raw[i]); t = w["text"]
    seq = [x["text"].strip(',."') for x in raw[i:i+5]]
    if seq[:3] == ["Jason", "L", "D"]: w["text"] = "JSON-LD"; w["end"] = raw[i+2]["end"]; i += 3; words.append(w); continue
    if seq[:5] == ["robots", "dot", "T", "X", "T"]: w["text"] = "robots.txt"; w["end"] = raw[i+4]["end"]; i += 5; words.append(w); continue
    w["text"] = t.replace("A.I.", "AI").replace('"', "")
    words.append(w); i += 1
phrases, cur = [], []
for w in words:
    cur.append(w); tok = w["text"]
    if tok.endswith((".", "!", "?", ":")) or len(cur) >= 4 or (tok.endswith(",") and len(cur) >= 2):
        phrases.append(cur); cur = []
if cur: phrases.append(cur)
def F(sz): return ImageFont.truetype(FONT, sz)
d0 = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
def render(ph, active, key):
    p = f"{CAP}/{key}.png"
    toks = [w["text"].upper() for w in ph]; text = " ".join(toks); maxw = W - 140
    sz = 76
    while sz > 46 and d0.textlength(text, font=F(sz)) > maxw * 1.9: sz -= 2
    f = F(sz); stroke = max(7, sz // 9); sp = d0.textlength(" ", font=f)
    lines, line, lw = [], [], 0.0
    for i, t in enumerate(toks):
        tw = d0.textlength(t, font=f)
        if line and lw + sp + tw > maxw: lines.append(line); line, lw = [], 0.0
        line.append(i); lw += (sp if len(line) > 1 else 0) + tw
    if line: lines.append(line)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), "Ag", font=f, stroke_width=stroke); lh = (bb[3] - bb[1]) + 14
    y = YC - lh * len(lines) // 2
    for ln in lines:
        lw = sum(d0.textlength(toks[i], font=f) for i in ln) + sp * (len(ln) - 1); x = (W - lw) / 2
        for i in ln:
            d.text((x, y), toks[i], font=f, fill=GREEN if i == active else WHITE, stroke_width=stroke, stroke_fill=BLACK)
            x += d0.textlength(toks[i], font=f) + sp
        y += lh
    img.save(p); return p
Image.new("RGBA", (W, H), (0, 0, 0, 0)).save(f"{CAP}/_blank.png")
segs, cur_t = [], 0.0
for pi, ph in enumerate(phrases):
    ps = ph[0]["start"]; pe = phrases[pi+1][0]["start"] if pi + 1 < len(phrases) else ph[-1]["end"] + 0.4
    pe = min(pe, ph[-1]["end"] + 0.6)
    if ps > cur_t: segs.append((f"{CAP}/_blank.png", ps - cur_t)); cur_t = ps
    for wi, w in enumerate(ph):
        se = ph[wi+1]["start"] if wi + 1 < len(ph) else pe
        se = max(se, cur_t + 0.04); segs.append((render(ph, wi, f"p{pi}_w{wi}"), se - cur_t)); cur_t = se
segs.append((f"{CAP}/_blank.png", 1.0))
with open("out/caps_list.txt", "w") as fh:
    for p, du in segs: fh.write(f"file '{os.path.abspath(p)}'\nduration {max(du,0.02):.3f}\n")
    fh.write(f"file '{os.path.abspath(segs[-1][0])}'\n")
subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", "out/caps_list.txt",
                "-vf", f"fps={FPS},format=rgba", "-c:v", "qtrle", "out/caption_track.mov"], check=True)
print("captions:", len(phrases), "phrases")
