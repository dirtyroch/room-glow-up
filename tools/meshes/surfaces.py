"""Tileable room-shell textures (floors and walls) for MaterialVariants / Textures.

python3 tools/meshes/surfaces.py
Writes assets/surfaces/<key>/{color,normal,roughness}.png (1024, tileable) and
assets/surfaces/surfaces.json. Colour maps are light and nearly neutral: the
part Color (theme pack or Designer Tools paint) tints them in game.
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "surfaces")
N = 1024
rng = np.random.default_rng(11)

# key: (MaterialVariant name, base Material, studs per tile)
SPECS = {
    "planks": ("RGU Planks", "WoodPlanks", 8),
    "tile": ("RGU Tile", "CeramicTiles", 4),
    "carpet": ("RGU Carpet", "Carpet", 4),
    "plaster": ("RGU Plaster", "Plaster", 8),
    "stripe": ("RGU Stripe", "Plaster", 8),
    "sprig": ("RGU Sprig", "Plaster", 4),
}


def tile_noise(scale, octaves=4, seed=0, stretch=(1, 1)):
    """Periodic value noise in [0,1] via summed random Fourier-free lattice upsampling."""
    r = np.random.default_rng(seed)
    acc = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gx = max(1, int(scale * stretch[0] * 2 ** o))
        gy = max(1, int(scale * stretch[1] * 2 ** o))
        g = r.random((gy, gx)).astype(np.float32)
        # Wrap-aware bicubic-ish upsample via PIL on a tiled 3x grid.
        big = np.tile(g, (3, 3))
        im = Image.fromarray((big * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
        a = np.asarray(im, np.float32)[N:2 * N, N:2 * N] / 255.0
        acc += a * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(key, color, height, rough, strength=4.0):
    d = os.path.join(OUT, key)
    os.makedirs(d, exist_ok=True)
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(os.path.join(d, "color.png"), optimize=True)
    Image.fromarray(normal_from_height(height, strength)).save(os.path.join(d, "normal.png"), optimize=True)
    r = Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).resize((512, 512), Image.BILINEAR)
    r.save(os.path.join(d, "roughness.png"), optimize=True)


def gray3(v, warm=(1.0, 0.985, 0.965)):
    return np.stack([v * warm[0], v * warm[1], v * warm[2]], -1)


def planks():
    rows = 8  # planks across the tile (1 stud each at 8 studs per tile)
    w = N // rows
    y, x = np.mgrid[0:N, 0:N]
    row = x // w
    # Board lengths: two butt joints per row, staggered.
    offs = rng.integers(0, N, rows)
    along = (y + offs[row]) % N
    seg = (along // (N // 2))
    board_id = row * 4 + seg
    tone = rng.uniform(0.86, 1.0, rows * 4)[board_id]
    grain = tile_noise(3, 4, seed=2, stretch=(6, 0.4))
    fine = tile_noise(24, 3, seed=3, stretch=(8, 0.5))
    rings = 0.5 + 0.5 * np.sin((grain * 9 + x / w * 1.7) * math.pi * 2)
    v = tone * (0.9 + 0.06 * rings + 0.06 * (fine - 0.5))
    gap_x = (x % w < 3) | (x % w > w - 3)
    gap_y = (along % (N // 2)) < 3
    seam = gap_x | gap_y
    v = np.where(seam, v * 0.62, v)
    h = 0.6 + 0.15 * rings * 0.2 + 0.05 * fine
    h = np.where(seam, 0.0, h)
    h = np.asarray(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    rough = 0.5 + 0.12 * (fine - 0.5) + np.where(seam, 0.3, 0)
    save("planks", gray3(v, (1.0, 0.97, 0.93)), h, rough, 5.0)


def tile():
    k = 4  # tiles per side (1 stud each at 4 studs per tile)
    w = N // k
    y, x = np.mgrid[0:N, 0:N]
    tid = (y // w) * k + (x // w)
    tone = rng.uniform(0.95, 1.0, k * k)[tid]
    lx, ly = x % w, y % w
    grout = (lx < 7) | (ly < 7)
    edge = np.minimum(np.minimum(lx - 7, w - lx), np.minimum(ly - 7, w - ly)).clip(0, 14) / 14.0
    speck = tile_noise(40, 2, seed=5)
    v = tone * (0.985 + 0.015 * speck)
    v = np.where(grout, 0.8, v)
    h = np.where(grout, 0.0, 0.3 + 0.7 * np.sqrt(edge))
    rough = np.where(grout, 0.85, 0.16 + 0.05 * speck)
    save("tile", gray3(v, (1.0, 1.0, 1.0)), h, rough, 3.0)


def carpet():
    fib = tile_noise(160, 2, seed=7)
    clump = tile_noise(14, 4, seed=8)
    v = 0.9 + 0.07 * (fib - 0.5) + 0.06 * (clump - 0.5)
    h = 0.6 * fib + 0.4 * clump
    rough = np.full((N, N), 0.95, np.float32)
    save("carpet", gray3(v), h, rough, 6.0)


def plaster():
    n1 = tile_noise(4, 5, seed=9)
    n2 = tile_noise(30, 3, seed=10)
    v = 0.96 + 0.035 * (n1 - 0.5) + 0.02 * (n2 - 0.5)
    h = 0.7 * n1 + 0.3 * n2
    rough = 0.82 + 0.06 * (n2 - 0.5)
    save("plaster", gray3(v), h, rough, 1.2)


def paper_base(seed):
    n = tile_noise(60, 3, seed=seed)
    return 0.975 + 0.02 * (n - 0.5), n


def stripe():
    base, n = paper_base(12)
    x = np.mgrid[0:N, 0:N][1]
    u = (x % (N // 4)) / (N // 4)  # 4 repeats per tile = 1 stud each
    band = (u > 0.18) & (u < 0.52)
    pin = (np.abs(u - 0.72) < 0.012)
    v = base * np.where(band, 0.94, 1.0) * np.where(pin, 0.9, 1.0)
    h = n * 0.2 + np.where(band, 0.03, 0)
    rough = 0.85 + 0.04 * (n - 0.5)
    save("stripe", gray3(v), h, rough, 0.8)


def sprig():
    base, n = paper_base(13)
    img = Image.new("L", (N * 3, N * 3), 0)
    d = ImageDraw.Draw(img)
    cell = N // 4
    for gy in range(-1, 13):
        for gx in range(-1, 13):
            cx = gx * cell + cell // 2
            cy = gy * cell + cell // 2 + (cell // 2 if gx % 2 else 0)
            # Tiny 5-petal flower with two leaves.
            for k in range(5):
                a = k * 2 * math.pi / 5
                px, py = cx + math.cos(a) * 11, cy + math.sin(a) * 11
                d.ellipse((px - 8, py - 8, px + 8, py + 8), fill=255)
            for s in (-1, 1):
                lx, ly = cx + s * 26, cy + 24
                d.ellipse((lx - 13, ly - 6, lx + 13, ly + 6), fill=190)
            d.line((cx, cy + 10, cx, cy + 40), fill=190, width=4)
    big = np.asarray(img.filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255.0
    m = np.zeros((N, N), np.float32)
    for oy in range(3):
        for ox in range(3):
            m = np.maximum(m, big[oy * N:(oy + 1) * N, ox * N:(ox + 1) * N])
    v = base * (1 - 0.2 * m)
    h = n * 0.2 + m * 0.15
    rough = 0.85 - 0.1 * m
    save("sprig", gray3(v), h, rough, 0.8)


def main():
    planks(); tile(); carpet(); plaster(); stripe(); sprig()
    meta = {k: {"variant": v[0], "base": v[1], "studs": v[2]} for k, v in SPECS.items()}
    json.dump(meta, open(os.path.join(OUT, "surfaces.json"), "w"), indent=1)
    print("surfaces", ", ".join(SPECS))


if __name__ == "__main__":
    main()
