# Parchment scroll rolls (contract complete panel) and Plymouth boot assets.
# Run: python3 make_scroll_and_boot.py <plugin-assets-dir> <plymouth-out-dir> <wolf.png>
import os, sys, importlib.util
from PIL import Image, ImageDraw, ImageFilter

here = os.path.dirname(os.path.abspath(__file__))

def roll(width, height):
    """A rolled parchment edge: shaded cylinder with dark wooden knobs."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    knob = height
    top, bot = (240, 226, 194), (176, 150, 104)
    for y in range(height):
        k = y / (height - 1)
        shade = 1 - abs(k - 0.35) * 1.1
        c = tuple(int(bot[i] + (top[i] - bot[i]) * max(0, shade)) for i in range(3))
        d.line([(knob // 2, y), (width - knob // 2, y)], fill=c + (255,))
    d.rectangle([knob // 2, 0, width - knob // 2, height - 1], outline=(110, 86, 52, 255))
    for x0 in (0, width - knob):
        d.ellipse([x0, 1, x0 + knob - 1, height - 2], fill=(92, 62, 38, 255), outline=(52, 34, 20, 255))
        d.ellipse([x0 + knob // 4, height // 4, x0 + knob // 2, height // 2], fill=(140, 102, 66, 255))
    return img

def boot(out, wolf, pup_mod):
    os.makedirs(out, exist_ok=True)
    # medallion with a soft sky-blue glow
    m = Image.open(wolf).convert("RGBA").resize((420, 420), Image.LANCZOS)
    canvas = Image.new("RGBA", (520, 520), (0, 0, 0, 0))
    canvas.paste(m, (50, 50), m)
    a = canvas.getchannel("A").filter(ImageFilter.GaussianBlur(22)).point(lambda v: min(255, int(v * 1.3)))
    g = Image.new("RGBA", canvas.size, (141, 179, 226, 0)); g.putalpha(a)
    Image.alpha_composite(g, canvas).save(os.path.join(out, "medallion.png"))
    # pup by the campfire, sharp pixels
    for i, fr in enumerate(pup_mod.campfire_frames()):
        # 720x440: the exact size on a 2400 px tall screen, so Plymouth doesn't blur the pixels
        pup_mod.to_gif_frame(fr, scale=20).save(os.path.join(out, f"fire-{i}.png"))
    # password field
    w, h = 1100, 120
    box = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(box).rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 2,
                                          fill=(31, 39, 51, 210), outline=(141, 179, 226, 200), width=4)
    box.save(os.path.join(out, "entry.png"))
    # bullet (drawn, so it doesn't depend on fonts in the initrd)
    b = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    ImageDraw.Draw(b).ellipse([6, 6, 33, 33], fill=(222, 229, 238, 255))
    b.save(os.path.join(out, "bullet.png"))

def main(assets, plymouth_out, wolf):
    os.makedirs(os.path.join(assets, "scroll"), exist_ok=True)
    roll(420, 26).save(os.path.join(assets, "scroll", "roll.png"))
    spec = importlib.util.spec_from_file_location("mp", os.path.join(here, "make_pup.py"))
    mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)
    boot(plymouth_out, wolf, mp)

if __name__ == "__main__":
    main(*sys.argv[1:4])
