# Builds the pup animation frames and the lock-screen campfire GIF from pup_frames.py.
# Run: python3 make_pup.py <out-dir>   (needs Pillow)
import os, sys, importlib.util
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("pf", os.path.join(here, "pup_frames.py"))
pf = importlib.util.module_from_spec(spec); spec.loader.exec_module(pf)
PAL = pf.PAL
W, H, TOP = 24, 22, 4          # canvas; TOP = empty rows above the pup for jumps/effects
SCALE = 3

def grid(s):
    rows = [r.ljust(W, ".") for r in s.strip("\n").split("\n")]
    return [list(r) for r in rows]

def canvas():
    return [["."] * W for _ in range(H)]

def place(dst, src, dx=0, dy=0):
    for y, row in enumerate(src):
        for x, ch in enumerate(row):
            if ch != ".":
                X, Y = x + dx, y + dy + TOP
                if 0 <= X < W and 0 <= Y < H:
                    dst[Y][X] = ch
    return dst

def put(g, pts, ch):
    for x, y in pts:
        g[y][x] = ch
    return g

def stamp(dst, pattern, x0, y0):
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch != "." and 0 <= y0 + y < H and 0 <= x0 + x < W:
                dst[y0 + y][x0 + x] = ch
    return dst

STAND, SIT, LIE, HOWL = (grid(pf.STAND), grid(pf.SIT), grid(pf.LIE), grid(pf.HOWL))

LEGS = {
    "neutral": ["...OGO.OGO..OGO.OGO.....", "...ODO.ODO..ODO.ODO.....", "...OOO.OOO..OOO.OOO....."],
    "spread":  ["..OGO...OGO.OGO...OGO...", "..ODO...ODO.ODO...ODO...", "..OOO...OOO.OOO...OOO..."],
    "together":["....OGOOGO....OGOOGO....", "....ODOODO....ODOODO....", "....OOOOOO....OOOOOO...."],
    "tucked":  ["...OGO.OGO..OGO.OGO.....", "...OOO.OOO..OOO.OOO.....", "........................"],
}

def stand(legs="neutral", tail_down=False):
    g = [row[:] for row in STAND]
    for i, r in enumerate(LEGS[legs]):
        g[15 + i] = list(r.ljust(W, "."))
    if tail_down:  # tail wag: drop the tail tip one row
        tail = [[g[y][x] for x in range(5)] for y in range(5, 9)]
        for y in range(5, 9):
            for x in range(5):
                if g[y][x] != "." and (x < 4 or y < 8):
                    g[y][x] = "."
        for y in range(5, 9):
            for x in range(5):
                ch = tail[y - 5][x]
                if ch != "." and y + 1 < 9:
                    g[y + 1][x] = ch
    return g

def sit(eyes="open", tongue=False, droopy=False):
    g = [row[:] for row in SIT]
    if eyes in ("closed", "half"):
        put(g, [(15, 5), (16, 5)], "G")
        if eyes == "closed":
            put(g, [(15, 6), (16, 6)], "C")
    if tongue:
        put(g, [(19, 9), (20, 9), (19, 10)], "P")
    if droopy:  # ears folded back
        g[0] = list("." * W); g[1] = list("." * W)
        g[2] = list("..........OKKO.OKKO.....")
    return g

Z_SMALL = ["ZZ", ".Z", "ZZ"]
Z_BIG = ["ZZZ", "..Z", ".Z.", "Z..", "ZZZ"]
HEART = [".P.P.", "PPPPP", ".PPP.", "..P.."]
BANG = ["Z", "Z", "Z", ".", "Z"]
NOTE = ["..ZZ", "..Z.", "..Z.", "ZZZ.", "ZZ.."]
DROP = ["Z", "Z"]

frames = {}
# walk cycle (bob up 1px on the stride frames)
frames["walk_0"] = place(canvas(), stand("neutral"))
frames["walk_1"] = place(canvas(), stand("spread", tail_down=True), dy=-1)
frames["walk_2"] = place(canvas(), stand("neutral"))
frames["walk_3"] = place(canvas(), stand("together", tail_down=True), dy=-1)
# idle
frames["sit_0"] = place(canvas(), sit())
frames["sit_1"] = place(canvas(), sit("closed"))
# sleep with drifting z's
frames["sleep_0"] = stamp(place(canvas(), LIE), Z_SMALL, 19, 3)
frames["sleep_1"] = stamp(place(canvas(), LIE), Z_BIG, 20, 0)
# hot: panting with a sweat drop
frames["pant_0"] = stamp(place(canvas(), sit(tongue=True)), DROP, 8, 4)
frames["pant_1"] = stamp(place(canvas(), sit(tongue=True, eyes="half")), DROP, 8, 6)
# alert: notification arrived
frames["alert_0"] = stamp(place(canvas(), stand("neutral")), BANG, 22, 0)
# happy hop
frames["hop_0"] = place(canvas(), stand("together"))
frames["hop_1"] = stamp(place(canvas(), stand("tucked"), dy=-3), HEART, 18, 0)
frames["hop_2"] = stamp(place(canvas(), stand("tucked"), dy=-2), HEART, 18, 0)
# sad
frames["sad_0"] = stamp(place(canvas(), sit("half", droopy=True)), DROP, 14, 12)
# meditation (focus timer): eyes closed, a soft aura that breathes
AURA_A = [(3, 11), (7, 5), (22, 2), (23, 12)]
AURA_B = [(2, 9), (6, 3), (23, 4), (22, 13), (4, 14)]
frames["meditate_0"] = put(place(canvas(), sit("closed")), [(x, y + TOP) for x, y in AURA_A if 0 <= y + TOP < H], "Z")
frames["meditate_1"] = put(place(canvas(), sit("closed")), [(x, y + TOP) for x, y in AURA_B if 0 <= y + TOP < H], "Z")
# howl (midnight, or click trick)
frames["howl_0"] = place(canvas(), HOWL)
frames["howl_1"] = stamp(place(canvas(), HOWL), NOTE, 1, 0)

def to_image(g, scale=SCALE, mirror=False):
    img = Image.new("RGBA", (W * scale, H * scale), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                c = PAL[ch].lstrip("#")
                rgba = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
                for yy in range(scale):
                    for xx in range(scale):
                        px[x * scale + xx, y * scale + yy] = rgba
    return img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img

# ── Lock screen: pup meditating by a campfire (looping GIF) ──────────────────
FIRE = [
    [".....Y......", "....YRY.....", "....RYR..Y..", "...RYYYR....", "..RRYYYYR...", "..RYYWYYRR..", ".RRYYWWYYRR.", ".RYYYWWYYYR."],
    ["......Y.....", ".....YR.....", "...Y.RYR....", "....RYYYR...", "...RYYYYRR..", "..RRYYWYYR..", ".RRYYWWYYRR.", ".RYYYWWYYYR."],
    ["....Y.......", "....RY...Y..", "...RYRY.....", "...RYYYR....", "..RYYYYYRR..", "..RRYWYYYR..", ".RRYYWWYYRR.", ".RYYYWWYYYR."],
    [".......Y....", ".....YRY....", "....RYYR....", "...RRYYYR...", "...RYYYYR...", "..RRYYWYYRR.", ".RRYYWWYYRR.", ".RYYYWWYYYR."],
]
LOGS = ["OOFFFFFFFFOO", ".OFFFOOFFFO."]
PAL["F"] = "#7A5236"

def campfire_frames():
    out = []
    for i, flame in enumerate(FIRE):
        g = [["."] * 36 for _ in range(H)]
        pup = sit("closed")
        for y, row in enumerate(pup):
            for x, ch in enumerate(row):
                if ch != ".":
                    g[y + TOP][x] = ch
        # fire to the right of the pup, on the ground line
        for y, row in enumerate(flame):
            for x, ch in enumerate(row):
                if ch != ".":
                    g[H - 2 - len(flame) + y][22 + x] = ch
        for y, row in enumerate(LOGS):
            for x, ch in enumerate(row):
                if ch != ".":
                    g[H - 2 + y][22 + x] = ch
        # a spark drifting up
        sy = [7, 5, 3, 9][i]
        g[sy][27 + (i % 2)] = "Y"
        out.append(g)
    return out

def to_gif_frame(g, scale=4):
    w = len(g[0]); img = Image.new("RGBA", (w * scale, H * scale), (0, 0, 0, 0)); px = img.load()
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                c = PAL[ch].lstrip("#"); rgba = tuple(int(c[k:k + 2], 16) for k in (0, 2, 4)) + (255,)
                for yy in range(scale):
                    for xx in range(scale):
                        px[x * scale + xx, y * scale + yy] = rgba
    return img

def main(out):
    os.makedirs(out, exist_ok=True)
    for name, g in frames.items():
        to_image(g).save(os.path.join(out, f"{name}_r.png"))
        to_image(g, mirror=True).save(os.path.join(out, f"{name}_l.png"))
    imgs = [to_gif_frame(g) for g in campfire_frames()]
    pal_imgs = []
    for im in imgs:
        p = im.convert("RGBA")
        alpha = p.getchannel("A")
        q = p.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=63)
        mask = Image.eval(alpha, lambda a: 255 if a < 128 else 0)
        q.paste(63, mask)
        pal_imgs.append(q)
    pal_imgs[0].save(os.path.join(out, "campfire.gif"), save_all=True, append_images=pal_imgs[1:],
                     duration=180, loop=0, transparency=63, disposal=2)
    # contact sheet for checking
    names = list(frames)
    sheet = Image.new("RGBA", (len(names) * (W * 4 + 8), H * 4 + 8), (52, 64, 86, 255))
    for i, n in enumerate(names):
        sheet.paste(to_image(frames[n], 4), (i * (W * 4 + 8) + 4, 4), to_image(frames[n], 4))
    sheet.save(os.path.join(out, "_sheet.png"))

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "assets", "pup"))
