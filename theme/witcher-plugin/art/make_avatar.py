#!/usr/bin/env python3
"""Vesna's portrait for the shell avatar (launcher, lock screen): the pup sitting in the
snow under a night sky, as a square that the shell crops into a circle.

  python3 art/make_avatar.py      → assets/avatar.png (512x512)
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
PUP = os.path.join(HERE, "..", "assets", "pup", "sit_0_r.png")
OUT = os.path.join(HERE, "..", "assets", "avatar.png")
SIZE = 512

im = Image.new("RGBA", (SIZE, SIZE))
d = ImageDraw.Draw(im)
top, low = (24, 32, 58), (40, 54, 84)
for y in range(SIZE):
    t = y / SIZE
    d.line([(0, y), (SIZE, y)], fill=tuple(round(top[i] + (low[i] - top[i]) * t) for i in range(3)) + (255,))

rnd = random.Random(4)
stars = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(stars)
for _ in range(70):
    x, y, r = rnd.randrange(SIZE), rnd.randrange(int(SIZE * 0.6)), rnd.choice([2, 2, 3, 4])
    sd.ellipse((x, y, x + r, y + r), fill=(234, 240, 246, rnd.randrange(110, 230)))
im.alpha_composite(stars)

# moon glow behind her head
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((150, 70, 400, 320), fill=(141, 179, 226, 70))
im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(50)))

# snowy ground
d = ImageDraw.Draw(im)
d.ellipse((-120, 380, SIZE + 120, 700), fill=(214, 224, 236, 255))
d.ellipse((-80, 400, SIZE + 80, 720), fill=(234, 240, 246, 255))

# the pup: sprite pixels are 3x3 in the asset, rebuild 1:1 and scale up crisply
pup = Image.open(PUP).convert("RGBA")
base = pup.resize((pup.width // 3, pup.height // 3), Image.NEAREST)
scale = 13
big = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
bbox = big.getbbox()
big = big.crop(bbox)
x = (SIZE - big.width) // 2 - 6
y = 430 - big.height
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse((x + 10, 410, x + big.width - 10, 450), fill=(60, 80, 110, 90))
im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
im.alpha_composite(big, (x, y))

im.convert("RGB").save(OUT, optimize=True)
print("wrote", OUT, big.size)
