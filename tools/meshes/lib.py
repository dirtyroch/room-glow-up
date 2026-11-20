"""Blender helpers for Room Glow Up furniture meshes.

Units are studs. Front of every item faces Blender -Y (Roblox +Z after the
default FBX axis conversion). The floor is z = 0 and the footprint is centered.
"""
import math
import os
import json

import bmesh
import bpy
from mathutils import Vector, Matrix

CELL = 4.8  # Config.Cell * Config.ItemScale

# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _activate(obj):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def _finish(obj, mat, smooth=True, angle=40):
    if mat is not None:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    _activate(obj)
    if smooth:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    else:
        bpy.ops.object.shade_flat()
    return obj


def _apply_mods(obj):
    _activate(obj)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def _mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _link(bpy.data.objects.new(name, me))


# ---------------------------------------------------------------- materials

MATS = {}


def _srgb(c):
    def one(v):
        v = max(0.0, min(1.0, v))
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (one(c[0]), one(c[1]), one(c[2]), 1.0)


def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)


def material(name, color, kind="plain", tint=False, rough=0.5, metal=0.0, bump=0.0, scale=1.0,
             color2=None, grain="x", sheen=0.0, image=None, emit=0.0, tint_alpha=False):
    """kind: plain, fabric, knit, wood, metal, leaf, soil, ceramic, paper, image."""
    key = name
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m["tint"] = 1.0 if tint else 0.0
    m["metal"] = float(metal)
    m["emit"] = float(emit)
    if tint_alpha:
        # Image alpha is the tint mask: opaque pixels follow the recolor.
        m["tint"] = 1.0
        m["tint_img"] = 1
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if sheen > 0:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    tc = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    links.new(tc.outputs["Object"], mapping.inputs["Vector"])
    if not isinstance(scale, tuple):
        mapping.inputs["Scale"].default_value = (scale, scale, scale)
    if grain == "z":
        mapping.inputs["Rotation"].default_value = (0, math.pi / 2, 0)
    elif grain == "y":
        mapping.inputs["Rotation"].default_value = (0, 0, math.pi / 2)
    vec = mapping.outputs["Vector"]
    base = _srgb(color)
    height = None

    if kind in ("fabric", "knit"):
        # Fine weave: two crossing wave textures plus a soft noise.
        w1 = nodes.new("ShaderNodeTexWave")
        w1.wave_type = "BANDS"; w1.bands_direction = "X"
        w1.inputs["Scale"].default_value = 60 if kind == "fabric" else 22
        w2 = nodes.new("ShaderNodeTexWave")
        w2.wave_type = "BANDS"; w2.bands_direction = "Y" if kind == "fabric" else "Z"
        w2.inputs["Scale"].default_value = 60 if kind == "fabric" else 22
        if kind == "knit":
            w1.wave_profile = "SAW"
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 9
        links.new(vec, w1.inputs["Vector"]); links.new(vec, w2.inputs["Vector"]); links.new(vec, noise.inputs["Vector"])
        mul = nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        links.new(w1.outputs["Fac"], mul.inputs[0]); links.new(w2.outputs["Fac"], mul.inputs[1])
        height = mul.outputs[0]
        # Subtle mottling in the colour.
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = tuple(c * 0.93 for c in base[:3]) + (1,)
        ramp.color_ramp.elements[1].color = base
        ramp.color_ramp.elements[0].position = 0.3
        ramp.color_ramp.elements[1].position = 0.7
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bump = bump or 0.25
    elif kind == "wood":
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"; wave.bands_direction = "Y"
        wave.inputs["Scale"].default_value = 3.0
        wave.inputs["Distortion"].default_value = 6.0
        wave.inputs["Detail"].default_value = 3.0
        stretch = nodes.new("ShaderNodeMapping")
        stretch.inputs["Scale"].default_value = (0.15, 1.0, 1.0)  # long grain along X
        links.new(vec, stretch.inputs["Vector"])
        links.new(stretch.outputs["Vector"], wave.inputs["Vector"])
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 30
        links.new(stretch.outputs["Vector"], noise.inputs["Vector"])
        mix = nodes.new("ShaderNodeMath"); mix.operation = "MULTIPLY_ADD"
        links.new(noise.outputs["Fac"], mix.inputs[0]); mix.inputs[1].default_value = 0.35
        links.new(wave.outputs["Fac"], mix.inputs[2])
        ramp = nodes.new("ShaderNodeValToRGB")
        c2 = _srgb(color2) if color2 else tuple(v * 0.72 for v in base[:3]) + (1,)
        ramp.color_ramp.elements[0].color = base
        ramp.color_ramp.elements[1].color = c2
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[1].position = 1.0
        links.new(mix.outputs[0], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        height = wave.outputs["Fac"]
        bump = bump or 0.06
    elif kind in ("leaf", "soil", "ceramic", "paper", "plain", "metal"):
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = {"leaf": 18, "soil": 40, "ceramic": 6, "paper": 50, "plain": 8, "metal": 25}[kind]
        noise.inputs["Detail"].default_value = 6
        links.new(vec, noise.inputs["Vector"])
        spread = {"leaf": 0.8, "soil": 0.6, "ceramic": 0.96, "paper": 0.94, "plain": 0.95, "metal": 0.95}[kind]
        ramp = nodes.new("ShaderNodeValToRGB")
        lo = _srgb(color2) if color2 else tuple(c * spread for c in base[:3]) + (1,)
        ramp.color_ramp.elements[0].color = lo
        ramp.color_ramp.elements[1].color = base
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        if kind in ("soil", "leaf"):
            height = noise.outputs["Fac"]
            bump = bump or (0.5 if kind == "soil" else 0.08)
        elif bump:
            height = noise.outputs["Fac"]
    elif kind == "image":
        # Planar projection from above (object X/Y), image covers the footprint.
        img = bpy.data.images.load(image)
        tex = nodes.new("ShaderNodeTexImage")
        tex.name = "tint_src"
        # Alpha is a mask, not coverage: keep the colour under alpha 0.
        img.alpha_mode = "CHANNEL_PACKED"
        tex.image = img
        tex.extension = "EXTEND"
        proj = nodes.new("ShaderNodeMapping")
        sx, sy = scale if isinstance(scale, tuple) else (scale, scale)
        proj.inputs["Scale"].default_value = (1.0 / sx, 1.0 / sy, 1)
        proj.inputs["Location"].default_value = (0.5, 0.5, 0)
        links.new(tc.outputs["Object"], proj.inputs["Vector"])
        links.new(proj.outputs["Vector"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        noise = nodes.new("ShaderNodeTexWave")
        noise.inputs["Scale"].default_value = 50
        links.new(tc.outputs["Object"], noise.inputs["Vector"])
        height = noise.outputs["Fac"]
        bump = bump or 0.15
    if height is not None and bump > 0:
        b = nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        b.inputs["Distance"].default_value = 0.02
        links.new(height, b.inputs["Height"])
        links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    if kind not in ("fabric", "knit", "wood", "leaf", "soil", "ceramic", "paper", "plain", "metal", "image"):
        bsdf.inputs["Base Color"].default_value = base
    MATS[key] = m
    return m


# Shared palette for fixed (non-tint) materials. Tint materials are near-white.
def standard_mats():
    return {
        "fabric": material("fabric", (0.93, 0.92, 0.90), "fabric", tint=True, rough=0.88, sheen=0.4),
        "knit": material("knit", (0.94, 0.93, 0.91), "knit", tint=True, rough=0.92, sheen=0.4, bump=0.5),
        "paint": material("paint", (0.95, 0.94, 0.92), "plain", tint=True, rough=0.38),
        "oak": material("oak", rgb(196, 146, 100), "wood", rough=0.5, color2=rgb(150, 100, 62)),
        "walnut": material("walnut", rgb(132, 86, 58), "wood", rough=0.45, color2=rgb(92, 58, 40)),
        "birch": material("birch", rgb(232, 206, 168), "wood", rough=0.5, color2=rgb(204, 168, 126)),
        "brass": material("brass", rgb(222, 184, 112), "metal", rough=0.28, metal=1.0),
        "chrome": material("chrome", rgb(220, 222, 226), "metal", rough=0.15, metal=1.0),
        "steel": material("steel", rgb(196, 198, 202), "metal", rough=0.35, metal=1.0),
        "black": material("black", rgb(46, 42, 44), "plain", rough=0.4),
        "rubber": material("rubber", rgb(40, 38, 40), "plain", rough=0.8),
        "white": material("white", rgb(250, 247, 242), "ceramic", rough=0.25),
        "cream": material("cream", rgb(252, 240, 222), "fabric", rough=0.85, sheen=0.3),
        "glass": material("glass", rgb(200, 222, 232), "plain", rough=0.06),
        "leaf": material("leaf", rgb(92, 160, 92), "leaf", rough=0.5, color2=rgb(56, 116, 66)),
        "soil": material("soil", rgb(92, 64, 46), "soil", rough=0.95, color2=rgb(60, 42, 32)),
        "terracotta": material("terracotta", rgb(214, 128, 92), "ceramic", rough=0.7),
        "bulb": material("bulb", rgb(255, 246, 214), "plain", rough=0.2, emit=1.0),
        "leather": material("leather", (0.93, 0.91, 0.89), "plain", tint=True, rough=0.42, bump=0.12),
        "tintceramic": material("tintceramic", (0.95, 0.94, 0.93), "ceramic", tint=True, rough=0.22),
        "marble": material("marble", rgb(244, 242, 238), "ceramic", rough=0.18, color2=rgb(214, 212, 210)),
        "paper": material("paper", rgb(250, 248, 240), "paper", rough=0.8),
    }


# ---------------------------------------------------------------- primitives

def box(size, loc, mat=None, bevel=0.12, seg=3, name="box", cuts=0, smooth=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if cuts:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.subdivide(number_cuts=cuts)
        bpy.ops.object.mode_set(mode="OBJECT")
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = min(bevel, min(size) * 0.49)
        b.segments = seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(30)
        b.harden_normals = False
        _apply_mods(o)
    return _finish(o, mat, smooth)


def cushion(size, loc, mat=None, round_=0.35, puff=0.12, cuts=4, seg=3, front_puff=0.0, name="cushion"):
    """Soft box: beveled, then the top (and optionally front) bulges out."""
    o = box(size, (0, 0, 0), None, bevel=min(size) * round_, seg=seg, name=name, cuts=cuts)
    sx, sy, sz = size
    for v in o.data.vertices:
        x, y, z = v.co
        fx = max(0.0, 1 - (2 * x / sx) ** 2)
        fy = max(0.0, 1 - (2 * y / sy) ** 2)
        fz = max(0.0, 1 - (2 * z / sz) ** 2)
        if z > 0:
            v.co.z += puff * min(sx, sy) * fx * fy * (z / (sz / 2))
        if front_puff and y < 0:
            v.co.y -= front_puff * min(sx, sz) * fx * fz * (-y / (sy / 2))
        # Slight side bulge so it never looks like a hard brick.
        v.co.x *= 1 + 0.03 * fy * fz
    o.location = loc
    _activate(o)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return _finish(o, mat, True, 60)


def lathe(profile, loc=(0, 0, 0), mat=None, segs=32, name="lathe", cap_top=True, cap_bottom=True, smooth=True, angle=40):
    """profile: list of (radius, z) from bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for i in range(segs):
            k = (i + 1) % segs
            bm.faces.new((a[i], a[k], b[k], b[i]))
    if cap_bottom and profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _mesh_obj(name, bm)
    o.location = loc
    _activate(o)
    bpy.ops.object.transform_apply(location=True)
    return _finish(o, mat, smooth, angle)


def cyl(r, h, loc, mat=None, segs=24, bevel=0.03, name="cyl", r2=None):
    """Vertical cylinder standing on loc (loc z is the bottom)."""
    r2 = r if r2 is None else r2
    bv = min(bevel, h * 0.4, r * 0.4)
    prof = []
    if bv > 0:
        prof = [(0, 0), (r - bv, 0), (r - bv * 0.3, bv * 0.3), (r, bv), (r2, h - bv), (r2 - bv * 0.3, h - bv * 0.3), (r2 - bv, h), (0, h)]
    else:
        prof = [(0, 0), (r, 0), (r2, h), (0, h)]
    return lathe(prof, loc, mat, segs, name, cap_top=False, cap_bottom=False, angle=50)


def sphere(r, loc, mat=None, scale=(1, 1, 1), segs=24, rings=14, name="sphere"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, scale=True)
    return _finish(o, mat, True, 80)


def tube(points, radius, mat=None, segs=10, name="tube", caps=True, resolution=6):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for p, co in zip(sp.bezier_points, points):
        p.co = co
        p.handle_left_type = p.handle_right_type = "AUTO"
    cu.bevel_depth = radius
    cu.bevel_resolution = max(1, segs // 4)
    cu.resolution_u = resolution
    cu.use_fill_caps = caps
    o = _link(bpy.data.objects.new(name, cu))
    _activate(o)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    return _finish(o, mat, True, 60)


def ring(major, minor, loc, mat=None, segs=32, minor_segs=10, rot=(0, 0, 0), name="ring"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segs,
                                     minor_segments=minor_segs, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return _finish(o, mat, True, 80)


def extrude_outline(points2d, depth, loc, mat=None, bevel=0.05, seg=2, name="slab"):
    """Flat shape from a closed 2D outline (x, y), extruded up by depth."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, 0)) for x, y in points2d]
    top = [bm.verts.new((x, y, depth)) for x, y in points2d]
    n = len(points2d)
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(n):
        k = (i + 1) % n
        bm.faces.new((bot[i], bot[k], top[k], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _mesh_obj(name, bm)
    o.location = loc
    _activate(o)
    bpy.ops.object.transform_apply(location=True)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(50)
        _apply_mods(o)
    # Triangulate n-gon caps cleanly.
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(o.data); bm.free()
    return _finish(o, mat, True, 50)


def transform(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Scale, then rotate about the world origin, then move (composes with any
    placement the object already had)."""
    _activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    _activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def duplicate(obj, loc=None, rot=None, scale=None, mirror_x=False):
    new = obj.copy()
    new.data = obj.data.copy()
    _link(new)
    if mirror_x:
        for v in new.data.vertices:
            v.co.x = -v.co.x
        new.data.flip_normals()
    if loc or rot or scale:
        transform(new, loc or (0, 0, 0), rot or (0, 0, 0), scale or (1, 1, 1))
    return new


def leaf_blade(length, width, bend=0.3, segs=6, name="leaf"):
    """A curved leaf with a raised midrib, base at origin, pointing +X."""
    bm = bmesh.new()
    rows = []
    for i in range(segs + 1):
        t = i / segs
        x = t * length
        w = width * math.sin(math.pi * min(1.0, t * 1.05)) * (1 - 0.25 * t)
        z = -bend * length * t * t
        mid = bm.verts.new((x, 0, z + width * 0.12))
        left = bm.verts.new((x, w / 2, z))
        right = bm.verts.new((x, -w / 2, z))
        rows.append((left, mid, right))
    for i in range(segs):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    # Back side so it is solid from below (Roblox meshes are single-sided).
    back = bmesh.ops.duplicate(bm, geom=list(bm.faces))
    bfaces = [g for g in back["geom"] if isinstance(g, bmesh.types.BMFace)]
    bverts = [g for g in back["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in bverts:
        v.co.z -= 0.012
    bmesh.ops.reverse_faces(bm, faces=bfaces)
    o = _mesh_obj(name, bm)
    return o


# ---------------------------------------------------------------- join, uv, bake

def join_all(name):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    _activate(meshes[0])
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def unwrap(obj, margin=0.006):
    _activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def _new_image(name, size, non_color, alpha=False):
    img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _target(obj, img):
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        node = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = img
        for n in nt.nodes:
            n.select = False
        node.select = True
        nt.nodes.active = node


def _bake(obj, kind, img, samples=4, pass_filter=None):
    scene = bpy.context.scene
    scene.cycles.samples = samples
    _target(obj, img)
    _activate(obj)
    kw = dict(type=kind, margin=8, use_clear=True)
    if pass_filter:
        kw["pass_filter"] = pass_filter
    bpy.ops.object.bake(**kw)


def _bake_value(obj, img, prop):
    """Bake a per-material constant (tint mask, metalness) through Emission."""
    saved = []
    for slot in obj.material_slots:
        m = slot.material
        nt = m.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        old = out.inputs["Surface"].links[0].from_socket
        em = nt.nodes.new("ShaderNodeEmission")
        v = float(m.get(prop, 0.0))
        em.inputs["Color"].default_value = (v, v, v, 1)
        if prop == "tint" and m.get("tint_img") and "tint_src" in nt.nodes:
            nt.links.new(nt.nodes["tint_src"].outputs["Alpha"], em.inputs["Color"])
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        saved.append((nt, out, old, em))
    _bake(obj, "EMIT", img, samples=1)
    for nt, out, old, em in saved:
        nt.links.new(old, out.inputs["Surface"])
        nt.nodes.remove(em)


def bake_maps(obj, out_dir, size=1024, small=512):
    import numpy as np
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.use_selected_to_active = False
    scene.render.threads_mode = "AUTO"
    col = _new_image("col", size, False)
    # Diffuse colour of a metal is black in Cycles; bake albedo with metal off.
    saved = []
    for slot in obj.material_slots:
        for n in slot.material.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                saved.append((n, n.inputs["Metallic"].default_value))
                n.inputs["Metallic"].default_value = 0.0
    _bake(obj, "DIFFUSE", col, samples=4, pass_filter={"COLOR"})
    for n, v in saved:
        n.inputs["Metallic"].default_value = v
    ao = _new_image("ao", size, True)
    scene.world = scene.world or bpy.data.worlds.new("w")
    _bake(obj, "AO", ao, samples=48)
    nrm = _new_image("nrm", size, True)
    _bake(obj, "NORMAL", nrm, samples=4)
    rough = _new_image("rough", small, True)
    _bake(obj, "ROUGHNESS", rough, samples=2)
    tint = _new_image("tint", size, True)
    _bake_value(obj, tint, "tint")
    metal = _new_image("metal", small, True)
    _bake_value(obj, metal, "metal")

    def px(img):
        a = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        return a.reshape((img.size[1], img.size[0], 4))

    c = px(col); o = px(ao); t = px(tint)
    # Soft contact shading: keep AO gentle so pastel colours stay clean.
    occ = 0.45 + 0.55 * np.clip(o[..., 0], 0, 1) ** 0.9
    occ = np.minimum(1.0, occ * 1.08)
    final = c.copy()
    final[..., :3] = np.clip(c[..., :3] * occ[..., None], 0, 1)
    final[..., 3] = np.clip(t[..., 0], 0, 1)
    out = bpy.data.images.new("color_final", size, size, alpha=True)
    out.alpha_mode = "STRAIGHT"
    out.pixels.foreach_set(final.ravel())
    os.makedirs(out_dir, exist_ok=True)

    def save(img, name):
        img.filepath_raw = os.path.join(out_dir, name)
        img.file_format = "PNG"
        img.save()

    save(out, "color.png")
    save(nrm, "normal.png")
    save(rough, "roughness.png")
    m = px(metal)
    has_metal = float(m[..., 0].max()) > 0.01
    if has_metal:
        save(metal, "metalness.png")
    has_emit = any(float(s.material.get("emit", 0)) > 0 for s in obj.material_slots)
    if has_emit:
        em = _new_image("emit", small, True)
        _bake_value(obj, em, "emit")
        save(em, "emissive.png")
    return {"metal": has_metal, "emissive": has_emit}


def export(obj, item_id, out_dir, extra=None):
    os.makedirs(out_dir, exist_ok=True)
    _activate(obj)
    # Strip bake nodes from materials, export geometry + UVs + normals only.
    path = os.path.join(out_dir, item_id + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             mesh_smooth_type="FACE", use_mesh_modifiers=True, add_leaf_bones=False,
                             path_mode="STRIP", axis_forward="-Z", axis_up="Y", apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True)
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    size = mx - mn
    center = (mx + mn) / 2
    # Roblox axes: X = Blender X, Y = Blender Z, Z = -Blender Y.
    meta = {
        "id": item_id,
        "tris": tri_count(obj),
        "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)],
        "center": [round(center.x, 4), round(center.z, 4), round(-center.y, 4)],
    }
    if extra:
        meta.update(extra)
    with open(os.path.join(out_dir, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return meta


def bend(obj, radius, axis_center=(0, 0)):
    """Wrap an object's local X around a vertical axis: x -> angle, y -> radial.
    Angle 0 points to +Y (the back of the item); +y in the source is outward."""
    cx, cy = axis_center
    for v in obj.data.vertices:
        x, y, z = v.co
        a = x / radius
        r = radius + y
        v.co.x = cx + r * math.sin(a)
        v.co.y = cy + r * math.cos(a)
    obj.data.update()
    return obj


def cut(target, cutter):
    """Boolean difference, then delete the cutter."""
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    _apply_mods(target)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def star_outline(r_out, r_in, n=5):
    pts = []
    for i in range(2 * n):
        a = math.pi / 2 + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def frond(length, width, leaflets=10, bend_amt=0.35, name="frond", gap=0.35):
    """Fern frond: a strip whose edge is cut into alternating leaflets."""
    bm = bmesh.new()
    segs = leaflets * 2
    rows = []
    for i in range(segs + 1):
        t = i / segs
        x = t * length
        env = math.sin(math.pi * min(1.0, 0.15 + t * 0.9)) * (1 - 0.6 * t)
        lobe = 1.0 if i % 2 == 1 else gap
        w = width * env * lobe
        z = -bend_amt * length * t * t
        fwd = (0.9 * length / segs) if i % 2 == 1 else 0.0
        rows.append((bm.verts.new((x + fwd, w / 2, z + 0.02 - 0.08 * lobe)), bm.verts.new((x, 0, z + 0.06)), bm.verts.new((x + fwd, -w / 2, z + 0.02 - 0.08 * lobe))))
    for i in range(segs):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    back = bmesh.ops.duplicate(bm, geom=list(bm.faces))
    bfaces = [g for g in back["geom"] if isinstance(g, bmesh.types.BMFace)]
    for g in back["geom"]:
        if isinstance(g, bmesh.types.BMVert):
            g.co.z -= 0.015
    bmesh.ops.reverse_faces(bm, faces=bfaces)
    return _mesh_obj(name, bm)


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj
