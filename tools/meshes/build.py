"""Build, bake and export furniture meshes.

blender -b -P tools/meshes/build.py -- <itemId> [<itemId> ...]
Writes assets/meshes/<itemId>/{<itemId>.fbx,color.png,normal.png,roughness.png,metalness.png,meta.json}
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib  # noqa: E402
import items  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def build(item_id, bake=True):
    lib.reset()
    lib.MATS.clear()
    spec = items.BUILDERS[item_id]
    t0 = time.time()
    extra = spec(lib.standard_mats()) or {}
    obj = lib.join_all(item_id)
    lib.unwrap(obj)
    out_dir = os.path.join(ROOT, "assets", "shell" if item_id in items.SHELL else "meshes", item_id)
    info = {}
    if bake:
        info = lib.bake_maps(obj, out_dir)
    extra.update(info)
    meta = lib.export(obj, item_id, out_dir, extra)
    print("BUILT", item_id, meta["tris"], "tris", round(time.time() - t0, 1), "s", flush=True)
    return meta


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(items.BUILDERS)
    for item_id in args:
        build(item_id)
