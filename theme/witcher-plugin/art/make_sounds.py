# Original synthesized sounds (no game audio). Run: python3 make_sounds.py <out-dir>
import os, sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 48000
rng = np.random.default_rng(7)

def t(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, attack, release_tau):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / release_tau)

def bell(freq, sec, partials=((1, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12)), tau=0.5, attack=0.004):
    x = t(sec); out = np.zeros_like(x)
    for ratio, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * x) * np.exp(-x / (tau / ratio ** 0.5))
    return out * env(len(x), attack, 10)

def band(noise, lo, hi):
    sos = butter(4, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, noise)

def normalize(x, peak=0.6):
    return x / (np.max(np.abs(x)) + 1e-9) * peak

def fade_out(x, sec=0.05):
    n = int(SR * sec); x[-n:] *= np.linspace(1, 0, n); return x

def write(out, name, x, peak=0.6):
    x = fade_out(normalize(x, peak))
    stereo = np.stack([x, x], axis=1)
    wavfile.write(os.path.join(out, name), SR, (stereo * 32767).astype(np.int16))

# Each school's medallion hums differently: (base Hz, tremble Hz, partials)
SCHOOL_HUMS = {
    "wolf": (146.8, 11, ((1, 1.0), (2.0, 0.35), (2.76, 0.5), (5.4, 0.18))),     # D3, steady
    "cat": (196.0, 15, ((1, 1.0), (2.4, 0.45), (4.1, 0.3), (6.3, 0.15))),       # G3, quick and bright
    "griffin": (220.0, 8, ((1, 1.0), (1.5, 0.4), (3.0, 0.35), (4.5, 0.2))),     # A3, airy fifths
    "bear": (98.0, 6, ((1, 1.0), (2.0, 0.6), (3.0, 0.4), (5.2, 0.15))),         # G2, deep and slow
}

def medallion_hum(freq=146.8, trem_hz=11, partials=SCHOOL_HUMS["wolf"][2]):
    x = t(1.6)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * x)
    base = 0
    for ratio, amp in partials:
        base += amp * np.sin(2 * np.pi * freq * ratio * vib * x)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * trem_hz * x) ** 2          # the trembling
    rattle = band(rng.standard_normal(len(x)), 1800, 4200) * 0.08 * (np.sin(2 * np.pi * trem_hz * x) > 0.6)
    e = np.clip(x / 0.18, 0, 1) * np.clip((1.6 - x) / 0.6, 0, 1)
    return (base * trem + rattle) * e

def blade_shing():
    x = t(1.3)
    n = rng.standard_normal(len(x))
    scrape_len = int(SR * 0.28)
    scrape = np.zeros_like(x)
    seg = n[:scrape_len]
    # rising scrape: sweep a band upward
    parts = []
    for i in range(8):
        a, b = i * scrape_len // 8, (i + 1) * scrape_len // 8
        lo = 1500 + i * 600
        parts.append(band(seg, lo, lo + 2500)[a:b])
    scrape[:scrape_len] = np.concatenate(parts) * np.linspace(0.3, 1, scrape_len)
    ring = np.zeros_like(x)
    start = int(SR * 0.24)
    r = bell(2100, 1.3 - 0.24, partials=((1, 1), (1.62, 0.6), (2.48, 0.45), (3.9, 0.25)), tau=0.9, attack=0.002)
    ring[start:start + len(r)] = r
    return scrape * 0.5 + ring * 0.8

def notify_chime():
    a = bell(659.25, 0.9, tau=0.35)
    b = bell(987.77, 0.9, tau=0.4)
    x = np.zeros(int(SR * 1.0)); x[:len(a)] += a * 0.8
    off = int(SR * 0.11); x[off:off + len(b)] += b[: len(x) - off] * 0.7
    return x

def potion_done():
    x = np.zeros(int(SR * 1.2))
    for i, (start, f0) in enumerate([(0.0, 300), (0.12, 380), (0.22, 340), (0.33, 460), (0.45, 420)]):
        d = t(0.09); f = f0 * (1 + 2.2 * d / 0.09)          # rising "bloop"
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * d / 0.09)
        a = int(SR * start); x[a:a + len(s)] += s * 0.6
    c = bell(1318.5, 0.6, tau=0.3); a = int(SR * 0.58); x[a:a + len(c)] += c * 0.7
    return x

def potion_fail():
    x = t(1.0)
    thud = np.sin(2 * np.pi * (110 - 50 * x) * x) * np.exp(-x / 0.18)
    clank = bell(233, 1.0, partials=((1, 1), (2.31, 0.7), (3.17, 0.5)), tau=0.4) * 0.5
    return thud + clank

def scroll_unroll():
    # parchment unrolling (filtered noise in little bursts), then a soft two-note seal
    x = np.zeros(int(SR * 1.6))
    n = band(rng.standard_normal(int(SR * 0.7)), 900, 5000)
    flutter = (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t(0.7))) * np.linspace(1, 0.2, len(n))
    x[: len(n)] += n * flutter * 0.35
    a = bell(523.25, 1.0, tau=0.45)
    b = bell(783.99, 0.9, tau=0.45)
    s1 = int(SR * 0.62); x[s1:s1 + len(a)] += a[: len(x) - s1] * 0.6
    s2 = int(SR * 0.78); x[s2:s2 + len(b)] += b[: len(x) - s2] * 0.55
    return x

def break_over():
    a = bell(783.99, 0.7, tau=0.3)
    b = bell(659.25, 0.9, tau=0.4)
    x = np.zeros(int(SR * 1.0)); x[:len(a)] += a * 0.7
    off = int(SR * 0.16); x[off:off + len(b)] += b[: len(x) - off] * 0.7
    return x

def main(out):
    os.makedirs(out, exist_ok=True)
    for school, (freq, trem, partials) in SCHOOL_HUMS.items():
        write(out, f"hum-{school}.wav", medallion_hum(freq, trem, partials), 0.55)
    write(out, "scroll.wav", scroll_unroll(), 0.5)
    write(out, "break-over.wav", break_over(), 0.45)
    write(out, "blade.wav", blade_shing(), 0.5)
    write(out, "chime.wav", notify_chime(), 0.45)
    write(out, "potion-done.wav", potion_done(), 0.5)
    write(out, "potion-fail.wav", potion_fail(), 0.55)

if __name__ == "__main__":
    main(sys.argv[1])
