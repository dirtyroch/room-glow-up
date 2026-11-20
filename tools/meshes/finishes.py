#!/usr/bin/env python3
"""Finish map variants for every furniture mesh (system Python + Pillow/numpy).

python3 tools/meshes/finishes.py
For each assets/meshes/<id>/, reads color.png alpha (the tint mask) and the
baked roughness/metalness, and writes 256 px variants that only change the
tinted surfaces: rough_satin (Wood), rough_metal + metal_metal (Metal),
rough_gloss (Glass) and rough_matte (Slate). Must match MeshFit.Finishes.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets", "meshes")
SIZE = 256
ROUGH = {"satin": 0.5, "metal": 0.3, "gloss": 0.06, "matte": 0.97}


def load(path, mode="L"):
    return np.asarray(Image.open(path).convert(mode).resize((SIZE, SIZE), Image.BILINEAR), np.float32) / 255.0


def main():
    n = 0
    for item_id in sorted(os.listdir(ASSETS)):
        d = os.path.join(ASSETS, item_id)
        if not os.path.isfile(os.path.join(d, "color.png")):
            continue
        mask = np.asarray(Image.open(os.path.join(d, "color.png")).getchannel("A").resize((SIZE, SIZE), Image.BILINEAR), np.float32) / 255.0
        rough = load(os.path.join(d, "roughness.png"))
        mp = os.path.join(d, "metalness.png")
        metal = load(mp) if os.path.exists(mp) else np.zeros_like(rough)
        for key, value in ROUGH.items():
            out = rough * (1 - mask) + value * mask
            Image.fromarray((out * 255).astype(np.uint8)).save(os.path.join(d, "rough_%s.png" % key), optimize=True)
        m = metal * (1 - mask) + 1.0 * mask
        Image.fromarray((m * 255).astype(np.uint8)).save(os.path.join(d, "metal_metal.png"), optimize=True)
        n += 1
    print("finish maps for", n, "items")


if __name__ == "__main__":
    main()
