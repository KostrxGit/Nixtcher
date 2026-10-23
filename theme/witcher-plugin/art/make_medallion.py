# Medallion frames for each school: resting, and trembling with a glow in the school's
# colour (or red for failures). Run: python3 make_medallion.py <icons-dir> <out-dir>
import os, sys
from PIL import Image, ImageFilter

SIZE = 72
SCHOOLS = {
    "wolf": (141, 179, 226),     # sky blue
    "cat": (212, 163, 90),       # amber
    "griffin": (121, 195, 209),  # glacier teal
    "bear": (201, 139, 94),      # bronze
}
RED = (214, 98, 58)
SHAKE = [(-7, -1, 1.6), (6, 1, 2.2), (-4, 0, 1.9), (3, -1, 2.4)]

def glow(img, rgb, strength):
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(5)).point(lambda v: min(255, int(v * strength)))
    g = Image.new("RGBA", img.size, rgb + (0,))
    g.putalpha(a)
    return g

def frames(src, out, accent):
    os.makedirs(out, exist_ok=True)
    m = Image.open(src).convert("RGBA").resize((SIZE - 16, SIZE - 16), Image.LANCZOS)
    rest = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rest.paste(m, (8, 8), m)
    rest.save(os.path.join(out, "rest.png"))
    for name, rgb in (("accent", accent), ("red", RED)):
        for i, (angle, dx, strength) in enumerate(SHAKE):
            f = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            r = m.rotate(angle, resample=Image.BICUBIC)
            f.paste(r, (8 + dx, 8), r)
            Image.alpha_composite(glow(f, rgb, strength), f).save(os.path.join(out, f"hum_{name}_{i}.png"))

def main(icons, out):
    for school, accent in SCHOOLS.items():
        frames(os.path.join(icons, f"{school}.png"), os.path.join(out, school), accent)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
