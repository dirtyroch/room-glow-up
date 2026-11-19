#!/usr/bin/env python3
"""Approximate offline stills for Room Glow Up.

Draws the lobby, one dressed set per theme family, the tour, the podium,
a 512 icon, and a 1920x1080 thumbnail. Nothing is uploaded.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "renders"

INK = (47, 36, 56, 255)
CREAM = (255, 246, 234, 255)
CORAL = (255, 186, 173, 255)
MINT = (186, 232, 206, 255)
BUTTER = (255, 226, 156, 255)
LAVENDER = (214, 201, 235, 255)
WOOD = (196, 142, 98, 255)
COCOA = (122, 78, 62, 255)
GINGER = (198, 132, 78, 255)
ICE = (186, 214, 226, 255)
WHITE = (255, 252, 248, 255)
GLASS = (214, 232, 242, 255)
PINE = (146, 186, 164, 255)
PINED = (116, 160, 140, 255)

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size: int) -> ImageFont.ImageFont:
    if os.path.exists(FONT_PATH):
        return ImageFont.truetype(FONT_PATH, size)
    return ImageFont.load_default()


def new(w: int, h: int, color) -> Image.Image:
    return Image.new("RGBA", (w, h), color)


def shadow(base: Image.Image, box, radius: int = 24, alpha: int = 40):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    draw.rounded_rectangle((x0 + 8, y0 + 14, x1 + 8, y1 + 14), radius, fill=(47, 36, 56, alpha))
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(10)))


def round_box(draw: ImageDraw.ImageDraw, box, fill, radius=28, outline=INK, width=6):
    draw.rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)


def circle(draw, box, fill, outline=INK, width=6):
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def glow_blob(base: Image.Image, center, radius, color):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius // 3)))


def window(draw, box, warm=True):
    round_box(draw, box, WOOD if warm else ICE, 18, width=6)
    x0, y0, x1, y1 = box
    pad = 14
    glass = (255, 236, 214, 255) if warm else (220, 236, 246, 255)
    round_box(draw, (x0 + pad, y0 + pad, x1 - pad, y1 - pad), glass, 12, width=4)
    mid_x = (x0 + x1) // 2
    mid_y = (y0 + y1) // 2
    draw.line((mid_x, y0 + pad, mid_x, y1 - pad), fill=INK, width=4)
    draw.line((x0 + pad, mid_y, x1 - pad, mid_y), fill=INK, width=4)


def armchair(draw, x, y, scale, fill):
    s = scale
    circle(draw, (x + 8 * s, y + 20 * s, x + 36 * s, y + 150 * s), fill, width=5)
    circle(draw, (x + 150 * s, y + 20 * s, x + 178 * s, y + 150 * s), fill, width=5)
    round_box(draw, (x + 18 * s, y + 10 * s, x + 168 * s, y + 118 * s), fill, 26, width=5)
    round_box(draw, (x + 36 * s, y + 78 * s, x + 150 * s, y + 150 * s), fill, 24, width=5)
    circle(draw, (x + 70 * s, y + 88 * s, x + 118 * s, y + 136 * s), LAVENDER, width=4)


def plant(draw, x, y, scale=1.0):
    s = scale
    round_box(draw, (x, y + 70 * s, x + 46 * s, y + 118 * s), WOOD, 16, width=4)
    circle(draw, (x - 18 * s, y, x + 64 * s, y + 86 * s), MINT, width=5)


def rug(draw, box, fill=BUTTER):
    round_box(draw, box, fill, 22, width=5)
    x0, y0, x1, y1 = box
    inset = (x0 + 16, y0 + 12, x1 - 16, y1 - 12)
    draw.rounded_rectangle(inset, 16, outline=CORAL, width=4)


def star(draw, cx, cy, r, fill=BUTTER):
    draw.regular_polygon((cx, cy, r), 5, rotation=270, fill=fill, outline=INK, width=4)


def room_shell(img, warm=True, floor=None):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    wall = CREAM if warm else (236, 244, 248, 255)
    floor = floor or ((232, 196, 156, 255) if warm else ICE)
    round_box(draw, (80, 70, w - 80, h - 60), wall, 36, width=8)
    round_box(draw, (110, h - 230, w - 110, h - 90), floor, 20, width=6)
    # baseboard and crown
    draw.rounded_rectangle((110, h - 250, w - 110, h - 220), 8, fill=CORAL if warm else LAVENDER, outline=INK, width=4)
    draw.rounded_rectangle((110, 100, w - 110, 132), 8, fill=CORAL if warm else LAVENDER, outline=INK, width=4)
    window(draw, (w // 2 - 90, 160, w // 2 + 90, 340), warm)
    glow_blob(img, (w // 2, 250), 120, (255, 220, 170, 90) if warm else (190, 220, 240, 90))
    return ImageDraw.Draw(img)


def dress_hearth(img):
    draw = room_shell(img, True)
    w, h = img.size
    rug(draw, (w // 2 - 220, h - 210, w // 2 + 220, h - 110))
    armchair(draw, w // 2 - 120, h - 360, 1.15, CORAL)
    plant(draw, w // 2 + 180, h - 340, 1.1)
    circle(draw, (w // 2 - 250, h - 250, w // 2 - 170, h - 170), LAVENDER)
    star(draw, w // 2 + 40, 250, 28)


def dress_winter(img):
    draw = room_shell(img, False, (214, 226, 234, 255))
    w, h = img.size
    rug(draw, (w // 2 - 220, h - 210, w // 2 + 200, h - 110), LAVENDER)
    armchair(draw, w // 2 - 150, h - 360, 1.1, (206, 214, 232, 255))
    plant(draw, w // 2 + 160, h - 330, 1.0)
    round_box(draw, (w // 2 + 40, h - 250, w // 2 + 180, h - 160), WOOD, 18, width=5)
    circle(draw, (w // 2 + 80, h - 300, w // 2 + 140, h - 240), BUTTER)


def dress_ginger(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    round_box(draw, (140, 220, w - 140, h - 80), GINGER, 20, width=8)
    # roof wedges as two triangles via polygons
    draw.polygon([(120, 240), (w // 2, 70), (w // 2, 240)], fill=WHITE, outline=INK)
    draw.polygon([(w // 2, 70), (w - 120, 240), (w // 2, 240)], fill=(255, 236, 220, 255), outline=INK)
    draw.line((w // 2, 70, w // 2, 240), fill=INK, width=6)
    for i, color in enumerate((CORAL, MINT, LAVENDER, BUTTER, CORAL)):
        circle(draw, (230 + i * 150, 200, 300 + i * 150, 270), color, width=4)
    circle(draw, (w // 2 - 70, 300, w // 2 + 70, 440), GLASS, width=6)
    glow_blob(img, (w // 2, 370), 80, (255, 210, 160, 100))
    round_box(draw, (w // 2 - 220, h - 280, w // 2 - 120, h - 100), (168, 96, 64, 255), 16, width=5)
    circle(draw, (w // 2 - 150, h - 180, w // 2 - 120, h - 150), BUTTER, width=3)


def tree_scene(img, cool=False):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    ground = ICE if cool else MINT
    round_box(draw, (80, h - 180, w - 80, h - 60), ground, 28, width=6)
    round_box(draw, (w // 2 - 28, h - 280, w // 2 + 28, h - 80), WOOD, 12, width=5)
    for i, (rad, col) in enumerate(((210, PINED), (160, PINE), (110, MINT))):
        y = 180 + i * 110
        circle(draw, (w // 2 - rad, y, w // 2 + rad, y + rad + 40), col, width=6)
    colors = (ICE, LAVENDER, WHITE, MINT) if cool else (CORAL, BUTTER, LAVENDER, MINT)
    spots = ((-70, 250), (80, 300), (-20, 380), (60, 450), (-90, 470))
    for (dx, y), color in zip(spots, colors * 2):
        circle(draw, (w // 2 + dx, y, w // 2 + dx + 36, y + 36), color, width=4)
    star(draw, w // 2, 150, 36, BUTTER if not cool else WHITE)
    glow_blob(img, (w // 2, 360), 100, (255, 230, 190, 70) if not cool else (200, 230, 245, 80))


def flat_before(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    draw.rectangle((90, 80, w - 90, h - 70), fill=(255, 250, 246, 255), outline=INK, width=8)
    draw.rectangle((120, h - 220, w - 120, h - 100), fill=(255, 232, 206, 255), outline=INK, width=6)
    draw.rectangle((w // 2 - 70, h - 340, w // 2 + 70, h - 180), fill=CORAL, outline=INK, width=6)
    draw.rectangle((w // 2 + 120, h - 300, w // 2 + 190, h - 180), fill=MINT, outline=INK, width=6)


def lobby(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    round_box(draw, (60, h // 2, w - 60, h - 40), (232, 244, 236, 255), 40, width=6)
    # sign
    round_box(draw, (w // 2 - 280, 70, w // 2 + 280, 190), CREAM, 28, width=6)
    title = font(54)
    sub = font(28)
    draw.text((w // 2, 110), "Room Glow Up", fill=INK, font=title, anchor="mm")
    draw.text((w // 2, 158), "Holiday Season", fill=INK, font=sub, anchor="mm")
    star(draw, w // 2 - 250, 120, 26)
    star(draw, w // 2 + 250, 120, 22, CORAL)
    # booth
    round_box(draw, (90, h // 2 + 40, 360, h - 80), CREAM, 24, width=6)
    round_box(draw, (110, h // 2 + 10, 340, h // 2 + 70), CORAL, 18, width=5)
    circle(draw, (190, h // 2 + 80, 270, h // 2 + 160), CREAM, width=5)
    circle(draw, (205, h // 2 + 95, 255, h // 2 + 145), (255, 220, 210, 255), width=3)
    draw.text((225, h - 120), "Auntie Roch", fill=INK, font=font(28), anchor="mm")
    # stage plinths
    blocks = ((w - 520, h - 230, 150, LAVENDER, "2nd"), (w - 350, h - 300, 220, BUTTER, "1st"), (w - 180, h - 190, 110, CORAL, "3rd"))
    for x, y, height, color, word in blocks:
        round_box(draw, (x, y, x + 140, y + height), color, 18, width=5)
        draw.text((x + 70, y + 36), word, fill=INK, font=font(28), anchor="mm")
    # photo spots
    circle(draw, (420, h - 200, 540, h - 80), LAVENDER, width=5)
    circle(draw, (560, h - 200, 680, h - 80), CORAL, width=5)
    draw.text((480, h - 140), "Photo", fill=INK, font=font(22), anchor="mm")
    draw.text((620, h - 140), "Photo", fill=INK, font=font(22), anchor="mm")


def tour(img):
    dress_hearth(img)
    draw = ImageDraw.Draw(img)
    w, h = img.size
    # spotlight cone
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.polygon([(w // 2, 40), (w // 2 - 220, h - 80), (w // 2 + 220, h - 80)], fill=(255, 236, 190, 70))
    img.alpha_composite(overlay)
    star(draw, w // 2, 120, 42)
    draw.text((w // 2, 48), "Tour", fill=INK, font=font(36), anchor="mm")


def podium(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    round_box(draw, (80, h // 2, w - 80, h - 50), MINT, 36, width=6)
    places = (
        (w // 2 - 340, h // 2 + 80, 220, LAVENDER, "2nd", "Bo"),
        (w // 2 - 110, h // 2 - 10, 310, BUTTER, "1st", "Ada"),
        (w // 2 + 180, h // 2 + 120, 180, CORAL, "3rd", "Cam"),
    )
    for x, y, height, color, place, name in places:
        round_box(draw, (x, y, x + 200, y + height), color, 22, width=6)
        draw.text((x + 100, y + 40), place, fill=INK, font=font(28), anchor="mm")
        draw.text((x + 100, y + 90), name, fill=INK, font=font(32), anchor="mm")
        star(draw, x + 100, y - 10, 22)
    draw.text((w // 2, 80), "Results", fill=INK, font=font(48), anchor="mm")


def icon(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    window(draw, (w // 2 - 70, 36, w // 2 + 70, 150), True)
    glow_blob(img, (w // 2, 90), 70, (255, 220, 180, 110))
    draw = ImageDraw.Draw(img)
    rug(draw, (70, h - 150, w - 70, h - 36))
    armchair(draw, 150, 170, 1.05, CORAL)
    plant(draw, 360, 250, 0.9)
    circle(draw, (190, 250, 250, 310), LAVENDER, width=4)


def thumbnail(img):
    # Left plain, right dressed. Theme name only. No timer and no price.
    w, h = img.size
    left = img.crop((0, 0, w // 2, h))
    right = img.crop((w // 2, 0, w, h))
    flat_before(left)
    dress_hearth(right)
    img.paste(left, (0, 0))
    img.paste(right, (w // 2, 0))
    draw = ImageDraw.Draw(img)
    draw.line((w // 2, 40, w // 2, h - 40), fill=INK, width=8)
    round_box(draw, (w // 2 - 220, 36, w // 2 + 220, 120), BUTTER, 28, width=6)
    draw.text((w // 2, 78), "Cocoa Hearth", fill=INK, font=font(42), anchor="mm")


def save(img: Image.Image, name: str):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    img.convert("RGB").save(path, "PNG")
    print(path)


def main():
    sky = (255, 236, 226, 255)
    cool = (226, 236, 244, 255)
    before = new(1280, 720, sky)
    flat_before(before)
    save(before, "before-room.png")

    scenes = {
        "after-lobby.png": (lobby, sky),
        "after-hearth.png": (dress_hearth, sky),
        "after-winter.png": (dress_winter, cool),
        "after-ginger.png": (dress_ginger, (255, 228, 210, 255)),
        "after-glow.png": (lambda im: tree_scene(im, False), (244, 228, 236, 255)),
        "after-frost.png": (lambda im: tree_scene(im, True), cool),
        "after-tour.png": (tour, sky),
        "after-podium.png": (podium, (255, 246, 234, 255)),
    }
    for name, (paint, bg) in scenes.items():
        img = new(1280, 720, bg)
        paint(img)
        save(img, name)

    badge = new(512, 512, CREAM)
    icon(badge)
    save(badge, "icon-512.png")
    wide = new(1920, 1080, sky)
    thumbnail(wide)
    save(wide, "thumbnail-1920.png")

    store = ROOT / "docs"
    Image.open(OUT / "icon-512.png").save(store / "store-icon.png")
    Image.open(OUT / "thumbnail-1920.png").resize((1920, 1080)).save(store / "store-thumbnail.png")


if __name__ == "__main__":
    main()
