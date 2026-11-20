#!/usr/bin/env python3
"""Rebuild Room Glow Up scenes (parts and furniture meshes) in Blender.

  lune run scripts/dump_previews /workspace/rgu-renders/rgu3d-scenes.json --meshes
  blender -b -P tools/meshes/scene_render.py -- <scenes.json> <outdir> [scene ...]

Meshes come from assets/meshes (the exported FBX and baked maps), drawn with the
SurfaceAppearance TintMask emulated, so they look like they would in game.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector, Color

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hero  # noqa: E402
import palette  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENES = "/workspace/rgu-renders/rgu3d-scenes.json"
OUT_DIR = "/workspace/rgu-renders"
MESH_CACHE = {}
MESH_META = {}
SIZE = (1920, 1080)

def srgb_to_linear(c):
    c = max(0.0, min(1.0, float(c)))
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def srgb3(channels, alpha=None):
    rgb = tuple(srgb_to_linear(c) for c in channels[:3])
    if alpha is None:
        return rgb
    return (*rgb, alpha)


FAMILIES = {
    "hearth": {
        "horizon": (0.62, 0.84, 0.98),
        "zenith": (0.45, 0.72, 0.96),
        "ground": (0.94, 0.97, 1.0),
        "key": (1.0, 0.98, 0.94),
        "fill": (0.92, 0.96, 1.0),
        "rim": (1.0, 0.90, 0.86),
        "exposure": 0.0,
    },
    "ginger": {
        "horizon": (0.70, 0.88, 0.98),
        "zenith": (0.50, 0.76, 0.96),
        "ground": (0.90, 0.82, 0.70),
        "key": (1.0, 0.97, 0.92),
        "fill": (0.95, 0.96, 1.0),
        "rim": (1.0, 0.80, 0.86),
        "exposure": 0.0,
    },
    "winter": {
        "horizon": (0.70, 0.88, 1.0),
        "zenith": (0.40, 0.68, 0.95),
        "ground": (0.92, 0.95, 0.98),
        "key": (0.96, 0.98, 1.0),
        "fill": (0.90, 0.94, 1.0),
        "rim": (0.85, 0.92, 1.0),
        "exposure": 0.0,
    },
    "glow": {
        "horizon": (0.72, 0.70, 0.96),
        "zenith": (0.40, 0.32, 0.70),
        "ground": (0.82, 0.78, 0.92),
        "key": (1.0, 0.94, 0.85),
        "fill": (0.90, 0.84, 1.0),
        "rim": (1.0, 0.70, 0.95),
        "exposure": 0.0,
    },
}

FACE_LOCAL = {
    "Front": (0, 0, -1),
    "Back": (0, 0, 1),
    "Right": (1, 0, 0),
    "Left": (-1, 0, 0),
    "Top": (0, 1, 0),
    "Bottom": (0, -1, 0),
}

MATS = {}


def rbx_to_b(p):
    return Vector((p[0], p[2], p[1]))


def part_matrix(part):
    right = rbx_to_b(part["right"])
    up = rbx_to_b(part["up"])
    back = rbx_to_b(part["back"])
    loc = rbx_to_b(part["p"])
    sx, sy, sz = part["s"]
    # Blender local X,Y,Z = Roblox X, Z, Y
    rot = Matrix((
        (right.x, back.x, up.x, loc.x),
        (right.y, back.y, up.y, loc.y),
        (right.z, back.z, up.z, loc.z),
        (0, 0, 0, 1),
    ))
    scale = Matrix.Diagonal((sx, sz, sy, 1.0))
    return rot @ scale


def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.curves):
        for item in list(block):
            block.remove(item)
    MATS.clear()


SURF_META = json.load(open(os.path.join(ROOT, "assets", "surfaces", "surfaces.json")))


def surf_material(part):
    """MaterialVariant stand-in: the tileable surface maps in world space, tinted
    by the part color (as MaterialVariant ColorMaps are in game)."""
    key = part["surf"]
    color = tuple(round(c, 4) for c in part["c"])
    mk = ("surf", key, color)
    if mk in MATS:
        return MATS[mk]
    d = os.path.join(ROOT, "assets", "surfaces", key)
    studs = float(SURF_META[key]["studs"])
    mat = bpy.data.materials.new(name="surf_%s_%d" % (key, len(MATS)))
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / studs, 1 / studs, 1 / studs)
    nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])

    def tex(name, non_color):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(d, name), check_existing=True)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        n.projection = "BOX"
        n.projection_blend = 0.05
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        return n
    c = tex("color.png", False)
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(c.outputs["Color"], mul.inputs[6])
    mul.inputs[7].default_value = (*srgb3(color), 1)
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    r = tex("roughness.png", True)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    n = tex("normal.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 0.8
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    MATS[mk] = mat
    return mat


def material_for(part):
    if part.get("surf"):
        return surf_material(part)
    mat_name = part.get("mat") or "SmoothPlastic"
    color = tuple(round(c, 4) for c in part["c"])
    trans = round(float(part.get("t") or 0), 3)
    key = (mat_name, color, trans)
    if key in MATS:
        return MATS[key]
    mat = bpy.data.materials.new(name=f"{mat_name}_{len(MATS)}")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (400, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    r, g, b = srgb3(color)
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
    if mat_name == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*srgb3(color), 1)
        bsdf.inputs["Emission Strength"].default_value = 0.9
        bsdf.inputs["Roughness"].default_value = 0.25
    elif mat_name == "Glass":
        # Frosted pane, not a blown portal.
        bsdf.inputs["Transmission Weight"].default_value = 0.12
        bsdf.inputs["Roughness"].default_value = 0.18
        bsdf.inputs["IOR"].default_value = 1.45
        bsdf.inputs["Alpha"].default_value = 0.55
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
        mat.blend_method = "BLEND"
    elif mat_name == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.85
        bsdf.inputs["Roughness"].default_value = 0.28
    elif mat_name in ("Wood", "WoodPlanks"):
        bsdf.inputs["Roughness"].default_value = 0.55
        bsdf.inputs["Specular IOR Level"].default_value = 0.35
    elif mat_name == "Fabric":
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Sheen Weight"].default_value = 0.35
    elif mat_name == "Grass":
        bsdf.inputs["Roughness"].default_value = 0.8
    elif mat_name == "Brick":
        bsdf.inputs["Roughness"].default_value = 0.7
    else:
        bsdf.inputs["Roughness"].default_value = 0.38
        bsdf.inputs["Specular IOR Level"].default_value = 0.4
    if trans > 0 and mat_name != "Glass":
        bsdf.inputs["Alpha"].default_value = max(0.08, 1 - trans)
        mat.blend_method = "BLEND"
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    MATS[key] = mat
    return mat


def make_mesh(shape):
    shape = (shape or "Block").lower()
    if shape == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=0.5, location=(0, 0, 0))
    elif shape == "cylinder":
        # Roblox cylinder axis is local X. Default Blender cylinder is Z.
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1, location=(0, 0, 0))
        obj = bpy.context.active_object
        obj.rotation_euler = (0, math.pi / 2, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    elif shape == "wedge":
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
        obj = bpy.context.active_object
        mesh = obj.data
        # Collapse the +Y (Blender local Y = Roblox +Z) top edge down, keeping -Y top.
        # Cube verts: x,y,z in +/- 0.5. Roblox wedge keeps height at -Z and drops at +Z.
        # After axis map, Roblox Z is Blender Y, Roblox Y is Blender Z.
        # So drop verts with +Y and +Z (top of the far edge).
        for v in mesh.vertices:
            if v.co.y > 0 and v.co.z > 0:
                v.co.z = -0.5
    else:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    obj = bpy.context.active_object
    bpy.ops.object.shade_smooth() if shape in ("ball", "cylinder") else None
    return obj


def mesh_template(item_id):
    if item_id in MESH_CACHE:
        return MESH_CACHE[item_id]
    path = os.path.join(hero.item_dir(item_id), item_id + ".fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y")
    obj = [o for o in bpy.data.objects if o not in before and o.type == "MESH"][0]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    MESH_CACHE[item_id] = obj.data
    MESH_META[item_id] = json.load(open(os.path.join(hero.item_dir(item_id), "meta.json")))
    return obj.data


def add_mesh(part, collection):
    item_id = part["mesh"]
    data = mesh_template(item_id)
    meta = MESH_META[item_id]
    c = part["c"]
    s = palette.SOFTEN
    tint = tuple(v + (1 - v) * s for v in c[:3])
    maps = None
    if part.get("finish"):
        tint, maps = palette.finish(tint, part["finish"])
    key = (item_id, tuple(round(v, 3) for v in tint), part.get("finish"))
    mat = MATS.get(key)
    if mat is None:
        mat = hero.textured_material(item_id, tint, name="mesh_%s_%d" % (item_id, len(MATS)), finish=maps)
        MATS[key] = mat
    obj = bpy.data.objects.new(item_id, data.copy())
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    right = rbx_to_b(part["right"])
    up = rbx_to_b(part["up"])
    back = rbx_to_b(part["back"])
    loc = rbx_to_b(part["p"])
    rot = Matrix((
        (right.x, back.x, up.x, loc.x),
        (right.y, back.y, up.y, loc.y),
        (right.z, back.z, up.z, loc.z),
        (0, 0, 0, 1),
    ))
    k = part["s"][0] / meta["size"][0] if meta["size"][0] else 1.0
    cx, cy, cz = meta["center"]
    # Native Blender mesh (front -Y) -> engine local (x, z, -y) -> reflected world.
    native_center = Matrix.Translation((-cx, cz, -cy))
    obj.matrix_world = rot @ Matrix.Diagonal((k, -k, k, 1.0)) @ native_center
    collection.objects.link(obj)
    for i, lamp in enumerate(part.get("lights") or []):
        light = bpy.data.lights.new(name=f"{item_id}_L{i}", type="POINT")
        brightness = float(lamp.get("b") or 1)
        radius = float(lamp.get("range") or 8)
        light.energy = max(3.0, brightness * radius * 2.4)
        light.shadow_soft_size = 0.6
        light.color = srgb3(lamp.get("c") or (1, 0.9, 0.75))
        lo = bpy.data.objects.new(light.name, light)
        lo.location = rbx_to_b(lamp.get("p") or part["p"])
        collection.objects.link(lo)
    return obj


def part_lights(part, collection, base):
    for i, lamp in enumerate(part.get("lights") or []):
        kind = (lamp.get("kind") or "PointLight")
        c = lamp.get("c") or part["c"]
        color = srgb3(c)
        brightness = float(lamp.get("b") or 1)
        radius = float(lamp.get("range") or 8)
        loc = rbx_to_b(part["p"])
        if kind == "SpotLight":
            # Ceiling cans: a real cone so the back wall gets soft scallops.
            light = bpy.data.lights.new(name=f"{base}_L{i}", type="SPOT")
            light.spot_size = math.radians(float(lamp.get("angle") or 70) * 1.3)
            light.spot_blend = 0.65
            light.energy = max(20.0, brightness * radius * 5.0)
            light.shadow_soft_size = 0.4
            light.color = color
            lo = bpy.data.objects.new(light.name, light)
            face = FACE_LOCAL.get(lamp.get("face") or "Bottom", FACE_LOCAL["Bottom"])
            right, up, back = part["right"], part["up"], part["back"]
            direction = tuple(right[j] * face[0] + up[j] * face[1] + back[j] * face[2] for j in range(3))
            emit = rbx_to_b(direction)
            emit.normalize()
            lo.location = loc + emit * 0.1
            lo.rotation_euler = emit.to_track_quat("-Z", "Y").to_euler()
        elif kind == "SurfaceLight":
            light = bpy.data.lights.new(name=f"{base}_L{i}", type="AREA")
            light.shape = "DISK"
            light.size = max(1.5, min(part["s"][0], part["s"][1]) * 0.6)
            light.energy = max(20.0, brightness * radius * 8.0)
            light.color = color
            light.use_shadow = True
            lo = bpy.data.objects.new(light.name, light)
            face = FACE_LOCAL.get(lamp.get("face") or "Back", FACE_LOCAL["Back"])
            right = part["right"]
            up = part["up"]
            back = part["back"]
            direction = (
                right[0] * face[0] + up[0] * face[1] + back[0] * face[2],
                right[1] * face[0] + up[1] * face[1] + back[1] * face[2],
                right[2] * face[0] + up[2] * face[1] + back[2] * face[2],
            )
            emit = rbx_to_b(direction)
            if emit.length < 0.001:
                emit = Vector((0, 0, -1))
            emit.normalize()
            lo.location = loc + emit * 0.25
            # Area lights emit along local -Z.
            lo.rotation_euler = emit.to_track_quat("-Z", "Y").to_euler()
        else:
            light = bpy.data.lights.new(name=f"{base}_L{i}", type="POINT")
            light.energy = max(3.0, brightness * radius * 2.4)
            light.shadow_soft_size = 1.2
            light.use_shadow = True
            light.color = color
            lo = bpy.data.objects.new(light.name, light)
            lo.location = loc
        collection.objects.link(lo)


def add_part(part, collection):
    if part.get("mesh"):
        return add_mesh(part, collection)
    obj = make_mesh(part.get("shape"))
    obj.name = (part.get("name") or "Part")[:60]
    obj.matrix_world = part_matrix(part)
    obj.data.materials.append(material_for(part))
    collection.objects.link(obj)
    if obj.name in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.unlink(obj)
    part_lights(part, collection, obj.name)
    return obj



def apply_grade(grade, family):
    # Color3 is already in the materials. Do not add a film look, exposure
    # crush, or tint multiply — those muddied the v3 stills. Only flip X
    # because the Roblox-to-Blender axis map is a reflection.
    scene = bpy.context.scene
    scene.use_nodes = True
    scene.render.use_compositing = True
    tree = scene.node_tree
    for n in list(tree.nodes):
        tree.nodes.remove(n)
    rl = tree.nodes.new("CompositorNodeRLayers")
    rl.location = (0, 0)
    flip = tree.nodes.new("CompositorNodeFlip")
    flip.location = (260, 0)
    flip.axis = "X"
    comp = tree.nodes.new("CompositorNodeComposite")
    comp.location = (520, 0)
    tree.links.new(rl.outputs["Image"], flip.inputs["Image"])
    tree.links.new(flip.outputs["Image"], comp.inputs["Image"])


def setup_world(family, look, cam_pos, scene_name="", lens=35, grade_light=None):
    pal = dict(FAMILIES.get(family, FAMILIES["hearth"]))
    if scene_name in ("lobby", "lobby_phone", "lobby_wide", "podium"):
        pal["horizon"] = (0.62, 0.84, 0.98)
        pal["ground"] = (0.94, 0.97, 1.0)
        pal["key"] = (1.0, 0.98, 0.94)
        pal["fill"] = (0.90, 0.95, 1.0)
    elif scene_name in ("hearth", "tour") or scene_name.split("_")[0] in ("hearth", "kitchen", "showroom"):
        pal["horizon"] = (0.82, 0.92, 0.98)
        pal["ground"] = (0.88, 0.90, 0.86)
        pal["key"] = (1.0, 0.95, 0.86)
        pal["fill"] = (1.0, 0.96, 0.90)
        pal["rim"] = (1.0, 0.88, 0.80)
    elif scene_name.split("_")[0] in ("nook", "nookwinter"):
        # Interior frost/winter stills: the same open-front sky as the hearth
        # interiors, keyed by the family's own daylight from the dumped grade.
        pal["horizon"] = (0.80, 0.89, 0.98)
        pal["ground"] = (0.92, 0.94, 0.96)
        pal["key"] = tuple(grade_light or (0.96, 0.97, 1.0))
        pal["fill"] = (0.97, 0.97, 1.0)
        pal["rim"] = (1.0, 0.92, 0.86)
    elif scene_name == "ginger":
        pal["horizon"] = (0.72, 0.88, 0.98)
        pal["ground"] = (0.93, 0.86, 0.70)
        pal["key"] = (1.0, 0.96, 0.86)
        pal["fill"] = (1.0, 0.96, 0.90)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.compression = 15
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    eevee = scene.eevee
    eevee.taa_render_samples = 48
    eevee.use_shadows = True
    if hasattr(eevee, "use_raytracing"):
        eevee.use_raytracing = True
    if hasattr(eevee, "use_bloom"):
        eevee.use_bloom = True
        eevee.bloom_intensity = 0.02
        eevee.bloom_threshold = 1.2

    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    # Clean high-key sky so part Color3 values read clearly.
    sky = pal.get("horizon") or (0.62, 0.82, 0.98)
    bg.inputs["Color"].default_value = srgb3(sky, 1)
    if scene_name in ("hearth", "tour", "ginger", "glow") or "_" in scene_name:
        bg.inputs["Strength"].default_value = 0.95
    else:
        bg.inputs["Strength"].default_value = 1.15
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])

    # Ground disc
    ground_at = rbx_to_b((look[0], 0, look[2]))
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=220, depth=0.4, location=(ground_at.x, ground_at.y, -0.2))
    ground = bpy.context.active_object
    ground.name = "Ground"
    gmat = bpy.data.materials.new("Ground")
    gmat.use_nodes = True
    princ = gmat.node_tree.nodes.get("Principled BSDF")
    princ.inputs["Base Color"].default_value = srgb3(pal["ground"], 1)
    princ.inputs["Roughness"].default_value = 0.85
    ground.data.materials.append(gmat)

    def add_area(name, loc, rot, color, energy, size):
        light = bpy.data.lights.new(name=name, type="AREA")
        light.energy = energy
        light.size = size
        light.color = color
        light.shape = "DISK"
        obj = bpy.data.objects.new(name, light)
        obj.location = loc
        obj.rotation_euler = rot
        bpy.context.scene.collection.objects.link(obj)

    key = rbx_to_b(cam_pos) + Vector((8, -6, 18))
    fill = rbx_to_b(look) + Vector((-16, 10, 12))
    rim = rbx_to_b(look) + Vector((6, 18, 10))
    add_area("Key", key, (math.radians(50), 0, math.radians(20)), srgb3(pal["key"]), 420, 20)
    add_area("Fill", fill, (math.radians(65), 0, math.radians(-40)), srgb3(pal["fill"]), 220, 28)
    add_area("Rim", rim, (math.radians(20), 0, math.radians(180)), srgb3(pal["rim"]), 80, 16)

    # Camera
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = float(lens)
    cam_data.clip_start = 0.2
    cam_data.clip_end = 800
    cam_data.dof.use_dof = False
    cam_obj = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = rbx_to_b(cam_pos)
    target = rbx_to_b(look)
    direction = target - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.dof.focus_distance = direction.length
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    return cam_obj


def add_text(text, loc_rbx, cam_pos, size=1.2, color=(0.18, 0.14, 0.22, 1), align="CENTER"):
    curve = bpy.data.curves.new(name=text, type="FONT")
    curve.body = text
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.04
    obj = bpy.data.objects.new(text, curve)
    loc = rbx_to_b(loc_rbx)
    obj.location = loc
    # Readable face is +Z; point it at the camera.
    obj.rotation_euler = (rbx_to_b(cam_pos) - loc).to_track_quat("Z", "Y").to_euler()
    # Pre-flip so the compositor X correction does not reverse readable labels.
    obj.scale = (-1.0, 1.0, 1.0)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new(name="InkText")
    mat.use_nodes = True
    princ = mat.node_tree.nodes.get("Principled BSDF")
    princ.inputs["Base Color"].default_value = color
    princ.inputs["Roughness"].default_value = 0.6
    obj.data.materials.append(mat)
    return obj


def add_labels(family, scene_name, cam_pos):
    if scene_name == "podium":
        add_text("Auntie Roch", (-16, 9.2, -31.6), cam_pos, size=0.65)
        add_text("2nd", (10.8, 3.1, -31.5), cam_pos, size=0.65)
        add_text("1st", (15, 3.8, -31.5), cam_pos, size=0.75)
        add_text("3rd", (19.2, 2.8, -31.5), cam_pos, size=0.65)
    if scene_name == "tour":
        add_text("Room 2 of 3", (0, 13.6, 52), cam_pos, size=1.0)


def render_scene(name, scene_data, outfile):
    clean_scene()
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    cam = scene_data["camera"]
    family = scene_data.get("family") or "hearth"
    setup_world(family, cam["look"], cam["pos"], name, lens=cam.get("lens") or 35,
                grade_light=(scene_data.get("grade") or {}).get("light"))
    size = scene_data.get("size") or SIZE
    bpy.context.scene.render.resolution_x = int(size[0])
    bpy.context.scene.render.resolution_y = int(size[1])
    apply_grade(scene_data.get("grade"), family)
    skip_signs = name in ("hearth", "winter", "tour", "ginger") or "_" in name
    cam_y = cam["pos"][1]
    for part in scene_data["parts"]:
        n = part.get("name") or ""
        if skip_signs and n == "Sign":
            continue
        if n == "Cone":
            continue
        ceil = part.get("ceil")
        if part.get("hidden") and ceil is None:
            # Same as earlier rounds: hidden window glass etc. stay out.
            continue
        # Hidden light hosts, and ceilings the camera is above (the client
        # cutaway hides those in game): lights only.
        if part.get("hidden") or (ceil is not None and cam_y > ceil - 0.5):
            part_lights(part, col, n or "hidden")
            continue
        obj = add_part(part, col)
        if ceil is not None and obj is not None:
            # CastShadow is off on the ceiling in game: it must not block the sky.
            obj.visible_shadow = False
    add_labels(scene_data.get("family"), name, cam["pos"])
    bpy.context.scene.render.filepath = outfile
    bpy.ops.render.render(write_still=True)
    print("wrote", outfile, "parts", len(scene_data["parts"]))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    scenes_path = args[0] if args else SCENES
    out_dir = args[1] if len(args) > 1 else OUT_DIR
    data = json.load(open(scenes_path))
    mapping = {
        "hearth_parts": "mesh-hearth-before.png",
        "hearth_mesh": "mesh-hearth-after.png",
        "kitchen_parts": "mesh-kitchen-before.png",
        "kitchen_mesh": "mesh-kitchen-after.png",
        "showroom_parts": "mesh-showroom-before.png",
        "showroom_mesh": "mesh-showroom-after.png",
        "nook_mesh": "shell-nook-frost.png",
        "nookwinter_mesh": "shell-nook-winter.png",
        "finishes_mesh": "finish-row.png",
        "hearth": "rgu3d-v6-hearth.png",
    }
    # Extra cameras on an existing scene: name -> (scene, camera, size).
    views = {
        "showroom_close": ("showroom_mesh", {"pos": [2, 12, 58], "look": [0, 7, 30], "lens": 24}, (1024, 576)),
        "kitchen_close": ("kitchen_mesh", {"pos": [2, 12, 58], "look": [0, 7, 30], "lens": 24}, (1024, 576)),
        "showroom_eye": ("showroom_mesh", {"pos": [9, 6.5, 50], "look": [-3, 9.5, 27], "lens": 20}, (1280, 720)),
        # The in-game build camera (Bases.camera room rig): the ceiling is cut away.
        "hearth_build": ("hearth_mesh", {"pos": [0, 24, 76], "look": [0, 5, 40], "lens": 16}, (1280, 720)),
        "nook_eye": ("nook_mesh", {"pos": [-8, 6.5, 50], "look": [3, 9, 27], "lens": 20}, (1280, 720)),
    }
    wanted = args[2:] or [k for k in mapping if k in data["scenes"]]
    for key in wanted:
        MESH_CACHE.clear()
        if key in views:
            base, cam, size = views[key]
            scene = dict(data["scenes"][base])
            scene["camera"] = cam
            scene["size"] = list(size)
            render_scene(base.split("_")[0] + "_view", scene, os.path.join(out_dir, key + ".png"))
            continue
        render_scene(key, data["scenes"][key], os.path.join(out_dir, mapping.get(key, key + ".png")))


if __name__ == "__main__":
    main()
