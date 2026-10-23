import sys, importlib.util
from PIL import Image
spec = importlib.util.spec_from_file_location("f", sys.argv[1]); f = importlib.util.module_from_spec(spec); spec.loader.exec_module(f)
names = sys.argv[3:]
S = 14
frames = [getattr(f, n) for n in names]
grids = [[r for r in fr.strip("\n").split("\n")] for fr in frames]
W = max(len(r) for g in grids for r in g); H = max(len(g) for g in grids)
img = Image.new("RGBA", ((W*S+20)*len(grids), H*S+20), (60, 75, 100, 255))
for k, g in enumerate(grids):
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                c = f.PAL[ch]; img.paste(Image.new("RGBA",(S,S),c), (k*(W*S+20)+10+x*S, 10+y*S))
img.save(sys.argv[2])
