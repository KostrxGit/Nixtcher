# Builds Sigurd's frames from horse_frames.py. Run: python3 make_horse.py <out-dir>
import os, sys, importlib.util
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("hf", os.path.join(here, "horse_frames.py"))
hf = importlib.util.module_from_spec(spec); spec.loader.exec_module(hf)
W, H, SCALE = 34, 24, 10  # shown at 68x48 points: crisp at 2.5x (laptop) and 1x

def grid(s):
    return [list(r.ljust(W, ".")[:W]) for r in s.strip("\n").split("\n")]

STAND, GRAZE = grid(hf.STAND), grid(hf.GRAZE)
NEAR = ["OCCO", "OCCO", "OCCO", "OSSO", "OHHO", "OOOO"]
FAR = ["OCO", "OCO", "OCO", "OSO", "OHO", "OOO"]

def legs(base, nh, fh, nf, ff):
    """Redraw the four legs (rows 18-23): far legs first, near legs over them."""
    g = [row[:] for row in base]
    for y in range(18, 24):
        g[y] = ["."] * W
    for x0, pat in ((fh, FAR), (ff, FAR), (nh, NEAR), (nf, NEAR)):
        for i, row in enumerate(pat):
            for j, ch in enumerate(row):
                g[18 + i][x0 + j] = ch
    return g

def sway_tail(g, dy):
    """Move the tail (columns 0-6, rows 9-17) down by dy rows."""
    out = [row[:] for row in g]
    for y in range(9, 18):
        for x in range(0, 6):
            out[y][x] = "."
    for y in range(9, 18):
        for x in range(0, 6):
            ch = g[y][x]
            if ch != "." and 9 <= y + dy < 18:
                out[y + dy][x] = ch
    return out

def put(g, pts, ch):
    g = [row[:] for row in g]
    for x, y in pts:
        g[y][x] = ch
    return g

frames = {
    "walk_0": legs(STAND, 6, 11, 19, 22),
    "walk_1": sway_tail(legs(STAND, 4, 12, 21, 18), 1),
    "walk_2": legs(STAND, 6, 11, 19, 22),
    "walk_3": sway_tail(legs(STAND, 8, 10, 17, 21), 1),
    "idle_0": STAND,
    "idle_1": put(put(STAND, [(28, 4), (29, 4)], "C"), [(28, 5), (29, 5)], "O"),  # blink
    "graze_0": GRAZE,
    "graze_1": put(GRAZE, [(31, 22)], "G"),
}

def to_image(g, mirror=False):
    img = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                c = hf.PAL[ch].lstrip("#")
                rgba = tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
                for yy in range(SCALE):
                    for xx in range(SCALE):
                        px[x * SCALE + xx, y * SCALE + yy] = rgba
    return img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img

def main(out):
    os.makedirs(out, exist_ok=True)
    for name, g in frames.items():
        to_image(g).save(os.path.join(out, f"{name}_r.png"))
        to_image(g, mirror=True).save(os.path.join(out, f"{name}_l.png"))
    names = list(frames)
    sheet = Image.new("RGBA", (len(names) * (W * SCALE + 8), H * SCALE + 8), (52, 64, 86, 255))
    for i, n in enumerate(names):
        im = to_image(frames[n])
        sheet.paste(im, (i * (W * SCALE + 8) + 4, 4), im)
    sheet.save(os.path.join(out, "_sheet.png"))

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "frames"))
