#!/usr/bin/env python3
"""Renders the README pictures in docs/images from the theme's own sprites.

  python3 docs/art/make_readme_images.py <cinzel-700.ttf|woff> <inter-dir>

Everything here is drawn from assets in this repo (Vesna, Sigurd, medallions, the boot
campfire, the parchment roll). Desktop screenshots are separate: see docs/screenshots.
"""

from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "docs", "images")
PUP = os.path.join(ROOT, "theme", "witcher-plugin", "assets", "pup")
MED = os.path.join(ROOT, "theme", "witcher-plugin", "assets", "medallion")
HORSE = os.path.join(ROOT, "theme", "sigurd", "frames")
BOOT = os.path.join(ROOT, "theme", "plymouth")
ROLL = os.path.join(ROOT, "theme", "witcher-plugin", "assets", "scroll", "roll.png")

CINZEL = sys.argv[1] if len(sys.argv) > 1 else "Cinzel-Bold.ttf"
INTER = sys.argv[2] if len(sys.argv) > 2 else "/usr/share/fonts/opentype/inter"

# palette (theme/palette.nix, dark)
BG = (22, 28, 38)
SURFACE = (31, 39, 51)
OUTLINE = (46, 58, 76)
MUTED = (95, 110, 134)
ICE = (154, 176, 201)
FROST = (222, 229, 238)
ACCENT = (141, 179, 226)
ORANGE = (217, 137, 74)
MOSS = (141, 175, 94)
INK = (74, 53, 32)
FADED = (122, 92, 58)
PARCH = (234, 219, 184)


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    if kind == "title":
        return ImageFont.truetype(CINZEL, size)
    name = {"regular": "Inter-Regular.otf", "medium": "Inter-Medium.otf", "semibold": "Inter-SemiBold.otf",
            "bold": "Inter-Bold.otf"}[kind]
    return ImageFont.truetype(os.path.join(INTER, name), size)


def sprite(path: str, scale: float) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    return im.resize((round(im.width * scale), round(im.height * scale)), Image.NEAREST)


def rounded(size, radius, fill, outline=None, width=1) -> Image.Image:
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=fill,
                                         outline=outline, width=width)
    return im


def glass(base: Image.Image, box, radius=22):
    """Frosted glass card: blur what's behind, tint, thin bright edge, soft shadow."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x0, y0 + 10, x1, y1 + 10), radius, fill=(5, 8, 14, 150))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    region = base.crop(box).filter(ImageFilter.GaussianBlur(14))
    mask = rounded((w, h), radius, (255, 255, 255, 255)).split()[3]
    base.paste(region, (x0, y0), mask)
    base.alpha_composite(rounded((w, h), radius, (*SURFACE, 205), (*FROST, 50), 2), (x0, y0))


def night_sky(w: int, h: int, seed=7, moon=True, ridges=True) -> Image.Image:
    rnd = random.Random(seed)
    im = Image.new("RGBA", (w, h))
    px = ImageDraw.Draw(im)
    top, mid, low = (17, 22, 40), (30, 38, 66), (22, 28, 38)
    for y in range(h):
        t = y / h
        a, b, u = (top, mid, t / 0.6) if t < 0.6 else (mid, low, (t - 0.6) / 0.4)
        px.line([(0, y), (w, y)], fill=tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3)) + (255,))
    stars = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stars)
    for _ in range(w * h // 2600):
        x, y = rnd.randrange(w), rnd.randrange(int(h * 0.7))
        r = rnd.choice([1, 1, 1, 2])
        sd.ellipse((x, y, x + r, y + r), fill=(234, 240, 246, rnd.randrange(90, 230)))
    im.alpha_composite(stars)
    if moon:
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        mx, my, mr = int(w * 0.82), int(h * 0.22), int(h * 0.09)
        ImageDraw.Draw(glow).ellipse((mx - mr * 4, my - mr * 4, mx + mr * 4, my + mr * 4), fill=(141, 179, 226, 40))
        im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(mr * 2)))
        ImageDraw.Draw(im).ellipse((mx - mr, my - mr, mx + mr, my + mr), fill=(236, 230, 214, 255))
        ImageDraw.Draw(im).ellipse((mx - mr * 0.45, my - mr * 0.3, mx - mr * 0.1, my + mr * 0.05), fill=(222, 214, 196, 255))
    if ridges:
        layers = [((40, 52, 78), 0.52, 0.18, 3), ((31, 40, 60), 0.62, 0.14, 5), ((24, 31, 45), 0.74, 0.1, 9)]
        for color, base_y, amp, n in layers:
            pts = [(0, h)]
            peaks = [(i / n * w + rnd.uniform(-w / n / 3, w / n / 3), h * (base_y - rnd.uniform(0.3, 1.0) * amp))
                     for i in range(-1, n + 2)]
            for i in range(len(peaks) - 1):
                (ax, ay), (bx, by) = peaks[i], peaks[i + 1]
                vx, vy = (ax + bx) / 2, h * base_y + rnd.uniform(0, amp * h * 0.3)
                pts += [(ax, ay), (vx, vy)]
            pts += [peaks[-1], (w, h)]
            ImageDraw.Draw(im).polygon(pts, fill=color + (255,))
    return im


def snowfall(im: Image.Image, seed=3, n=None):
    rnd = random.Random(seed)
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n or im.width * im.height // 9000):
        x, y, r = rnd.randrange(im.width), rnd.randrange(im.height), rnd.choice([1.5, 2, 2.5, 3])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(246, 249, 252, rnd.randrange(60, 170)))
    im.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))


def text_center(d: ImageDraw.ImageDraw, cx, y, text, f, fill):
    w = d.textlength(text, font=f)
    d.text((cx - w / 2, y), text, font=f, fill=fill)


# ── banner ────────────────────────────────────────────────────────────────────
def banner():
    W, H = 1600, 560
    im = night_sky(W, H, seed=11)
    ground = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(ground).rectangle((0, H - 70, W, H), fill=(18, 23, 32, 255))
    ImageDraw.Draw(ground).line((0, H - 70, W, H - 70), fill=(46, 58, 76, 255), width=2)
    im.alpha_composite(ground)
    snowfall(im)

    # title with a cold glow
    d = ImageDraw.Draw(im)
    title = "KAER MORHEN"
    tf = font("title", 112)
    tw = d.textlength(title, font=tf)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text(((W - tw) / 2, 120), title, font=tf, fill=(141, 179, 226, 170))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(16)))
    d = ImageDraw.Draw(im)
    d.text(((W - tw) / 2, 120), title, font=tf, fill=FROST)
    text_center(d, W / 2, 262, "A NixOS desktop for witchers who write code", font("medium", 30), ICE)
    text_center(d, W / 2, 312, "Niri  ·  Noctalia  ·  liquid glass  ·  a wolf pup  ·  a pony  ·  Claude agents",
                font("regular", 20), MUTED)

    # Vesna by the campfire (boot art) on the left, Sigurd grazing on the right
    fire = Image.open(os.path.join(BOOT, "fire-1.png")).convert("RGBA")
    fire = fire.resize((fire.width // 2, fire.height // 2), Image.NEAREST)
    im.alpha_composite(fire, (120, H - 70 - fire.height + 18))
    horse = sprite(os.path.join(HORSE, "graze_0_l.png"), 0.6)
    im.alpha_composite(horse, (W - 330, H - 70 - horse.height + 6))
    return im


def save_gif(frames, name, ms):
    """One shared palette for every frame, so colours don't flicker between frames."""
    sheet = Image.new("RGB", (frames[0].width, frames[0].height * 3))
    for i, k in enumerate((0, len(frames) // 2, len(frames) * 3 // 5)):
        sheet.paste(frames[k], (0, frames[0].height * i))
    pal = sheet.quantize(96, dither=Image.Dither.NONE)
    out = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    out[0].save(os.path.join(OUT, name), save_all=True, append_images=out[1:], duration=ms, loop=0, optimize=True)


# ── Vesna's moods (animated) ──────────────────────────────────────────────────
MOODS = [
    ("Patrols", ["walk_0", "walk_1", "walk_2", "walk_3"], 1),
    ("Keeps watch", ["sit_0"] * 7 + ["sit_1"], 1),
    ("Hops", ["hop_0", "hop_1", "hop_2", "hop_1", "hop_0", "sit_0"], 1),
    ("Howls", ["howl_0", "howl_1"], 3),
    ("Naps", ["sleep_0", "sleep_1"], 4),
    ("Meditates", ["meditate_0", "meditate_1"], 4),
    ("Pants", ["pant_0", "pant_1"], 2),
    ("Hears you", ["alert_0"], 1),
    ("Droops", ["sad_0"], 1),
]


def vesna_gif():
    tile_w, tile_h, scale = 150, 190, 2
    cols = 9
    W, H = tile_w * cols + 20, tile_h + 20
    bg = night_sky(W, H, seed=5, moon=False, ridges=False)
    frames = []
    for t in range(24):
        im = bg.copy()
        d = ImageDraw.Draw(im)
        for i, (label, seq, hold) in enumerate(MOODS):
            x0 = 10 + i * tile_w
            im.alpha_composite(rounded((tile_w - 10, tile_h - 10), 18, (*SURFACE, 215), (*FROST, 40), 2), (x0 + 5, 15))
            name = seq[(t // hold) % len(seq)]
            spr = sprite(os.path.join(PUP, f"{name}_r.png"), scale)
            im.alpha_composite(spr, (x0 + (tile_w - spr.width) // 2, 30))
            text_center(d, x0 + tile_w / 2, tile_h - 22, label, font("semibold", 15), ICE)
        frames.append(im.convert("RGB"))
    save_gif(frames, "vesna.gif", 130)


# ── Sigurd trots in with a message (animated) ─────────────────────────────────
def sigurd_gif():
    W, H, ground = 960, 260, 236
    bg = night_sky(W, H, seed=21, moon=False)
    ImageDraw.Draw(bg).rectangle((0, ground, W, H), fill=(18, 23, 32, 255))
    snowfall(bg, seed=9, n=140)
    horse = {name[:-4]: sprite(os.path.join(HORSE, name), 0.4) for name in os.listdir(HORSE) if name.endswith(".png")}
    hw, hh = horse["walk_0_r"].size
    stop = 430
    frames = []
    x, t, state = -hw, 0, "walk"
    msg = "The Swallow potion is ready! Brewed in 4 min."
    while True:
        im = bg.copy()
        if state == "walk":
            name = f"walk_{t % 4}_r"
            x += 9
            if x >= stop:
                state, pause = "talk", 0
        elif state == "talk":
            name = "idle_1_r" if pause % 18 == 0 else "idle_0_r"
            pause += 1
            if pause > 34:
                state, pause = "graze", 0
        elif state == "graze":
            name = f"graze_{(pause // 4) % 2}_r"
            pause += 1
            if pause > 22:
                state = "leave"
        else:
            name = f"walk_{t % 4}_r"
            x += 9
            if x > W + 10:
                break
        im.alpha_composite(horse[name], (int(x), ground - hh + 4))
        if state in ("talk", "graze"):
            d = ImageDraw.Draw(im)
            f = font("medium", 15)
            tw = d.textlength(msg, font=f)
            bw, bh = int(tw) + 30, 60
            bx, by = int(x + hw / 2 - bw / 2), ground - hh - bh - 6
            im.alpha_composite(rounded((bw, bh), 14, (*SURFACE, 235), (*FROST, 60), 1), (bx, by))
            d.text((bx + 15, by + 10), msg, font=f, fill=FROST)
            pill = rounded((92, 20), 9, (*ACCENT, 255))
            im.alpha_composite(pill, (bx + 15, by + 34))
            text_center(d, bx + 15 + 46, by + 35, "Thanks!", font("semibold", 12), BG)
        frames.append(im.convert("RGB"))
        t += 1
    save_gif(frames, "sigurd.gif", 70)


# ── the four schools ──────────────────────────────────────────────────────────
SCHOOLS = [("wolf", "Wolf", ACCENT), ("cat", "Cat", (212, 163, 90)), ("griffin", "Griffin", (121, 195, 209)),
           ("bear", "Bear", (201, 139, 94))]


def schools():
    W, H = 1200, 300
    im = night_sky(W, H, seed=2, moon=False, ridges=False)
    d = ImageDraw.Draw(im)
    for i, (key, label, color) in enumerate(SCHOOLS):
        cx = 150 + i * 300
        glass(im, (cx - 125, 25, cx + 125, H - 25))
        d = ImageDraw.Draw(im)
        med = sprite(os.path.join(MED, key, "hum_accent_2.png"), 1.6)
        im.alpha_composite(med, (cx - med.width // 2, 50))
        text_center(d, cx, 180, f"School of the {label}", font("title", 22), FROST)
        for k in range(5):
            shade = tuple(round(c * (0.55 + k * 0.12)) for c in color)
            d.rounded_rectangle((cx - 85 + k * 36, 222, cx - 85 + k * 36 + 28, 250), 7, fill=min_rgb(shade))
    return im


def min_rgb(c):
    return tuple(min(255, v) for v in c)


# ── panels: encounter, badge, contract-complete scroll ────────────────────────
def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if d.textlength(test, font=f) <= width:
            cur = test
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def card(im, x, y, w, title, text, buttons, icon_color=ACCENT):
    d = ImageDraw.Draw(im)
    body = wrap(d, text, font("regular", 16), w - 44)
    h = 92 + len(body) * 24 + 52
    glass(im, (x, y, x + w, y + h))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x + 22, y + 26, x + 27, y + 50), 3, fill=icon_color)
    d.text((x + 40, y + 22), title, font=font("title", 22), fill=FROST)
    for i, line in enumerate(body):
        d.text((x + 22, y + 68 + i * 24), line, font=font("regular", 16), fill=FROST)
    bx = x + w - 22
    for label, primary in reversed(buttons):
        f = font("semibold", 15)
        bw = int(d.textlength(label, font=f)) + 34
        bx -= bw
        if primary:
            im.alpha_composite(rounded((bw, 36), 12, (*ACCENT, 255)), (bx, y + h - 54))
            d.text((bx + 17, y + h - 46), label, font=f, fill=BG)
        else:
            d.text((bx + 17, y + h - 46), label, font=f, fill=ICE)
        bx -= 10
    return h


def scroll_panel(im, x, y):
    roll = Image.open(ROLL).convert("RGBA")
    w = roll.width
    d = ImageDraw.Draw(im)
    body_h = 200
    ImageDraw.Draw(im).rectangle((x + 20, y + 18, x + w - 20, y + 18 + body_h), fill=PARCH)
    im.alpha_composite(roll, (x, y))
    im.alpha_composite(roll, (x, y + body_h + 10))
    cx = x + w / 2
    text_center(d, cx, y + 46, "CONTRACT COMPLETE", font("title", 26), INK)
    d.line((cx - 150, y + 90, cx + 150, y + 90), fill=FADED, width=1)
    text_center(d, cx, y + 104, "Focus session 3 · 25 minutes", font("regular", 17), INK)
    text_center(d, cx, y + 134, "Vesna kept watch. Rest for 5 minutes.", font("regular", 15), FADED)
    text_center(d, cx, y + 166, "Today: 3 contracts · 1 h 15 min", font("semibold", 15), INK)


def panels():
    W, H = 1400, 470
    im = night_sky(W, H, seed=13)
    snowfall(im, seed=4, n=160)
    card(im, 40, 40, 420, "A merchant hails you",
         "Two meditations: finish two focus sessions today. Reward: 15 crowns.", [("Not now", False), ("Accept", True)])
    card(im, 40, 250, 420, "Contract: Drowner",
         "Delete one merged branch (git branch --merged). Reward: 10 crowns.",
         [("Not now", False), ("Take the contract", True)], ORANGE)
    scroll_panel(im, 500, 110)
    card(im, 960, 40, 400, "A mysterious traveller",
         "Every monster has a weakness. Every bug has a stack trace. Read it twice.", [("Thanks", True)], MUTED)
    card(im, 960, 250, 400, "A bard sings of your deeds",
         "Three Days on the Path: focused on three days in a row. +20 crowns.", [("Splendid", True)], MOSS)
    return im


def boot():
    # the real Plymouth pieces, laid out like the boot screen
    W, H = 1200, 750
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(round(22 - 10 * t), round(28 - 12 * t), round(38 - 16 * t), 255))
    med = Image.open(os.path.join(BOOT, "medallion.png")).convert("RGBA").resize((130, 130), Image.LANCZOS)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W / 2 - 90, 150, W / 2 + 90, 330), fill=(141, 179, 226, 90))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30)))
    im.alpha_composite(med, (W // 2 - 65, 175))
    fire = Image.open(os.path.join(BOOT, "fire-2.png")).convert("RGBA")
    fire = fire.resize((fire.width * 9 // 20, fire.height * 9 // 20), Image.NEAREST)
    im.alpha_composite(fire, (W // 2 - fire.width // 2, 345))
    text_center(d, W / 2, 568, "Please enter passphrase for disk cryptroot:", font("regular", 20), FROST)
    entry = Image.open(os.path.join(BOOT, "entry.png")).convert("RGBA")
    k = 270 / entry.width
    entry = entry.resize((270, round(entry.height * k)), Image.LANCZOS)
    im.alpha_composite(entry, (W // 2 - entry.width // 2, 610))
    bullet = Image.open(os.path.join(BOOT, "bullet.png")).convert("RGBA")
    bullet = bullet.resize((max(6, round(bullet.width * k)), max(6, round(bullet.height * k))), Image.LANCZOS)
    for i in range(8):
        im.alpha_composite(bullet, (W // 2 - 8 * 9 + i * 18, 610 + entry.height // 2 - bullet.height // 2))
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    banner().convert("RGB").save(os.path.join(OUT, "banner.png"), optimize=True)
    schools().convert("RGB").save(os.path.join(OUT, "schools.png"), optimize=True)
    panels().convert("RGB").save(os.path.join(OUT, "encounters.png"), optimize=True)
    boot().convert("RGB").save(os.path.join(OUT, "boot.png"), optimize=True)
    vesna_gif()
    sigurd_gif()
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
