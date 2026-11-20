"""Item default colours (mirrors UIKit palette) and the tint the runtime uses."""
import json
import os

PALETTE = {
    "cream": (255, 248, 236),
    "coral": (255, 150, 140),
    "mint": (120, 220, 180),
    "butter": (255, 214, 110),
    "lavender": (196, 170, 240),
}
SOFTEN = 0.15  # must match src/shared/MeshKit.luau


def tint_rgb(name):
    r, g, b = PALETTE[name]
    return tuple((v / 255.0) * (1 - SOFTEN) + SOFTEN for v in (r, g, b))


def item_color(item_id):
    here = os.path.dirname(os.path.abspath(__file__))
    src = open(os.path.join(here, "..", "..", "src", "shared", "Items.luau")).read()
    for line in src.splitlines():
        bits = line.split("|")
        if len(bits) >= 11 and bits[0] == item_id:
            return bits[9]
    return "cream"


def tint_for(item_id):
    return tint_rgb(item_color(item_id))
