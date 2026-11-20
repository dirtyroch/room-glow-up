#!/usr/bin/env python3
"""Rug artwork for the mesh bakes (system Python + Pillow).

The pibble outline lives in pibble_outline() so the mesh and the art match.
Image space maps object X/Y in [-H, H] to pixels, +Y at the top row.
"""
import math
import os


HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "art")
N = 1024
H = 4.8  # half footprint for a 2x2 rug


def px(x, y, half=H):
    return ((x / (2 * half) + 0.5) * N, (0.5 - y / (2 * half)) * N)


def pibble_outline(k=1.0):
    """Closed outline of a pit-bull head rug, in studs, ears at +Y."""
    pts = []
    # Head: wide, square-jawed oval.
    for i in range(72):
        a = 2 * math.pi * i / 72
        c, s = math.cos(a), math.sin(a)
        rx = 3.55
        ry = 3.35 if s > 0 else 3.6
        # Square the jaw and cheeks a bit.
        e = 2.6
        x = rx * math.copysign(abs(c) ** (2 / e), c)
        y = ry * math.copysign(abs(s) ** (2 / e), s) - 0.35
        pts.append((x * k, y * k))
    return pts


def ear(side):
    # Rose ears folding out at the top corners.
    sx = side
    return [(sx * 1.6, 2.6), (sx * 2.9, 4.35), (sx * 3.9, 3.6), (sx * 3.4, 1.9)]


def draw_pibble():
    from PIL import Image, ImageDraw, ImageFilter
    img = Image.new("RGB", (N, N), (150, 154, 166))
    d = ImageDraw.Draw(img)
    fur = (142, 146, 160)
    fur_dark = (112, 116, 130)
    white = (248, 246, 242)
    # Whole area fur so baking edges never pick up a background colour.
    d.rectangle((0, 0, N, N), fill=fur)
    for side in (-1, 1):
        d.polygon([px(*p) for p in ear(side)], fill=fur_dark)
        inner = [(side * 2.0, 2.75), (side * 2.9, 3.9), (side * 3.45, 3.4), (side * 3.1, 2.3)]
        d.polygon([px(*p) for p in inner], fill=(214, 160, 168))
    # White blaze down the forehead into the muzzle.
    d.polygon([px(-0.35, 3.0), px(0.35, 3.0), px(0.75, 0.6), px(-0.75, 0.6)], fill=white)
    # Muzzle.
    x0, y0 = px(-2.0, 0.9)
    x1, y1 = px(2.0, -2.9)
    d.ellipse((x0, y0, x1, y1), fill=white)
    # Cheeks shading.
    for side in (-1, 1):
        a, b = px(side * 2.9 - 0.9, 0.6), px(side * 2.9 + 0.9, -1.6)
        d.ellipse((min(a[0], b[0]), a[1], max(a[0], b[0]), b[1]), fill=(132, 136, 150))
    # Eyes.
    for side in (-1, 1):
        cx, cy = side * 1.45, 1.35
        a, b = px(cx - 0.62, cy + 0.55), px(cx + 0.62, cy - 0.55)
        d.ellipse((a[0], a[1], b[0], b[1]), fill=(60, 40, 34))
        a, b = px(cx - 0.42, cy + 0.38), px(cx + 0.42, cy - 0.38)
        d.ellipse((a[0], a[1], b[0], b[1]), fill=(120, 74, 52))
        a, b = px(cx - 0.2, cy + 0.2), px(cx + 0.2, cy - 0.2)
        d.ellipse((a[0], a[1], b[0], b[1]), fill=(22, 16, 16))
        a, b = px(cx + 0.05, cy + 0.32), px(cx + 0.28, cy + 0.08)
        d.ellipse((a[0], a[1], b[0], b[1]), fill=(255, 255, 255))
    # Nose.
    d.polygon([px(-0.9, -0.35), px(0.9, -0.35), px(0.55, -1.1), px(0, -1.3), px(-0.55, -1.1)], fill=(70, 56, 60))
    a, b = px(-0.45, -0.5), px(-0.1, -0.7)
    d.ellipse((a[0], a[1], b[0], b[1]), fill=(120, 104, 110))
    # Smile and tongue.
    d.line([px(0, -1.3), px(0, -1.75)], fill=(90, 80, 84), width=10)
    d.arc((*px(-1.3, -1.1), *px(0.02, -2.25)), 20, 160, fill=(90, 80, 84), width=10)
    d.arc((*px(-0.02, -1.1), *px(1.3, -2.25)), 20, 160, fill=(90, 80, 84), width=10)
    d.pieslice((*px(-0.55, -1.6), *px(0.55, -2.75)), 0, 180, fill=(236, 124, 140))
    # Soft fur speckle and blur so it reads as tufted pile, not flat vector.
    img = img.filter(ImageFilter.GaussianBlur(3))
    noise = Image.effect_noise((N, N), 18).convert("RGB")
    img = Image.blend(img, Image.composite(img, noise, Image.new("L", (N, N), 235)), 1.0)
    return img


def draw_hearth_rug():
    """Grey-scale traditional rug: tinted by SurfaceAppearance.Color in game."""
    from PIL import Image, ImageDraw, ImageFilter
    img = Image.new("RGB", (N, N), (238, 236, 232))
    d = ImageDraw.Draw(img)
    m = 40
    d.rectangle((m, m, N - m, N - m), outline=(176, 172, 168), width=28)
    d.rectangle((m + 52, m + 52, N - m - 52, N - m - 52), outline=(200, 196, 192), width=10)
    # Diamond lattice in the field.
    step = 96
    for i in range(-N, 2 * N, step):
        d.line([(i, m + 80), (i + N, N + m + 80)], fill=(222, 219, 214), width=6)
        d.line([(i, N - m - 80), (i + N, -m - 80)], fill=(222, 219, 214), width=6)
    # Medallion.
    c = N / 2
    for r, col in ((250, (190, 186, 182)), (210, (246, 244, 240)), (150, (176, 172, 168)), (100, (240, 238, 234)), (40, (160, 156, 152))):
        pts = [(c + r * math.cos(a * math.pi / 4) * (1.0 if a % 2 == 0 else 0.62), c + r * math.sin(a * math.pi / 4) * (1.0 if a % 2 == 0 else 0.62)) for a in range(8)]
        d.polygon(pts, fill=col)
    # Border motif.
    for k in range(14):
        t = m + 90 + k * (N - 2 * m - 180) / 13
        for x, y in ((t, m + 26), (t, N - m - 26), (m + 26, t), (N - m - 26, t)):
            d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(246, 244, 240))
    # Interior clear-out so the rug keeps the edge 2 px bleed.
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    noise = Image.effect_noise((N, N), 14).convert("RGB")
    return Image.blend(img, noise, 0.06)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    draw_pibble().save(os.path.join(OUT, "pibble.png"))
    draw_hearth_rug().save(os.path.join(OUT, "hearth_rug.png"))
    print("art written")
