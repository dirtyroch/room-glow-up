"""Render a hero still of each exported mesh, using only the exported FBX and
baked maps (what Roblox would get), with SurfaceAppearance TintMask emulated.

blender -b -P tools/meshes/hero.py -- <outdir> <itemId>[:r,g,b] ...
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import palette  # noqa: E402


def lin(c):
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c)


def item_dir(item_id):
    d = os.path.join(ROOT, "assets", "meshes", item_id)
    return d if os.path.isdir(d) else os.path.join(ROOT, "assets", "shell", item_id)


def textured_material(item_id, tint_rgb, name=None, finish=None):
    """finish: None or (rough_file, metal_file_or_None, alpha) from palette.FINISH."""
    d = item_dir(item_id)
    m = bpy.data.materials.new(name or ("tex_" + item_id))
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def tex(fname, non_color):
        p = os.path.join(d, fname)
        if not os.path.exists(p):
            return None
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(p, check_existing=True)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        n.image.alpha_mode = "STRAIGHT"
        return n

    c = tex("color.png", False)
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(c.outputs["Color"], mul.inputs[6])
    mul.inputs[7].default_value = (*lin(tint_rgb), 1)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    nt.links.new(c.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(c.outputs["Color"], mix.inputs[6])
    nt.links.new(mul.outputs[2], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    r = tex((finish[0] + ".png") if finish and finish[0] else "roughness.png", True)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    mt = tex((finish[1] + ".png") if finish and finish[1] else "metalness.png", True)
    if mt:
        nt.links.new(mt.outputs["Color"], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Metallic"].default_value = 0
    n = tex("normal.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.45
    e = tex("emissive.png", True)
    if e:
        em = nt.nodes.new("ShaderNodeMix"); em.data_type = "RGBA"; em.blend_type = "MULTIPLY"
        em.inputs["Factor"].default_value = 1.0
        nt.links.new(mix.outputs[2], em.inputs[6])
        nt.links.new(e.outputs["Color"], em.inputs[7])
        nt.links.new(em.outputs[2], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.5
    if finish and finish[2] < 1:
        bsdf.inputs["Alpha"].default_value = finish[2]
        m.blend_method = "BLEND"
    return m


def import_item(item_id, tint_rgb, finish=None):
    path = os.path.join(item_dir(item_id), item_id + ".fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="-Z", axis_up="Y")
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    obj = objs[0]
    obj.data.materials.clear()
    obj.data.materials.append(textured_material(item_id, tint_rgb, finish=finish))
    return obj


def studio(target, radius, warm=(1.0, 0.95, 0.92), wall_y=None):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 48
    scene.eevee.use_shadows = True
    scene.eevee.use_raytracing = True
    scene.eevee.ray_tracing_options.resolution_scale = "1"
    scene.eevee.use_gtao = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*lin((0.93, 0.95, 1.0)), 1)
    bg.inputs["Strength"].default_value = 0.9
    # Curved backdrop.
    bpy.ops.mesh.primitive_plane_add(size=radius * 30, location=(target.x, target.y, 0))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fb = fm.node_tree.nodes["Principled BSDF"]
    fb.inputs["Base Color"].default_value = (*lin(warm), 1)
    fb.inputs["Roughness"].default_value = 0.9
    floor.data.materials.append(fm)
    wy = wall_y if wall_y is not None else target.y + radius * 3.5
    bpy.ops.mesh.primitive_plane_add(size=radius * 30, location=(target.x, wy, radius * 6), rotation=(math.radians(90), 0, 0))
    wall = bpy.context.active_object
    wall.data.materials.append(fm)

    def area(name, loc, energy, size, color=(1, 1, 1)):
        L = bpy.data.lights.new(name, "AREA")
        L.energy = energy
        L.size = size
        L.color = color
        o = bpy.data.objects.new(name, L)
        scene.collection.objects.link(o)
        o.location = loc
        d = target - Vector(loc)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    s = radius
    area("key", target + Vector((-2.2 * s, -3.0 * s, 3.4 * s)), 900 * s * s / 9, 3 * s, (1.0, 0.97, 0.92))
    area("fill", target + Vector((3.2 * s, -2.2 * s, 1.6 * s)), 380 * s * s / 9, 4 * s, (0.92, 0.95, 1.0))
    area("rim", target + Vector((1.5 * s, 3.0 * s, 3.2 * s)), 500 * s * s / 9, 2 * s, (1.0, 0.92, 0.9))


def camera(target, radius, az=-35, el=22, lens=50):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    co = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(co)
    dist = radius * 2.0 * 50 / lens * 1.55
    a, e = math.radians(az), math.radians(el)
    co.location = target + Vector((dist * math.sin(a) * math.cos(e) * -1, -dist * math.cos(a) * math.cos(e), dist * math.sin(e)))
    co.rotation_euler = (target - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co


def render_one(item_id, tint_rgb, out, finish=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj = import_item(item_id, tint_rgb, finish)
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    if mn.z < -0.01:
        # Hanging pieces (curtains) start at the rod: stand them on the floor.
        obj.location.z -= mn.z
        mx.z -= mn.z; mn.z = 0
    meta_path = os.path.join(item_dir(item_id), "meta.json")
    mount = json.load(open(meta_path)).get("mount") if os.path.exists(meta_path) else None
    if mount == "wall":
        # Hang it on the backdrop wall at eye height.
        obj.location.z += 1.5
        mn.z += 1.5; mx.z += 1.5
    target = (mn + mx) / 2
    radius = (mx - mn).length / 2
    studio(target, radius, wall_y=(mx.y + 0.01) if mount == "wall" else None)
    flat = (mx - mn).z < 0.6
    if mount == "wall":
        camera(target, radius, az=-22, el=8)
    else:
        camera(target, radius * (0.8 if flat else 1.0), el=(58 if flat else 22))
    sc = bpy.context.scene
    px = int(os.environ.get("HERO_SIZE", "1024"))
    sc.render.resolution_x = px
    sc.render.resolution_y = px
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("HERO", out, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    outdir = args[0]
    for spec in args[1:]:
        # itemId or itemId@Finish (Wood, Fabric, Metal, Glass, Slate)
        item_id, _, fin = spec.partition("@")
        tint = palette.tint_for(item_id)
        if fin:
            tint, maps = palette.finish(tint, fin)
            render_one(item_id, tint, os.path.join(outdir, "mesh-%s-%s.png" % (item_id, fin.lower())), maps)
        else:
            render_one(item_id, tint, os.path.join(outdir, "mesh-" + item_id + ".png"))
