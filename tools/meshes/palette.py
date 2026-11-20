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
SOFTEN = 0.15  # must match src/shared/MeshFit.luau


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


# Finish -> (tint target, mix, rough map, metal map, alpha). Mirrors MeshFit.Finishes.
FINISHES = {
    "Fabric": (None, 0.0, None, None, 1.0),
    "Wood": ((0.66, 0.47, 0.33), 0.45, "rough_satin", None, 1.0),
    "Metal": ((0.8, 0.82, 0.86), 0.2, "rough_metal", "metal_metal", 1.0),
    "Glass": ((1.0, 1.0, 1.0), 0.35, "rough_gloss", None, 1.0),
    "Slate": ((0.42, 0.45, 0.5), 0.5, "rough_matte", None, 1.0),
}


def finish(tint, name):
    target, k, rough, metal, alpha = FINISHES[name]
    if target:
        tint = tuple(a + (b - a) * k for a, b in zip(tint, target))
    return tint, (rough, metal, alpha)
