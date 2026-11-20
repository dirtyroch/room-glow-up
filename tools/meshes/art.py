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


# ------------------------------------------------------------ 2x1 accent rugs
# RGBA, 1024x512 over the rug's x/y extent. Opaque pixels are tinted by the
# recolor (keep them light grey); alpha 0 keeps the cream/ink yarn as is.
RW, RH = 1024, 512
TINT = (236, 234, 230, 255)
TINT_DEEP = (196, 192, 188, 255)
CREAM = (250, 244, 230, 0)
INK = (92, 84, 90, 0)


def _weave(img, amount=0.07):
    from PIL import Image
    noise = Image.effect_noise((RW, RH), 18).convert("L")
    px = img.load(); nz = noise.load()
    for y in range(RH):
        for x in range(RW):
            r, g, b, a = px[x, y]
            k = 1 + amount * ((nz[x, y] - 128) / 128.0) + 0.03 * (1 if (x // 3 + y // 3) % 2 else -1)
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)
    return img


def draw_dot_rug():
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (RW, RH), TINT)
    d = ImageDraw.Draw(img)
    d.ellipse((14, 14, RW - 14, RH - 14), outline=TINT_DEEP, width=26)
    d.ellipse((58, 58, RW - 58, RH - 58), outline=CREAM, width=8)
    for gy in range(5):
        for gx in range(11):
            cx = 120 + gx * 80 + (40 if gy % 2 else 0)
            cy = 96 + gy * 80
            if ((cx - RW / 2) / (RW / 2 - 110)) ** 2 + ((cy - RH / 2) / (RH / 2 - 100)) ** 2 < 1:
                d.ellipse((cx - 17, cy - 17, cx + 17, cy + 17), fill=CREAM)
    return _weave(img)


def draw_stripe_rug():
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (RW, RH), TINT)
    d = ImageDraw.Draw(img)
    x = 0
    pattern = [(70, TINT), (16, CREAM), (8, INK), (16, CREAM), (56, TINT_DEEP), (16, CREAM)]
    i = 0
    while x < RW:
        w, c = pattern[i % len(pattern)]
        d.rectangle((x, 0, x + w, RH), fill=c)
        x += w; i += 1
    return _weave(img, 0.09)


def draw_checker_rug():
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (RW, RH), TINT)
    d = ImageDraw.Draw(img)
    s = 64
    for gy in range(RH // s):
        for gx in range(RW // s):
            if (gx + gy) % 2:
                d.rectangle((gx * s, gy * s, gx * s + s - 1, gy * s + s - 1), fill=CREAM)
    return _weave(img, 0.06)


def draw_plaid_rug():
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (RW, RH), TINT)
    d = ImageDraw.Draw(img)
    for k in range(0, RW, 128):
        d.rectangle((k + 30, 0, k + 74, RH), fill=TINT_DEEP)
        d.rectangle((k + 100, 0, k + 104, RH), fill=CREAM)
    for k in range(0, RH, 128):
        d.rectangle((0, k + 30, RW, k + 74), fill=TINT_DEEP)
        d.rectangle((0, k + 100, RW, k + 104), fill=CREAM)
    # Overlap squares a step deeper.
    for kx in range(0, RW, 128):
        for ky in range(0, RH, 128):
            d.rectangle((kx + 30, ky + 30, kx + 74, ky + 74), fill=(170, 166, 162, 255))
    return _weave(img, 0.08)


# ------------------------------------------------------------ wall art
# 512x512 paintings for the framed wall items (not tinted), plus the quilt
# patchwork (RGBA: opaque = tinted patches, alpha 0 = cream/ink fabric).
AW = 512


def _soft(img, blur=0.8, grain=0.05):
    from PIL import Image, ImageFilter
    img = img.filter(ImageFilter.GaussianBlur(blur))
    noise = Image.effect_noise(img.size, 20).convert("RGB")
    return Image.blend(img.convert("RGB"), noise, grain)


def _vgrad(d, w, h, top, bottom, y0=0):
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y0 + y), (w, y0 + y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))


def _pine(d, x, base, h, col, snow=(250, 252, 255)):
    for k in range(4):
        w = h * (0.42 - k * 0.08)
        y = base - k * h * 0.22
        d.polygon([(x - w, y), (x + w, y), (x, y - h * 0.38)], fill=col)
        d.polygon([(x - w * 0.75, y - h * 0.05), (x + w * 0.2, y - h * 0.05), (x - w * 0.1, y - h * 0.16)], fill=snow)
    d.rectangle((x - h * 0.04, base, x + h * 0.04, base + h * 0.08), fill=(110, 80, 64))


def draw_winter_scene():
    """Frosted Frame painting: dusk snowfield, pines and a lit cottage."""
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (AW, AW))
    d = ImageDraw.Draw(img)
    _vgrad(d, AW, 300, (164, 196, 232), (250, 214, 210))
    _vgrad(d, AW, AW - 300, (246, 248, 255), (214, 228, 246), 300)
    d.ellipse((330, 70, 400, 140), fill=(255, 246, 220))
    d.polygon([(0, 300), (140, 230), (260, 290), (380, 220), (512, 300)], fill=(196, 214, 238))
    d.polygon([(0, 330), (512, 310), (512, 340), (0, 360)], fill=(236, 242, 252))
    for x, h in ((60, 150), (120, 110), (430, 170), (480, 120), (380, 90)):
        _pine(d, x, 360, h, (70, 120, 110))
    d.rectangle((200, 300, 320, 380), fill=(196, 110, 96))
    d.polygon([(186, 304), (260, 248), (334, 304)], fill=(248, 250, 255))
    d.rectangle((222, 322, 252, 350), fill=(255, 214, 140))
    d.rectangle((270, 330, 296, 380), fill=(120, 76, 66))
    import random
    r = random.Random(4)
    for _ in range(220):
        x, y = r.uniform(0, AW), r.uniform(0, AW)
        s = r.uniform(1.5, 3.5)
        d.ellipse((x - s, y - s, x + s, y + s), fill=(255, 255, 255))
    return _soft(img)


def draw_snow_globe():
    """Snow Globe Frame painting: a glass globe with a tiny village on a stand."""
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (AW, AW))
    d = ImageDraw.Draw(img)
    _vgrad(d, AW, AW, (220, 244, 236), (196, 226, 218))
    c, r = 256, 170
    d.ellipse((c - r, 220 - r, c + r, 220 + r), fill=(188, 218, 244))
    d.ellipse((c - r + 14, 220 - r + 14, c + r - 14, 220 + r - 14), fill=(206, 230, 250))
    d.chord((c - r + 14, 220 - r + 14, c + r - 14, 220 + r - 14), 20, 160, fill=(246, 250, 255))
    _pine(d, 190, 300, 120, (60, 128, 104))
    _pine(d, 330, 296, 96, (60, 128, 104))
    d.rectangle((236, 250, 300, 300), fill=(232, 120, 120))
    d.polygon([(228, 252), (268, 218), (308, 252)], fill=(255, 255, 255))
    d.rectangle((258, 266, 276, 284), fill=(255, 216, 150))
    d.ellipse((150, 90, 230, 130), fill=(236, 246, 255))
    d.polygon([(110, 380), (402, 380), (372, 460), (140, 460)], fill=(176, 112, 76))
    d.rectangle((120, 372, 392, 392), fill=(214, 168, 96))
    d.rectangle((140, 448, 372, 462), fill=(150, 92, 62))
    import random
    rr = random.Random(9)
    for _ in range(90):
        a, t = rr.uniform(0, 6.283), rr.uniform(0, 0.92)
        x, y = c + math.cos(a) * r * t, 220 + math.sin(a) * r * t
        d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(255, 255, 255))
    d.arc((c - r + 30, 220 - r + 30, c + r - 30, 220 + r - 30), 200, 250, fill=(255, 255, 255), width=10)
    return _soft(img)


def draw_nutcracker():
    """Nutcracker Portrait: a toy soldier on a deep teal ground."""
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (AW, AW))
    d = ImageDraw.Draw(img)
    _vgrad(d, AW, AW, (64, 120, 128), (40, 88, 96))
    d.ellipse((96, 40, 416, 480), fill=(78, 140, 146))
    cx = 256
    d.rectangle((cx - 52, 70, cx + 52, 170), fill=(40, 40, 52))
    d.rectangle((cx - 58, 160, cx + 58, 176), fill=(232, 184, 80))
    d.ellipse((cx - 14, 54, cx + 14, 82), fill=(232, 184, 80))
    d.rectangle((cx - 46, 176, cx + 46, 250), fill=(252, 220, 196))
    d.ellipse((cx - 28, 196, cx - 14, 210), fill=(40, 40, 52))
    d.ellipse((cx + 14, 196, cx + 28, 210), fill=(40, 40, 52))
    d.ellipse((cx - 8, 208, cx + 8, 226), fill=(236, 150, 140))
    d.rectangle((cx - 40, 228, cx + 40, 236), fill=(255, 255, 255))
    d.polygon([(cx - 46, 236), (cx + 46, 236), (cx + 30, 286), (cx - 30, 286)], fill=(250, 250, 250))
    d.rectangle((cx - 64, 260, cx + 64, 380), fill=(206, 52, 64))
    for y in (290, 320, 350):
        d.ellipse((cx - 6, y - 6, cx + 6, y + 6), fill=(232, 184, 80))
    d.rectangle((cx - 64, 300, cx - 50, 380), fill=(232, 184, 80))
    d.rectangle((cx + 50, 300, cx + 64, 380), fill=(232, 184, 80))
    d.rectangle((cx - 92, 266, cx - 64, 360), fill=(206, 52, 64))
    d.rectangle((cx + 64, 266, cx + 92, 360), fill=(206, 52, 64))
    d.rectangle((cx - 64, 370, cx + 64, 384), fill=(40, 40, 52))
    d.rectangle((cx - 52, 384, cx - 8, 450), fill=(244, 244, 250))
    d.rectangle((cx + 8, 384, cx + 52, 450), fill=(244, 244, 250))
    d.rectangle((cx - 56, 440, cx - 4, 466), fill=(40, 40, 52))
    d.rectangle((cx + 4, 440, cx + 56, 466), fill=(40, 40, 52))
    return _soft(img, 0.7, 0.04)


def draw_quilt():
    """Quilt Square patchwork: tinted patches (opaque) and cream/ink (alpha 0)."""
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (AW, AW), (236, 234, 230, 255))
    d = ImageDraw.Draw(img)
    s = AW // 4
    cream = (250, 244, 230, 0)
    deep = (196, 192, 188, 255)
    for gy in range(4):
        for gx in range(4):
            x0, y0 = gx * s, gy * s
            if (gx + gy) % 2 == 0:
                # Pinwheel block.
                d.rectangle((x0, y0, x0 + s, y0 + s), fill=cream)
                d.polygon([(x0, y0), (x0 + s / 2, y0), (x0 + s / 2, y0 + s / 2)], fill=deep)
                d.polygon([(x0 + s, y0), (x0 + s, y0 + s / 2), (x0 + s / 2, y0 + s / 2)], fill=deep)
                d.polygon([(x0 + s, y0 + s), (x0 + s / 2, y0 + s), (x0 + s / 2, y0 + s / 2)], fill=deep)
                d.polygon([(x0, y0 + s), (x0, y0 + s / 2), (x0 + s / 2, y0 + s / 2)], fill=deep)
            else:
                d.rectangle((x0 + 18, y0 + 18, x0 + s - 18, y0 + s - 18), fill=cream)
                d.ellipse((x0 + s / 2 - 20, y0 + s / 2 - 20, x0 + s / 2 + 20, y0 + s / 2 + 20), fill=deep)
    for k in range(5):
        d.line([(k * s, 0), (k * s, AW)], fill=(92, 84, 90, 0), width=3)
        d.line([(0, k * s), (AW, k * s)], fill=(92, 84, 90, 0), width=3)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    draw_pibble().save(os.path.join(OUT, "pibble.png"))
    draw_hearth_rug().save(os.path.join(OUT, "hearth_rug.png"))
    for name, fn in (("dot_rug", draw_dot_rug), ("stripe_rug", draw_stripe_rug), ("checker_rug", draw_checker_rug), ("plaid_rug", draw_plaid_rug)):
        fn().save(os.path.join(OUT, name + ".png"))
    for name, fn in (("winter_scene", draw_winter_scene), ("snow_globe", draw_snow_globe), ("nutcracker", draw_nutcracker), ("quilt", draw_quilt)):
        fn().save(os.path.join(OUT, name + ".png"))
    print("art written")
