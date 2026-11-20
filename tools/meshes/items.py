"""Per-item builders. Each takes the standard material dict and returns extra meta.

Front faces -Y. Floor at z = 0. Footprint centered on the origin.
"""
import math
import os
import random

import lib
from lib import (CELL, box, cushion, cyl, lathe, sphere, tube, ring, extrude_outline, transform,
                 duplicate, leaf_blade, material, rgb, bend, cut, star_outline, frond, assign)

HERE = os.path.dirname(os.path.abspath(__file__))
BUILDERS = {}


def item(fn):
    BUILDERS[fn.__name__] = fn
    return fn


def finish(o, m, angle=60):
    return lib._finish(o, m, True, angle)


def tapered_leg(x, y, h, top_r, bot_r, m, splay=0.0, name="leg", segs=16):
    o = cyl(bot_r, h, (0, 0, 0), m, segs=segs, bevel=0.03, r2=top_r, name=name)
    sx = -splay if x < 0 else splay
    sy = -splay if y < 0 else splay
    return transform(o, (x, y, 0), (-sy, sx, 0))


def mug(x, y, z, r, h, m_body, m_fill, handle=True, yaw=0.0):
    t = 0.07
    prof = [(0, 0), (r * 0.9, 0), (r, 0.06), (r, h - 0.03), (r - 0.02, h), (r - t, h), (r - t, t + 0.04), (0, t + 0.04)]
    o = lathe(prof, (x, y, z), m_body, segs=24, cap_top=False, cap_bottom=False, angle=50)
    lathe([(0, h * 0.78), (r - t + 0.005, h * 0.78)], (x, y, z), m_fill, segs=24, cap_top=False, cap_bottom=False)
    if handle:
        hx = x + math.cos(yaw) * r
        hy = y + math.sin(yaw) * r
        ox, oy = math.cos(yaw), math.sin(yaw)
        tube([(hx - ox * 0.05, hy - oy * 0.05, z + h * 0.8), (hx + ox * r * 0.55, hy + oy * r * 0.55, z + h * 0.7),
              (hx + ox * r * 0.55, hy + oy * r * 0.55, z + h * 0.3), (hx - ox * 0.05, hy - oy * 0.05, z + h * 0.22)],
             r * 0.11, m_body, segs=8, resolution=6)
    return o


def book(x, y, z, w, d, h, color, yaw=0.0, tilt=0.0, name="book"):
    m = material("book_%d_%d_%d" % tuple(int(c * 255) for c in color), color, "paper", rough=0.6)
    o = box((w, d, h), (0, 0, 0), m, bevel=min(w, d, h) * 0.15, seg=2, name=name)
    return transform(o, (x, y, z + h / 2), (0, tilt, yaw))


BOOK_COLORS = [rgb(196, 84, 84), rgb(70, 110, 160), rgb(236, 196, 96), rgb(96, 150, 120), rgb(240, 236, 226),
               rgb(150, 110, 170), rgb(222, 140, 110), rgb(60, 70, 90), rgb(180, 200, 214)]


# ------------------------------------------------------------------ seating

def sofa_frame(M, w, d, h, leg_m, arm_style="track", tufted=False):
    fab = M["fabric"]
    leg_h = 0.7
    base_top = leg_h + 0.75
    arm_w = 0.85
    inner = w - 2 * arm_w
    cushion((inner + 0.1, d - 0.3, base_top - leg_h), (0, -0.05, leg_h + (base_top - leg_h) / 2), fab, round_=0.2, puff=0.0, cuts=2)
    back_h = h * (0.9 if tufted else 0.84)
    back_d = 1.05 if tufted else 0.75
    back = cushion((w - 0.2, back_d, back_h - leg_h), (0, d / 2 - back_d / 2 - 0.05, leg_h + (back_h - leg_h) / 2), fab,
                   round_=0.35, puff=0.12 if tufted else 0.05, cuts=5 if tufted else 3, front_puff=0.04 if tufted else 0)
    arm_h = h * 0.64
    for sx in (-1, 1):
        ax = sx * (w / 2 - arm_w / 2)
        if arm_style == "roll":
            body_h = arm_h - leg_h - 0.3
            cushion((arm_w * 0.9, d - 0.3, body_h), (ax, 0, leg_h + body_h / 2), fab, round_=0.25, puff=0.0, cuts=2)
            r = arm_w * 0.58
            tube([(ax + sx * 0.12, -d / 2 + 0.2, arm_h - r * 0.55), (ax + sx * 0.12, d / 2 - 0.35, arm_h - r * 0.55)], r, fab, segs=16, resolution=2)
            # Scroll face on the front of the roll.
            lathe([(0, 0), (r * 0.96, 0), (r * 1.02, 0.08), (r * 0.9, 0.14), (0, 0.14)], (0, 0, 0), fab, segs=20,
                  name="scroll")
            sc = [o for o in lib.bpy.context.scene.objects if o.name.startswith("scroll")][-1]
            transform(sc, (ax + sx * 0.12, -d / 2 + 0.12, arm_h - r * 0.55), (math.radians(90), 0, 0))
        else:
            cushion((arm_w, d - 0.15, arm_h - leg_h), (ax, 0, leg_h + (arm_h - leg_h) / 2), fab, round_=0.42, puff=0.06, cuts=3)
    return leg_h, base_top, inner, back_h, back_d


@item
def butter_bench(M):
    w, d, h = 2 * CELL, CELL, 0.85 * CELL
    fab = M["fabric"]
    leg_h, base_top, inner, back_h, _ = sofa_frame(M, w, d, h, M["walnut"])
    seat_h = 0.8
    cw = inner / 2
    for i in range(2):
        cx = -inner / 2 + cw * (i + 0.5)
        cushion((cw - 0.08, d - 1.15, seat_h), (cx, -0.45, base_top + seat_h / 2 - 0.05), fab, round_=0.4, puff=0.1, front_puff=0.06, cuts=4)
    for i in range(2):
        cx = -inner / 2 + cw * (i + 0.5)
        c = cushion((cw - 0.1, 0.95, back_h - base_top - 0.35), (0, 0, 0), fab, round_=0.45, puff=0.12, front_puff=0.12, cuts=4)
        transform(c, (cx, d / 2 - 1.05, base_top + seat_h - 0.3 + (back_h - base_top - 0.35) / 2), (math.radians(-10), 0, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_leg(sx * (w / 2 - 0.55), sy * (d / 2 - 0.55), leg_h + 0.05, 0.17, 0.1, M["walnut"], splay=math.radians(8))
    for k, (px_, rot) in enumerate(((-(inner / 2) + 1.05, 18), ((inner / 2) - 1.05, -16))):
        m = M["cream"] if k == 0 else material("pillow_sage", rgb(164, 190, 160), "fabric", rough=0.85, sheen=0.3)
        p = cushion((1.6, 0.5, 1.6), (0, 0, 0), m, round_=0.5, puff=0.3, front_puff=0.35, cuts=4)
        transform(p, (px_, d / 2 - 1.75, base_top + seat_h + 0.6), (math.radians(-14), 0, math.radians(rot)))
    return {}


@item
def lavender_settee(M):
    w, d, h = 2 * CELL, CELL, 0.85 * CELL
    fab = M["fabric"]
    leg_h, base_top, inner, back_h, back_d = sofa_frame(M, w, d, h, M["walnut"], arm_style="roll", tufted=True)
    seat_h = 0.75
    cushion((inner - 0.05, d - 1.4, seat_h), (0, -0.55, base_top + seat_h / 2 - 0.05), fab, round_=0.4, puff=0.08, front_puff=0.08, cuts=5)
    # Tufting buttons in a diamond grid on the back.
    yb = d / 2 - back_d - 0.02
    z0, z1 = base_top + seat_h + 0.3, back_h - 0.45
    for row in range(3):
        z = z0 + (z1 - z0) * row / 2
        n = 6 if row % 2 == 0 else 5
        for i in range(n):
            x = -inner / 2 + 0.5 + (inner - 1.0) * (i + (0.0 if row % 2 == 0 else 0.5)) / 5
            sphere(0.11, (x, yb + 0.04, z), fab, scale=(1, 0.6, 1), segs=10, rings=6, name="button")
    # Turned legs with brass cups.
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.5), sy * (d / 2 - 0.5)
            lathe([(0, 0), (0.13, 0), (0.15, 0.12), (0.1, 0.18), (0.12, 0.35), (0.2, 0.5), (0.13, 0.62), (0.16, 0.72), (0, 0.72)],
                  (x, y, 0), M["walnut"], segs=14)
            cyl(0.15, 0.1, (x, y, 0), M["brass"], segs=14, bevel=0.02)
    p = cushion((1.5, 0.5, 1.5), (0, 0, 0), M["cream"], round_=0.5, puff=0.3, front_puff=0.35, cuts=4)
    transform(p, (inner / 2 - 0.95, d / 2 - 1.65, base_top + seat_h + 0.55), (math.radians(-14), 0, math.radians(-20)))
    return {}


@item
def coral_armchair(M):
    fab = M["fabric"]
    leg_h = 0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_leg(sx * 1.35, sy * 1.25, leg_h + 0.05, 0.15, 0.09, M["walnut"], splay=math.radians(10))
    cushion((3.6, 3.5, 0.75), (0, 0.1, leg_h + 0.375), fab, round_=0.45, puff=0.0, cuts=3)
    # Barrel back: a thick padded wall wrapped around the seat.
    R = 1.85
    span = math.radians(118)
    L = 2 * R * span
    wall = box((L, 0.75, 3.6), (0, 0.35, 0), fab, bevel=0.32, seg=4, cuts=10, name="barrel")
    top = 5.0
    for v in wall.data.vertices:
        v.co.z += leg_h + 0.2 + 1.8
    bend(wall, R, (0, 0.15))
    for v in wall.data.vertices:
        a = math.atan2(v.co.x, v.co.y - 0.15)
        f = 1.0 - 0.36 * (abs(a) / span) ** 2.2
        base = leg_h + 0.2
        v.co.z = base + (v.co.z - base) * f
    finish(wall, fab)
    # Seat cushion, tucked into the barrel.
    cushion((3.1, 3.0, 0.75), (0, -0.25, leg_h + 0.75 + 0.35), fab, round_=0.45, puff=0.14, front_puff=0.1, cuts=4)
    p = cushion((1.45, 0.45, 1.25), (0, 0, 0), material("pillow_cream", rgb(250, 244, 232), "knit", rough=0.9, bump=0.6), round_=0.5, puff=0.3, front_puff=0.3, cuts=4)
    transform(p, (0, 0.95, leg_h + 2.5), (math.radians(-12), 0, 0))
    return {}


@item
def unc_chair(M):
    lea = M["leather"]
    # Base and feet.
    cushion((4.2, 3.6, 1.3), (0, 0.5, 0.25 + 0.65), lea, round_=0.25, puff=0.0, cuts=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.4, 0.4, 0.3), (sx * 1.7, 0.5 + sy * 1.4, 0.15), M["rubber"], bevel=0.06)
    # Plush arms with rolled fronts.
    for sx in (-1, 1):
        cushion((0.9, 3.7, 1.9), (sx * 1.65, 0.45, 1.1 + 0.95), lea, round_=0.45, puff=0.14, front_puff=0.1, cuts=4)
    # Seat.
    cushion((2.5, 3.0, 0.8), (0, 0.15, 1.55 + 0.4), lea, round_=0.45, puff=0.15, front_puff=0.12, cuts=4)
    # Extended footrest.
    cushion((2.6, 1.05, 0.55), (0, -1.75, 1.35), lea, round_=0.45, puff=0.12, cuts=3)
    box((0.12, 0.9, 0.12), (-0.9, -1.15, 1.05), M["steel"], bevel=0.03)
    box((0.12, 0.9, 0.12), (0.9, -1.15, 1.05), M["steel"], bevel=0.03)
    # Pillow-top back: three stacked bolsters, leaning back.
    for i in range(3):
        c = cushion((2.75, 1.05, 1.15), (0, 0, 0), lea, round_=0.5, puff=0.2, front_puff=0.25, cuts=4)
        transform(c, (0, 1.55 + i * 0.22, 2.75 + i * 1.02), (math.radians(-14), 0, 0))
    cushion((3.0, 0.7, 3.3), (0, 2.1, 2.3 + 1.65), lea, round_=0.4, puff=0.08, cuts=3)
    # TV remote on the right arm.
    rem = box((0.38, 1.05, 0.14), (1.65, -0.2, 3.1), M["black"], bevel=0.06, seg=2)
    for i in range(4):
        box((0.08, 0.08, 0.04), (1.58 + (i % 2) * 0.14, -0.45 + (i // 2) * 0.2, 3.18), material("btn_red" if i == 0 else "btn_grey", rgb(214, 70, 70) if i == 0 else rgb(150, 150, 156), "plain", rough=0.4), bevel=0.015, seg=1)
    # Reading glasses on the left arm.
    gm = material("frames", rgb(96, 58, 40), "plain", rough=0.35)
    for sx in (-1, 1):
        ring(0.2, 0.035, (-1.65 + sx * 0.24, -0.4, 3.12), gm, segs=20, minor_segs=6, rot=(0, 0, 0), name="rim")
        lathe([(0, 0), (0.19, 0), (0.19, 0.015), (0, 0.015)], (-1.65 + sx * 0.24, -0.4, 3.11), M["glass"], segs=20)
    tube([(-1.69, -0.4, 3.13), (-1.65, -0.38, 3.17), (-1.61, -0.4, 3.13)], 0.03, gm, segs=6)
    for sx in (-1, 1):
        tube([(-1.65 + sx * 0.43, -0.4, 3.12), (-1.65 + sx * 0.42, -0.1, 3.13), (-1.65 + sx * 0.38, 0.2, 3.1)], 0.025, gm, segs=6)
    return {}


# ------------------------------------------------------------------ tables

@item
def cocoa_table(M):
    w, d, h = 2 * CELL, CELL, 0.7 * CELL
    paint = M["paint"]
    box((w - 0.5, d - 0.45, 0.32), (0, 0, h - 0.16), M["oak"], bevel=0.12, seg=3)
    box((w - 1.2, d - 1.1, 0.45), (0, 0, h - 0.32 - 0.22), paint, bevel=0.06, seg=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_leg(sx * (w / 2 - 0.75), sy * (d / 2 - 0.65), h - 0.3, 0.2, 0.13, paint, splay=math.radians(5))
    box((w - 1.6, d - 1.35, 0.16), (0, 0, 0.85), M["oak"], bevel=0.05, seg=2)
    # Tabletop styling: two mugs of cocoa, a book stack, a small candle.
    cocoa = material("cocoa", rgb(110, 66, 44), "plain", rough=0.25)
    mug(-2.2, -0.4, h, 0.38, 0.72, M["white"], cocoa, yaw=-0.5)
    mug(-1.2, 0.5, h, 0.38, 0.72, material("mug_sage", rgb(170, 200, 176), "ceramic", rough=0.25), cocoa, yaw=0.4)
    book(1.8, 0.2, h, 2.0, 1.4, 0.24, rgb(70, 110, 160), yaw=0.15)
    book(1.85, 0.15, h + 0.24, 1.8, 1.3, 0.2, rgb(236, 196, 96), yaw=-0.1)
    cyl(0.3, 0.55, (3.2, -0.6, h), M["white"], segs=18, bevel=0.03)
    cyl(0.02, 0.12, (3.2, -0.6, h + 0.55), M["black"], segs=6, bevel=0)
    # Books on the shelf below.
    book(-2.4, 0.0, 0.93, 1.9, 1.5, 0.3, rgb(196, 84, 84), yaw=0.05)
    book(-2.35, 0.0, 1.23, 1.7, 1.3, 0.22, rgb(240, 236, 226), yaw=-0.12)
    return {}


@item
def round_side(M):
    h = 0.7 * CELL
    lathe([(0, 0), (1.35, 0), (1.38, 0.06), (1.3, 0.16), (1.0, 0.26), (0.5, 0.55), (0.28, 1.0), (0.22, 1.8), (0.26, 2.6), (0.5, 2.95), (0.7, h - 0.26), (0, h - 0.26)],
          (0, 0, 0), M["paint"], segs=36)
    lathe([(0, 0), (1.9, 0), (2.02, 0.06), (2.05, 0.14), (2.02, 0.22), (1.94, 0.26), (0, 0.26)], (0, 0, h - 0.26), M["oak"], segs=48)
    # Bud vase with sprigs, and a little book.
    lathe([(0, 0), (0.32, 0), (0.42, 0.25), (0.36, 0.6), (0.16, 0.85), (0.14, 1.05), (0.19, 1.12), (0.12, 1.12), (0.1, 0.9), (0, 0.9)],
          (-0.45, 0.35, h), M["white"], segs=24)
    random.seed(4)
    for i in range(4):
        a = i * 1.6 + 0.3
        tip = (-0.45 + math.cos(a) * 0.7, 0.35 + math.sin(a) * 0.6, h + 2.0 + 0.25 * (i % 2))
        tube([(-0.45, 0.35, h + 0.95), (-0.45 + math.cos(a) * 0.3, 0.35 + math.sin(a) * 0.25, h + 1.5), tip], 0.025, M["leaf"], segs=6)
        for k in range(5):
            t = 0.35 + k * 0.15
            lp = (-0.45 + math.cos(a) * 0.7 * t, 0.35 + math.sin(a) * 0.6 * t, h + 0.95 + 1.1 * t)
            lb = leaf_blade(0.28, 0.2, bend=0.2, segs=3)
            finish(lb, material("eucalyptus", rgb(150, 182, 164), "leaf", rough=0.5))
            transform(lb, lp, (0, math.radians(-20), a + (1.4 if k % 2 else -1.4)))
    book(0.55, -0.35, h, 1.3, 0.95, 0.2, rgb(150, 110, 170), yaw=0.4)
    return {}


# ------------------------------------------------------------------ lighting

def drum_shade(z0, z1, r0, r1, m_out, m_in):
    t = 0.05
    lathe([(r0, z0), (r1, z1), (r1 - t, z1), (r0 - t, z0)], (0, 0, 0), m_out, segs=40, cap_top=False, cap_bottom=False, angle=30)
    # Inner liner (lit side) is a separate cream surface so it glows warm.
    lathe([(r0 - t - 0.005, z0 + 0.02), (r1 - t - 0.005, z1 - 0.02)], (0, 0, 0), m_in, segs=40, cap_top=False, cap_bottom=False)
    lib.bpy.context.active_object.data.flip_normals()
    ring(r0 - t / 2, 0.035, (0, 0, z0), m_out, segs=40, minor_segs=6)
    ring(r1 - t / 2, 0.035, (0, 0, z1), m_out, segs=40, minor_segs=6)


@item
def hearth_lamp(M):
    h = 1.35 * CELL
    lathe([(0, 0), (1.0, 0), (1.05, 0.08), (0.95, 0.26), (0.5, 0.36), (0.2, 0.4), (0, 0.4)], (0, 0, 0), M["marble"], segs=40)
    cyl(0.085, 4.4, (0, 0, 0.38), M["brass"], segs=16, bevel=0.0)
    sphere(0.16, (0, 0, 2.3), M["brass"], scale=(1, 1, 0.8), segs=16, rings=8)
    lathe([(0, 4.65), (0.2, 4.65), (0.22, 4.95), (0, 4.95)], (0, 0, 0), M["brass"], segs=16)
    sphere(0.3, (0, 0, 5.2), M["bulb"], segs=20, rings=12)
    # Harp.
    for a in (0, math.pi):
        tube([(0, 0, 4.8), (0.5 * math.cos(a), 0.5 * math.sin(a), 5.4), (0.05 * math.cos(a), 0.05 * math.sin(a), 6.05)], 0.03, M["brass"], segs=6)
    drum_shade(4.5, 6.15, 1.45, 1.2, M["fabric"], M["cream"])
    sphere(0.12, (0, 0, 6.22), M["brass"], segs=12, rings=8)
    return {"light": {"at": [0, 5.2, 0], "brightness": 0.6, "range": 12}}


@item
def reading_lamp(M):
    h = 1.35 * CELL
    # Weighted base at the back, arc reaching forward, dome shade over the front.
    bx, by = 0.0, 1.55
    lathe([(0, 0), (0.95, 0), (1.0, 0.1), (0.9, 0.3), (0.35, 0.42), (0, 0.42)], (bx, by, 0), M["marble"], segs=40)
    tube([(bx, by, 0.35), (bx, by + 0.05, 3.5), (bx, by - 0.4, 5.9), (bx, -0.3, 6.25), (bx, -1.1, 5.7)], 0.08, M["brass"], segs=10, resolution=12)
    sx, sy, sz = bx, -1.1, 5.55
    lathe([(0.02, 0.0), (0.25, 0.02), (0.75, -0.25), (1.05, -0.75), (1.12, -1.05), (1.06, -1.06), (0.98, -0.8), (0.7, -0.33), (0.22, -0.06), (0.02, -0.04)],
          (sx, sy, sz + 0.1), M["paint"], segs=40, cap_top=False, cap_bottom=False, angle=50)
    sphere(0.28, (sx, sy, sz - 0.55), M["bulb"], segs=18, rings=10)
    # Floor switch cord.
    tube([(bx + 0.6, by, 0.05), (bx + 1.2, by - 0.8, 0.04), (bx + 1.4, by - 1.6, 0.04)], 0.035, M["black"], segs=6)
    return {"light": {"at": [0, 5.0, 1.1], "brightness": 0.6, "range": 12}}


# ------------------------------------------------------------------ shelves

@item
def mantel_shelf(M):
    w, d, h = 2 * CELL, CELL, 0.9 * CELL
    paint = M["paint"]
    stone = M["marble"]
    # Hearth slab.
    box((w - 0.2, 2.4, 0.3), (0, -0.95, 0.15), stone, bevel=0.06)
    # Chimney breast and surround.
    box((w - 0.6, 1.6, h - 0.4), (0, 1.5, (h - 0.4) / 2), paint, bevel=0.06)
    for sx in (-1, 1):
        box((1.35, 1.0, h - 0.75), (sx * (w / 2 - 0.95), 0.3, 0.3 + (h - 1.05) / 2), paint, bevel=0.08)
        box((1.55, 1.15, 0.3), (sx * (w / 2 - 0.95), 0.3, 0.45), paint, bevel=0.05)
        box((1.55, 1.15, 0.25), (sx * (w / 2 - 0.95), 0.3, h - 1.15), paint, bevel=0.05)
    box((w - 1.0, 1.0, 0.8), (0, 0.3, h - 0.95), paint, bevel=0.08)
    box((w, 1.75, 0.3), (0, 0.25, h - 0.42), M["oak"], bevel=0.1, seg=3)
    # Firebox.
    soot = material("soot", rgb(48, 40, 40), "soil", rough=0.95, color2=rgb(30, 26, 26))
    box((w - 3.6, 0.12, h - 1.65), (0, 0.62, 0.3 + (h - 1.65) / 2), soot, bevel=0.02)
    for sx in (-1, 1):
        o = box((0.2, 0.9, h - 1.65), (sx * (w / 2 - 1.75), 0.45, 0.3 + (h - 1.65) / 2), soot, bevel=0.02)
    # Logs and embers.
    bark = material("bark", rgb(104, 72, 52), "wood", rough=0.9, color2=rgb(70, 46, 34), bump=0.4)
    for (x, y, rz, l) in ((-0.5, 0.35, 0.25, 2.6), (0.6, 0.45, -0.3, 2.4), (0.0, 0.1, 0.0, 2.2)):
        o = cyl(0.26, l, (0, 0, 0), bark, segs=12, bevel=0.06)
        transform(o, (x - l / 2 * math.cos(rz), y - l / 2 * math.sin(rz), 0.56 if y > 0.2 else 0.85), (0, math.radians(90), rz))
    ember = material("ember", rgb(255, 150, 60), "plain", rough=0.5, emit=1.0)
    random.seed(2)
    for i in range(9):
        sphere(0.12 + random.random() * 0.08, (random.uniform(-1.3, 1.3), random.uniform(0.0, 0.6), 0.36), ember, scale=(1, 1, 0.5), segs=8, rings=5)
    outer = material("flame_out", rgb(255, 140, 60), "plain", rough=0.5, emit=1.0)
    inner = material("flame_in", rgb(255, 222, 120), "plain", rough=0.5, emit=1.0)
    for (x, sc, lean) in ((-0.55, 0.75, -0.18), (0.45, 0.65, 0.2), (0.0, 1.0, 0.05), (-0.25, 0.55, -0.1), (0.25, 0.6, 0.12)):
        prof = [(0, 0), (0.22 * sc, 0.1), (0.24 * sc, 0.3 * sc), (0.16 * sc, 0.65 * sc), (0.07 * sc, 0.95 * sc), (0, 1.15 * sc)]
        o = lathe(prof, (0, 0, 0), outer, segs=12)
        transform(o, (x, 0.25, 0.9), (0, lean, 0), (1.0, 0.6, 1.0))
        o = lathe([(r * 0.6, z * 0.75) for r, z in prof], (0, 0, 0), inner, segs=10)
        transform(o, (x, 0.17, 0.92), (0, lean, 0), (1.0, 0.6, 1.0))
    # Mantel styling: candlesticks and a little garland.
    for sx in (-1, 1):
        lathe([(0, 0), (0.26, 0), (0.24, 0.08), (0.08, 0.2), (0.07, 0.6), (0.16, 0.7), (0.1, 0.75), (0, 0.75)], (sx * 3.6, 0.25, h - 0.27), M["brass"], segs=18)
        cyl(0.1, 0.95, (sx * 3.6, 0.25, h + 0.45), M["white"], segs=14, bevel=0.02)
    random.seed(9)
    for i in range(26):
        t = i / 25
        x = -3.0 + 6.0 * t
        lb = leaf_blade(0.42, 0.22, bend=0.3, segs=3)
        finish(lb, M["leaf"])
        transform(lb, (x, -0.55, h - 0.25 - 0.1 * math.sin(math.pi * t)), (math.radians(random.uniform(60, 110)), 0, math.radians(random.uniform(-80, 80) + (180 if i % 2 else 0))))
    berry = material("berry", rgb(210, 50, 60), "ceramic", rough=0.25)
    for i in range(9):
        sphere(0.09, (-2.7 + i * 0.68, -0.62, h - 0.28 - 0.1 * math.sin(math.pi * i / 8)), berry, segs=8, rings=6)
    return {"light": {"at": [0, 1.2, -0.2], "brightness": 0.8, "range": 12, "color": [255, 170, 100]}}


@item
def book_ledge(M):
    w, d, h = 2 * CELL, CELL, 0.8 * CELL
    paint = M["paint"]
    dep = 2.2
    y0 = 0.9
    box((w - 0.3, dep, 0.22), (0, y0, h - 0.11 - 0.25), paint, bevel=0.06)          # top
    box((w - 0.5, dep - 0.1, 0.3), (0, y0, 0.15 + 0.1), paint, bevel=0.04)          # plinth
    box((w - 0.4, 0.12, h - 0.4), (0, y0 + dep / 2 - 0.06, (h - 0.4) / 2 + 0.1), paint, bevel=0.0)  # back
    for x in (-(w / 2 - 0.3), -1.45, 1.45, w / 2 - 0.3):
        box((0.2, dep, h - 0.5), (x, y0, (h - 0.5) / 2 + 0.15), paint, bevel=0.04)
    shelf_z = 1.95
    box((w - 0.6, dep - 0.15, 0.16), (0, y0 + 0.05, shelf_z), paint, bevel=0.03)
    random.seed(11)
    for bay_x0, bay_x1 in ((-(w / 2 - 0.4), -1.55), (-1.35, 1.35), (1.55, w / 2 - 0.4)):
        for z0, top in ((0.42, shelf_z - 0.1), (shelf_z + 0.08, h - 0.48)):
            x = bay_x0 + 0.05
            while x < bay_x1 - 0.3:
                bw = random.uniform(0.18, 0.32)
                bh = min(top - z0 - 0.05, random.uniform(0.95, 1.4))
                col = random.choice(BOOK_COLORS)
                if random.random() < 0.12 and x + 0.9 < bay_x1:
                    # A small flat stack.
                    for k in range(3):
                        book(x + 0.45, y0 + 0.1, z0 + k * 0.17, 0.9, 1.3, 0.17, random.choice(BOOK_COLORS), yaw=random.uniform(-0.1, 0.1))
                    x += 1.0
                    continue
                book(x + bw / 2, y0 + 0.1, z0, bw, 1.4, bh, col)
                x += bw + 0.01
    # Top styling: plant and a framed photo.
    lathe([(0, 0), (0.42, 0), (0.55, 0.62), (0.58, 0.66), (0, 0.66)], (-3.0, y0, h - 0.25), M["terracotta"], segs=20)
    random.seed(3)
    for i in range(10):
        lb = leaf_blade(0.9, 0.38, bend=0.35, segs=5)
        finish(lb, M["leaf"])
        transform(lb, (-3.0, y0, h + 0.38), (0, math.radians(-random.uniform(25, 60)), i * 0.63))
    box((1.2, 0.12, 1.5), (2.4, y0 + 0.4, h - 0.25 + 0.75), M["walnut"], bevel=0.04)
    box((0.95, 0.04, 1.2), (2.4, y0 + 0.33, h - 0.25 + 0.75), material("photo", rgb(176, 206, 222), "plain", rough=0.2), bevel=0.0)
    return {}


# ------------------------------------------------------------------ rugs

def rug_slab(outline, depth, m, bevel=0.06):
    return extrude_outline(outline, depth, (0, 0, 0), m, bevel=bevel, seg=2)


@item
def hearth_rug(M):
    s = 2 * CELL
    half = s / 2 - 0.35
    img = os.path.join(HERE, "art", "hearth_rug.png")
    m = material("rug_hearth", (1, 1, 1), "image", tint=True, rough=0.95, image=img, scale=(2 * half, 2 * half), bump=0.3)
    o = box((2 * half, 2 * half, 0.16), (0, 0, 0.08), m, bevel=0.06, seg=2, cuts=6)
    fringe = M["cream"]
    for side in (-1, 1):
        for i in range(30):
            x = -half + 0.12 + i * (2 * half - 0.24) / 29
            tube([(x, side * half, 0.06), (x + 0.02, side * (half + 0.22), 0.03), (x - 0.02, side * (half + 0.38), 0.02)], 0.035, fringe, segs=4, resolution=2)
    return {}


@item
def pibble_rug(M):
    import sys
    sys.path.insert(0, HERE)
    import art
    img = os.path.join(HERE, "art", "pibble.png")
    m = material("rug_pibble", (1, 1, 1), "image", tint=False, rough=0.95, image=img, scale=(2 * art.H, 2 * art.H), bump=0.4)
    rug_slab(art.pibble_outline(), 0.2, m, bevel=0.08)
    for side in (-1, 1):
        o = extrude_outline(art.ear(side), 0.16, (0, 0, 0.005), m, bevel=0.06, seg=2)
    # Rug binding around the head: the recolor shows here.
    pts = [(x * 1.0, y * 1.0, 0.2) for x, y in art.pibble_outline(0.985)]
    tube(pts + [pts[0]], 0.11, M["fabric"], segs=8, resolution=2)
    return {}


# ------------------------------------------------------------------ plants

def pot(M, m, r, h, x=0, y=0, rim=True):
    prof = [(0, 0), (r * 0.72, 0), (r * 0.75, 0.05), (r, h - 0.2)]
    if rim:
        prof += [(r * 1.08, h - 0.18), (r * 1.1, h), (r * 0.98, h), (r * 0.95, h - 0.1)]
    else:
        prof += [(r, h), (r * 0.92, h)]
    prof += [(r * 0.9, h - 0.25), (0, h - 0.25)]
    lathe(prof, (x, y, 0), m, segs=32, cap_top=False, cap_bottom=False, angle=45)
    lathe([(0, h - 0.24), (r * 0.9, h - 0.24)], (x, y, 0.0), M["soil"], segs=32, cap_top=False, cap_bottom=False)


@item
def mini_pine(M):
    h = 1.4 * CELL
    pot(M, M["tintceramic"], 1.15, 1.5)
    cyl(0.2, 1.3, (0, 0, 1.2), M["walnut"], segs=10, bevel=0)
    pine = material("pine", rgb(64, 120, 88), "leaf", rough=0.7, color2=rgb(36, 84, 62), bump=0.35)
    random.seed(5)
    tiers = 8
    for k in range(tiers):
        t = k / (tiers - 1)
        r = 2.1 * (1 - t) + 0.4 * t
        z0 = 2.0 + k * 0.54
        hgt = 1.05 - 0.25 * t
        segs = 20
        bm = lib.bmesh.new()
        tip = bm.verts.new((0, 0, z0 + hgt))
        ring_v = []
        inner_v = []
        for i in range(segs * 2):
            a = math.pi * i / segs + k * 0.4
            rr = r * (1.0 if i % 2 == 0 else 0.62) * random.uniform(0.85, 1.08)
            zz = z0 - (0.32 if i % 2 == 0 else 0.0) * (1 - 0.5 * t) + random.uniform(-0.05, 0.05)
            ring_v.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), zz)))
            inner_v.append(bm.verts.new((r * 0.35 * math.cos(a), r * 0.35 * math.sin(a), z0 + 0.12)))
        n = len(ring_v)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ring_v[i], ring_v[j], tip))
            bm.faces.new((ring_v[j], ring_v[i], inner_v[i], inner_v[j]))
        cap = bm.verts.new((0, 0, z0 + 0.12))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((inner_v[j], inner_v[i], cap))
        lib.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        o = lib._mesh_obj("tier", bm)
        sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = 1
        lib._apply_mods(o)
        finish(o, pine, 40)
    # Baubles and a star.
    cols = [rgb(214, 60, 70), rgb(236, 190, 80), rgb(240, 236, 228)]
    for i in range(10):
        k = i % 5
        t = k / 4
        r = (2.0 * (1 - t) + 0.6 * t) * 0.82
        a = i * 2.39
        z = 2.05 + k * 0.72 + 0.05
        sphere(0.17, (r * math.cos(a), r * math.sin(a), z), material("bauble%d" % (i % 3), cols[i % 3], "ceramic", rough=0.15, metal=0.0), segs=12, rings=8)
    st = extrude_outline(star_outline(0.55, 0.24), 0.14, (0, 0, 0), material("gold", rgb(240, 196, 96), "metal", rough=0.25, metal=1.0), bevel=0.04)
    transform(st, (0, 0.07, 2.0 + 7 * 0.54 + 0.85 + 0.4), (math.radians(90), 0, 0))
    return {}


def soft_frond(length, leaflets, leaf_len, droop, m, seed):
    """Boston-fern frond: an arching rachis with small rounded leaflets on both
    sides, shrinking toward the tip. Built along +X, arching down (-Z)."""
    rnd = random.Random(seed)
    bm = lib.bmesh.new()

    def spine(t):
        return (t * length, 0.0, length * (0.32 * t - droop * t * t))

    # Rachis: a thin flat ribbon.
    prev = None
    for i in range(9):
        t = i / 8
        x, y, z = spine(t)
        w = 0.045 * (1 - 0.7 * t)
        cur = (bm.verts.new((x, -w, z)), bm.verts.new((x, w, z)))
        if prev:
            bm.faces.new((prev[0], cur[0], cur[1], prev[1]))
        prev = cur
    for k in range(leaflets):
        # Leaflets bunch a little toward the tip so the frond ends full, not bare.
        u = (k + 0.5) / leaflets
        t = 0.1 + 0.88 * (u ** 0.85)
        x, y, z = spine(t)
        x2, _, z2 = spine(min(1.0, t + 0.02))
        slope = math.atan2(z2 - z, x2 - x)
        ramp = min(1.0, 0.45 + t * 2.2)
        size = leaf_len * ramp * (1.0 - 0.42 * t * t)
        for side in (-1, 1):
            ang = math.radians(rnd.uniform(50, 62) + 14 * t)  # tips sweep forward
            dx, dy = math.cos(ang) * size, side * math.sin(ang) * size
            wid = size * 0.3
            ox = x
            base = bm.verts.new((ox, side * 0.03, z))
            pts = []
            ux, uy = dx / size, dy / size
            nx, ny = -uy, ux
            for a in (0.3, 0.7):
                px_ = ox + dx * a
                py_ = side * 0.03 + dy * a
                ww = wid * (math.sin(math.pi * min(1.0, a * 1.05)) ** 0.6)
                droop_z = z + math.tan(slope) * dx * a - 0.12 * size * a * a
                pts.append((bm.verts.new((px_ + nx * ww, py_ + ny * ww, droop_z + 0.03)),
                            bm.verts.new((px_ - nx * ww, py_ - ny * ww, droop_z + 0.03))))
            tip = bm.verts.new((ox + dx, side * 0.03 + dy, z + math.tan(slope) * dx - 0.12 * size))
            ring_v = [base] + [p[0] for p in pts] + [tip] + [p[1] for p in reversed(pts)]
            try:
                bm.faces.new(ring_v)
            except ValueError:
                continue
    # Terminal leaflet so the frond ends in a soft point.
    x, y, z = spine(1.0)
    x0, _, z0 = spine(0.97)
    L = leaf_len * 0.5
    dxn, dzn = (x - x0), (z - z0)
    nrm = math.hypot(dxn, dzn) or 1.0
    dxn, dzn = dxn / nrm, dzn / nrm
    tv = [bm.verts.new((x0, 0.0, z0)), bm.verts.new((x + dxn * L * 0.5, -L * 0.22, z + dzn * L * 0.5 + 0.02)),
          bm.verts.new((x + dxn * L, 0.0, z + dzn * L)), bm.verts.new((x + dxn * L * 0.5, L * 0.22, z + dzn * L * 0.5 + 0.02))]
    bm.faces.new(tv)
    lib.bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    back = lib.bmesh.ops.duplicate(bm, geom=list(bm.faces))
    bfaces = [g for g in back["geom"] if isinstance(g, lib.bmesh.types.BMFace)]
    for g in back["geom"]:
        if isinstance(g, lib.bmesh.types.BMVert):
            g.co.z -= 0.012
    lib.bmesh.ops.reverse_faces(bm, faces=bfaces)
    lib.bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f not in bfaces])
    o = lib._mesh_obj("frond", bm)
    return finish(o, m, 70)


@item
def fern_pot(M):
    pot(M, M["tintceramic"], 1.05, 1.55)
    fern = material("fern", rgb(118, 184, 104), "leaf", rough=0.6, color2=rgb(76, 140, 80))
    random.seed(7)
    # Soft Boston fern: many arching fronds with small rounded leaflets that
    # spill over the rim instead of pointing up.
    n = 32
    for i in range(n):
        a = i * 2.39996 + random.uniform(-0.15, 0.15)
        inner = i < 11
        L = random.uniform(1.3, 1.6) if inner else random.uniform(1.9, 2.2)
        o = soft_frond(L, 16, 0.5, random.uniform(0.55, 0.75) if not inner else 0.35, fern, 100 + i)
        lift = random.uniform(30, 45) if inner else random.uniform(5, 22)
        transform(o, (0.15 * math.cos(a), 0.15 * math.sin(a), 1.42), (random.uniform(-0.2, 0.2), math.radians(-lift), a))
    return {}


# ------------------------------------------------------------------ holiday trim

def ribbon_box(M, w, d, h, x, y, z, yaw, paper, ribbon, bow=True):
    b = box((w, d, h), (0, 0, h / 2), paper, bevel=0.06, seg=2, name="gift")
    parts = [b]
    t = 0.18
    parts.append(box((w + 0.04, t, h + 0.04), (0, 0, h / 2), ribbon, bevel=0.01, seg=1))
    parts.append(box((t, d + 0.04, h + 0.04), (0, 0, h / 2), ribbon, bevel=0.01, seg=1))
    if bow:
        for s in (-1, 1):
            r = ring(0.26, 0.07, (0, 0, 0), ribbon, segs=18, minor_segs=6)
            transform(r, (0, 0, 0), (0, 0, 0), (1.0, 0.62, 1.0))
            transform(r, (s * 0.3, 0, h + 0.2), (0, math.radians(-s * 38), 0))
            parts.append(r)
            tail = box((0.16, 0.5, 0.03), (0, 0, 0), ribbon, bevel=0.01, seg=1)
            transform(tail, (s * 0.18, -0.35, h + 0.03), (0, 0, math.radians(s * 25)))
            parts.append(tail)
        parts.append(sphere(0.13, (0, 0, h + 0.1), ribbon, segs=10, rings=6))
    for p in parts:
        transform(p, (x, y, z), (0, 0, yaw))


@item
def gift_stack(M):
    satin_red = material("satin_red", rgb(206, 52, 64), "fabric", rough=0.35, sheen=0.6)
    satin_gold = material("satin_gold", rgb(232, 190, 92), "fabric", rough=0.3, sheen=0.6, metal=0.0)
    ribbon_box(M, 3.4, 3.0, 1.45, 0, 0.1, 0, 0.0, M["paint"], satin_gold, bow=False)
    ribbon_box(M, 2.4, 2.2, 1.05, -0.1, 0.0, 1.45, math.radians(14), material("paper_cream", rgb(246, 238, 224), "paper", rough=0.6), satin_red, bow=False)
    ribbon_box(M, 1.4, 1.4, 0.8, 0.1, -0.05, 2.5, math.radians(-10), material("paper_mint", rgb(150, 206, 184), "paper", rough=0.6), satin_red, bow=True)
    ribbon_box(M, 1.3, 1.2, 0.9, 1.45, -1.25, 0, math.radians(30), material("paper_red", rgb(204, 64, 70), "paper", rough=0.6), satin_gold, bow=True)
    return {}


@item
def cocoa_mug(M):
    r, h = 1.25, 1.75
    t = 0.12
    lathe([(0, 0), (r * 0.88, 0), (r * 0.98, 0.08), (r, 0.25), (r * 1.04, h - 0.05), (r * 1.03, h), (r * 1.03 - t, h), (r - t, 0.3), (0, 0.3)],
          (0, -0.1, 0), M["tintceramic"], segs=40, cap_top=False, cap_bottom=False, angle=50)
    cocoa = material("cocoa", rgb(110, 66, 44), "plain", rough=0.25)
    lathe([(0, h - 0.18), (r * 1.03 - t, h - 0.18)], (0, -0.1, 0), cocoa, segs=40, cap_top=False, cap_bottom=False)
    tube([(r * 0.95, -0.1, h * 0.82), (r + 0.75, -0.1, h * 0.75), (r + 0.75, -0.1, h * 0.32), (r * 0.95, -0.1, h * 0.25)], 0.14, M["tintceramic"], segs=10)
    cream = material("whip", rgb(252, 248, 240), "ceramic", rough=0.5)
    for i, (rr, zz) in enumerate(((0.85, 0.1), (0.68, 0.32), (0.48, 0.52), (0.26, 0.7))):
        ring(rr, 0.2, (0, -0.1, h - 0.1 + zz), cream, segs=28, minor_segs=10)
    sphere(0.16, (0, -0.1, h + 0.75), cream, segs=12, rings=8)
    mm = material("marsh", rgb(255, 250, 244), "ceramic", rough=0.6)
    random.seed(8)
    for i in range(6):
        a = i * 1.05 + 0.3
        o = cyl(0.17, 0.26, (0, 0, 0), mm, segs=12, bevel=0.06)
        transform(o, (0.95 * math.cos(a), -0.1 + 0.95 * math.sin(a), h - 0.2), (random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), 0))
    # Sprinkles on the cream.
    for i in range(14):
        a = i * 2.4
        rr = 0.3 + 0.45 * ((i * 7) % 5) / 5
        z = h + 0.15 + (0.85 - rr) * 0.75
        box((0.14, 0.05, 0.05), (rr * math.cos(a), -0.1 + rr * math.sin(a), z), material("spr%d" % (i % 3), [rgb(230, 80, 90), rgb(120, 200, 170), rgb(250, 200, 90)][i % 3], "plain", rough=0.4), bevel=0.02, seg=1)
    return {}


# ------------------------------------------------------------------ music

@item
def carol_piano(M):
    w, d, h = 2 * CELL, CELL, 1.05 * CELL
    lac = M["paint"]
    bw = 8.4
    y_back = d / 2 - 0.15
    body_d = 2.0
    yb = y_back - body_d / 2
    box((bw, body_d, h - 0.25), (0, yb, (h - 0.25) / 2), lac, bevel=0.08)
    box((bw + 0.3, body_d + 0.25, 0.22), (0, yb - 0.05, h - 0.14), lac, bevel=0.08)
    # Key bed and cheeks.
    key_y = yb - body_d / 2 - 0.55
    box((bw - 0.2, 1.2, 0.5), (0, key_y + 0.05, 2.3), lac, bevel=0.06)
    for sx in (-1, 1):
        box((0.45, 1.35, 0.95), (sx * (bw / 2 - 0.22), key_y, 2.55), lac, bevel=0.1)
        # Console leg and toe block.
        tube([(sx * (bw / 2 - 0.35), key_y + 0.1, 2.05), (sx * (bw / 2 - 0.35), key_y - 0.15, 1.2), (sx * (bw / 2 - 0.35), key_y + 0.05, 0.25)], 0.2, lac, segs=10)
        box((0.5, 0.9, 0.25), (sx * (bw / 2 - 0.35), key_y + 0.3, 0.12), lac, bevel=0.05)
    ivory = material("ivory", rgb(250, 247, 238), "ceramic", rough=0.3)
    ebony = material("ebony", rgb(30, 28, 32), "ceramic", rough=0.2)
    kw_total = bw - 1.2
    n = 36
    kw = kw_total / n
    for i in range(n):
        box((kw - 0.03, 0.85, 0.16), (-kw_total / 2 + kw * (i + 0.5), key_y - 0.05, 2.6), ivory, bevel=0.025, seg=1)
    for i in range(n - 1):
        if i % 7 in (2, 6):
            continue
        box((kw * 0.55, 0.5, 0.14), (-kw_total / 2 + kw * (i + 1), key_y + 0.12, 2.72), ebony, bevel=0.02, seg=1)
    # Fallboard, music desk and sheet music.
    box((bw - 0.9, 0.12, 0.6), (0, yb - body_d / 2 - 0.02, 3.05), lac, bevel=0.04)
    desk = box((3.2, 0.12, 1.15), (0, 0, 0), lac, bevel=0.04)
    transform(desk, (0, yb - body_d / 2 - 0.12, 3.85), (math.radians(-12), 0, 0))
    sheet = box((2.2, 0.03, 1.0), (0, 0, 0), M["paper"], bevel=0.0)
    transform(sheet, (0, yb - body_d / 2 - 0.2, 3.9), (math.radians(-12), 0, 0))
    # Brass candle sconces and pedals.
    for sx in (-1, 1):
        tube([(sx * 2.7, yb - body_d / 2, 3.9), (sx * 2.8, yb - body_d / 2 - 0.35, 3.85), (sx * 2.8, yb - body_d / 2 - 0.4, 4.0)], 0.04, M["brass"], segs=6)
        cyl(0.11, 0.06, (sx * 2.8, yb - body_d / 2 - 0.4, 4.0), M["brass"], segs=12, bevel=0.01)
        cyl(0.07, 0.4, (sx * 2.8, yb - body_d / 2 - 0.4, 4.06), M["white"], segs=10, bevel=0.01)
    for i in (-1, 0, 1):
        o = box((0.16, 0.6, 0.07), (i * 0.45, yb - body_d / 2 - 0.25, 0.35), M["brass"], bevel=0.03, seg=1)
    # Bench.
    bench_y = -d / 2 + 0.75
    box((3.6, 1.3, 0.25), (0, bench_y, 2.0), M["walnut"], bevel=0.06)
    cushion((3.4, 1.15, 0.3), (0, bench_y, 2.25), M["cream"], round_=0.35, puff=0.1, cuts=3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tapered_leg(sx * 1.55, bench_y + sy * 0.45, 1.9, 0.12, 0.08, M["walnut"], splay=math.radians(6))
    return {}


# ------------------------------------------------------------------ kitchen

def base_cabinet(M, w, d, h, y=0.0, doors=2, drawers=0, handle="bar"):
    paint = M["paint"]
    box((w - 0.1, d - 0.15, h - 0.35), (0, y + 0.05, 0.35 + (h - 0.35) / 2), paint, bevel=0.05)
    box((w - 0.3, d - 0.4, 0.35), (0, y + 0.15, 0.175), M["black"], bevel=0.02)  # toe kick
    front = y - (d - 0.15) / 2 + 0.05
    z0 = 0.45
    top = h - 0.1
    dz = 0.0
    if drawers:
        dh = 0.75
        dw = (w - 0.3) / drawers
        for i in range(drawers):
            x = -w / 2 + 0.15 + dw * (i + 0.5)
            panel(M, x, front, top - dh / 2 - 0.02, dw - 0.1, dh - 0.08, handle)
        top -= dh
    dw = (w - 0.3) / doors
    for i in range(doors):
        x = -w / 2 + 0.15 + dw * (i + 0.5)
        panel(M, x, front, (z0 + top) / 2, dw - 0.1, top - z0 - 0.1, handle, vertical=True, side=(1 if i % 2 == 0 else -1) if doors > 1 else 1)


def panel(M, x, y, z, w, h, handle="bar", vertical=False, side=1):
    paint = M["paint"]
    box((w, 0.12, h), (x, y - 0.06, z), paint, bevel=0.035, seg=2)
    # Shaker inset frame.
    box((w - 0.4, 0.06, h - 0.4), (x, y - 0.1, z), paint, bevel=0.03, seg=2)
    if handle == "bar":
        if vertical:
            hx = x + side * (w / 2 - 0.25)
            tube([(hx, y - 0.12, z + 0.35), (hx, y - 0.3, z + 0.3), (hx, y - 0.3, z - 0.3), (hx, y - 0.12, z - 0.35)], 0.04, M["brass"], segs=6, resolution=4)
        else:
            tube([(x - 0.4, y - 0.12, z), (x - 0.35, y - 0.3, z), (x + 0.35, y - 0.3, z), (x + 0.4, y - 0.12, z)], 0.04, M["brass"], segs=6, resolution=4)
    else:
        sphere(0.11, (x + side * (w / 2 - 0.3), y - 0.2, z), M["brass"], segs=12, rings=8)


@item
def coffee_bar(M):
    w = CELL
    base_cabinet(M, w - 0.2, 3.9, 3.6, y=0.35, doors=2, drawers=1, handle="knob")
    box((w, 4.2, 0.3), (0, 0.3, 3.75), M["oak"], bevel=0.06)
    top = 3.9
    steel, chrome, black = M["steel"], M["chrome"], M["black"]
    # Espresso machine.
    mx, my = -0.35, 0.75
    box((2.6, 2.0, 1.65), (mx, my, top + 0.825 + 0.18), chrome, bevel=0.22, seg=4)
    box((2.65, 2.05, 0.18), (mx, my, top + 0.09), black, bevel=0.05)
    box((2.2, 1.6, 0.08), (mx, my - 0.05, top + 0.18 + 1.65 + 0.06), black, bevel=0.03)
    box((2.5, 0.9, 0.15), (mx, my - 1.3, top + 0.15), steel, bevel=0.05)  # drip tray
    for k in range(5):
        box((2.2, 0.05, 0.02), (mx, my - 1.05 - k * 0.12, top + 0.23), black, bevel=0.0)
    front = my - 1.0
    for gx in (-0.6, 0.55):
        cyl(0.32, 0.3, (mx + gx, front - 0.25, top + 1.1), chrome, segs=20, bevel=0.06)
        tube([(mx + gx, front - 0.3, top + 1.0), (mx + gx, front - 0.75, top + 0.98), (mx + gx, front - 1.15, top + 0.92)], 0.08, black, segs=8)
        mug(mx + gx, front - 0.3, top + 0.22, 0.27, 0.42, M["white"], material("espresso", rgb(80, 52, 36), "plain", rough=0.2), yaw=-1.2)
    # Gauge.
    cyl(0.3, 0.1, (0, 0, 0), chrome, segs=24, bevel=0.03)
    g = lib.bpy.context.active_object
    transform(g, (mx, front - 0.02, top + 1.65), (math.radians(90), 0, 0))
    lathe([(0, 0), (0.24, 0), (0, 0.001)], (0, 0, 0), M["white"], segs=24)
    gf = lib.bpy.context.active_object
    transform(gf, (mx, front - 0.13, top + 1.65), (math.radians(90), 0, 0))
    box((0.03, 0.02, 0.18), (mx + 0.04, front - 0.15, top + 1.68), material("needle", rgb(200, 50, 50), "plain"), bevel=0.0)
    tube([(mx + 1.15, my - 0.9, top + 1.35), (mx + 1.3, my - 1.1, top + 0.9), (mx + 1.3, my - 1.15, top + 0.55)], 0.04, chrome, segs=6)
    # Knobs.
    for i, kx in enumerate((-1.1, 1.1)):
        cyl(0.13, 0.15, (0, 0, 0), black, segs=14, bevel=0.03)
        o = lib.bpy.context.active_object
        transform(o, (mx + kx * 0.95, front - 0.02, top + 1.65), (math.radians(90), 0, 0))
    # Grinder with beans.
    gx, gy = 1.55, 0.9
    box((0.9, 1.0, 1.15), (gx, gy, top + 0.575), black, bevel=0.15, seg=3)
    lathe([(0.3, 0), (0.45, 0.9), (0.47, 0.95), (0.0, 0.95)], (gx, gy, top + 1.15), M["glass"], segs=20)
    lathe([(0, 0), (0.33, 0), (0.42, 0.6), (0, 0.6)], (gx, gy, top + 1.18), material("beans", rgb(92, 56, 38), "soil", rough=0.5, bump=0.8), segs=20)
    lathe([(0, 0), (0.48, 0), (0.48, 0.1), (0.15, 0.2), (0, 0.22)], (gx, gy, top + 2.12), black, segs=20)
    # Stack of cups on the counter.
    for k in range(3):
        mug(1.55, -0.95, top + k * 0.32, 0.3, 0.38, M["tintceramic"] if k == 1 else M["white"], M["white"], handle=(k == 2), yaw=-0.8)
    return {}


@item
def sink_counter(M):
    w, d = 2 * CELL, CELL
    base_cabinet(M, w - 0.2, 4.0, 3.9, y=0.3, doors=4, drawers=2, handle="bar")
    top = 3.9
    slab = box((w, 4.3, 0.3), (0, 0.25, top + 0.15), M["marble"], bevel=0.05, seg=2)
    hole = box((3.0, 2.2, 1.2), (1.6, 0.05, top), None, bevel=0.15, seg=2)
    cut(slab, hole)
    steel = M["steel"]
    basin = box((3.0, 2.2, 1.0), (1.6, 0.05, top - 0.25), steel, bevel=0.15, seg=2)
    inner = box((2.8, 2.0, 1.0), (1.6, 0.05, top - 0.15), None, bevel=0.13, seg=2)
    cut(basin, inner)
    cyl(0.18, 0.04, (1.6, 0.05, top - 0.74), M["black"], segs=14, bevel=0)
    # Backsplash.
    box((w, 0.25, 1.1), (0, d / 2 - 0.1, top + 0.55), material("tile", rgb(236, 240, 238), "ceramic", rough=0.2), bevel=0.04)
    chrome = M["chrome"]
    fx, fy = 1.6, 1.45
    cyl(0.2, 0.2, (fx, fy, top + 0.3), chrome, segs=16, bevel=0.04)
    tube([(fx, fy, top + 0.4), (fx, fy, top + 1.6), (fx, fy - 0.35, top + 2.0), (fx, fy - 0.9, top + 1.7), (fx, fy - 1.0, top + 1.25)], 0.09, chrome, segs=10, resolution=10)
    tube([(fx + 0.25, fy, top + 0.5), (fx + 0.5, fy - 0.05, top + 0.85)], 0.05, chrome, segs=6)
    # Counter styling: cutting board, crock with utensils, dish soap.
    box((2.2, 1.4, 0.12), (-2.4, -0.1, top + 0.36), M["oak"], bevel=0.05)
    lathe([(0, 0), (0.42, 0), (0.45, 0.9), (0.4, 0.92), (0.38, 0.4), (0, 0.4)], (-3.9, 1.1, top + 0.3), M["tintceramic"], segs=20)
    random.seed(12)
    for i in range(4):
        a = i * 1.5
        tube([(-3.9 + 0.1 * math.cos(a), 1.1 + 0.1 * math.sin(a), top + 0.6), (-3.9 + 0.32 * math.cos(a), 1.1 + 0.3 * math.sin(a), top + 1.9)], 0.05, M["oak"] if i % 2 else M["black"], segs=6)
    lathe([(0, 0), (0.2, 0), (0.22, 0.45), (0.1, 0.6), (0.05, 0.75), (0, 0.75)], (0.3, 1.2, top + 0.3), material("soap", rgb(150, 210, 190), "ceramic", rough=0.15), segs=16)
    box((1.7, 1.0, 0.18), (-0.9, 1.0, top + 0.39), material("towel", rgb(240, 236, 226), "knit", rough=0.9), bevel=0.06)
    return {}


@item
def retro_fridge(M):
    h = 1.95 * CELL
    paint = M["paint"]
    chrome = M["chrome"]
    W, D = 4.1, 3.6
    y = 0.4
    box((W, D, h - 0.45), (0, y + 0.2, 0.45 + (h - 0.45) / 2), paint, bevel=0.75, seg=6)
    split = 6.6
    front = y + 0.2 - D / 2
    # Doors: thick rounded slabs proud of the body.
    box((W - 0.05, 0.4, split - 0.62), (0, front - 0.12, 0.55 + (split - 0.62) / 2), paint, bevel=0.35, seg=5)
    box((W - 0.05, 0.4, h - split - 0.12), (0, front - 0.12, split + (h - split - 0.12) / 2 - 0.02), paint, bevel=0.35, seg=5)
    box((W - 0.4, 0.3, 0.06), (0, front - 0.02, split - 0.05), M["black"], bevel=0.0)  # gap shadow
    for z0, z1 in ((split - 2.6, split - 0.6), (split + 0.4, split + 1.6)):
        tube([(-W / 2 + 0.35, front - 0.32, z1 + 0.15), (-W / 2 + 0.3, front - 0.62, z1), (-W / 2 + 0.3, front - 0.62, z0), (-W / 2 + 0.35, front - 0.32, z0 - 0.15)], 0.09, chrome, segs=10, resolution=8)
        for zz in (z0 - 0.15, z1 + 0.15):
            o = cyl(0.13, 0.25, (0, 0, 0), chrome, segs=12, bevel=0.04)
            transform(o, (-W / 2 + 0.35, front - 0.3, zz), (math.radians(90), 0, 0))
    # Hinges and badge.
    for zz in (0.75, split - 0.2, split + 0.2, h - 0.35):
        box((0.3, 0.3, 0.25), (W / 2 - 0.2, front - 0.15, zz), chrome, bevel=0.08)
    lathe([(0, 0), (0.42, 0), (0.42, 0.06), (0, 0.08)], (0, 0, 0), chrome, segs=24)
    bdg = lib.bpy.context.active_object
    transform(bdg, (0.4, front - 0.32, split + 1.9), (math.radians(90), 0, 0), (1.0, 0.45, 1.0))
    # Feet and kick plate.
    box((W - 0.6, D - 0.4, 0.4), (0, y + 0.3, 0.3), chrome, bevel=0.08)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe([(0, 0), (0.2, 0), (0.24, 0.12), (0.14, 0.32), (0, 0.32)], (sx * (W / 2 - 0.45), y + 0.2 + sy * (D / 2 - 0.45), 0), chrome, segs=14)
    # A couple of magnets/notes on the door.
    box((0.75, 0.04, 0.95), (0.6, front - 0.33, 4.6), M["paper"], bevel=0.0)
    sphere(0.12, (0.6, front - 0.36, 5.0), material("magnet", rgb(230, 80, 90), "ceramic", rough=0.2), scale=(1, 0.5, 1), segs=10, rings=6)
    box((0.6, 0.04, 0.6), (-0.4, front - 0.33, 3.7), material("photo", rgb(176, 206, 222), "plain", rough=0.2), bevel=0.0)
    return {}


@item
def retro_stove(M):
    paint, chrome, black = M["paint"], M["chrome"], M["black"]
    W, D, H = 4.5, 3.9, 3.85
    y = 0.4
    box((W, D, H - 0.35), (0, y, 0.35 + (H - 0.35) / 2), paint, bevel=0.3, seg=4)
    box((W - 0.5, D - 0.5, 0.35), (0, y + 0.15, 0.175), chrome, bevel=0.06)
    front = y - D / 2
    # Oven door with window and bar handle.
    box((W - 0.5, 0.25, 2.2), (0, front - 0.08, 1.65), paint, bevel=0.15, seg=3)
    box((W - 1.5, 0.08, 1.0), (0, front - 0.2, 1.6), material("oven_glass", rgb(40, 36, 40), "plain", rough=0.05), bevel=0.06)
    box((W - 1.3, 0.06, 1.2), (0, front - 0.17, 1.6), chrome, bevel=0.04)
    tube([(-1.5, front - 0.12, 2.6), (-1.45, front - 0.45, 2.62), (1.45, front - 0.45, 2.62), (1.5, front - 0.12, 2.6)], 0.07, chrome, segs=8, resolution=3)
    # Control strip with knobs.
    box((W - 0.4, 0.2, 0.55), (0, front - 0.03, H - 0.5), chrome, bevel=0.08)
    for i in range(5):
        x = -1.6 + i * 0.8
        lathe([(0, 0), (0.17, 0), (0.18, 0.12), (0.12, 0.25), (0, 0.27)], (0, 0, 0), M["white"], segs=16)
        k = lib.bpy.context.active_object
        transform(k, (x, front - 0.12, H - 0.5), (math.radians(90), 0, 0))
    # Cooktop and grates.
    box((W - 0.1, D - 0.1, 0.12), (0, y, H + 0.04), black, bevel=0.05)
    for bx in (-1.05, 1.05):
        for by in (-0.85, 0.95):
            cx, cy = bx, y + by
            lathe([(0, 0), (0.55, 0), (0.55, 0.06), (0.35, 0.1), (0, 0.12)], (cx, cy, H + 0.1), material("burner", rgb(60, 58, 60), "metal", rough=0.5, metal=0.6), segs=24)
            ring(0.62, 0.05, (cx, cy, H + 0.24), black, segs=24, minor_segs=6)
            for a in (0, math.pi / 2):
                o = box((1.3, 0.09, 0.09), (0, 0, 0), black, bevel=0.03, seg=1)
                transform(o, (cx, cy, H + 0.28), (0, 0, a))
    # Backguard with a little clock.
    box((W, 0.35, 1.3), (0, y + D / 2 - 0.15, H + 0.65), paint, bevel=0.15, seg=3)
    box((W - 0.6, 0.05, 0.35), (0, y + D / 2 - 0.34, H + 0.9), chrome, bevel=0.02)
    lathe([(0, 0), (0.3, 0), (0.3, 0.06), (0, 0.06)], (0, 0, 0), M["white"], segs=20)
    c = lib.bpy.context.active_object
    transform(c, (0, y + D / 2 - 0.36, H + 0.62), (math.radians(90), 0, 0))
    # Kettle on the front-left burner.
    kettle = material("kettle", rgb(214, 70, 72), "ceramic", rough=0.18)
    kx, ky, kz = -1.05, y - 0.85, H + 0.3
    lathe([(0, 0), (0.55, 0), (0.68, 0.15), (0.7, 0.45), (0.55, 0.85), (0.25, 1.0), (0.2, 1.05), (0, 1.07)], (kx, ky, kz), kettle, segs=28)
    sphere(0.1, (kx, ky, kz + 1.12), black, segs=10, rings=6)
    tube([(kx - 0.35, ky, kz + 0.95), (kx, ky, kz + 1.55), (kx + 0.35, ky, kz + 0.95)], 0.06, black, segs=8)
    tube([(kx + 0.55, ky, kz + 0.35), (kx + 0.85, ky, kz + 0.6), (kx + 1.0, ky, kz + 0.85)], 0.09, kettle, segs=8)
    return {}


# ================================================================== round 2
# Starter and most-placed items that sat next to the meshes as blocks.

def berries(cx, cy, cz, n, spread, seed, m):
    random.seed(seed)
    for i in range(n):
        a = random.uniform(0, 2 * math.pi)
        r = random.uniform(0, spread)
        sphere(random.uniform(0.09, 0.13), (cx + r * math.cos(a), cy + r * math.sin(a), cz + random.uniform(-0.08, 0.1)), m, segs=8, rings=6, name="berry")


def sprig_ring(cx, cy, z, r, n, seed, leaf_m, berry_m):
    random.seed(seed)
    for i in range(n):
        a = i * 2 * math.pi / n + random.uniform(-0.15, 0.15)
        lb = leaf_blade(random.uniform(0.45, 0.6), 0.2, bend=0.15, segs=3)
        finish(lb, leaf_m)
        transform(lb, (cx + r * math.cos(a), cy + r * math.sin(a), z), (0, math.radians(random.uniform(-25, -5)), a + random.uniform(0.8, 1.6)))
    for i in range(n // 3):
        a = i * 2 * math.pi / (n // 3) + 0.4
        berries(cx + r * math.cos(a), cy + r * math.sin(a), z + 0.08, 3, 0.1, seed + i, berry_m)


HOLLY = None


def holly_mats():
    return (material("holly", rgb(60, 128, 84), "leaf", rough=0.35, color2=rgb(40, 96, 62)),
            material("berry", rgb(206, 44, 56), "ceramic", rough=0.2))


@item
def window_candle(M):
    leaf_m, berry_m = holly_mats()
    paint = M["paint"]
    # Open candle lantern: no glass, so the candle reads from every side.
    box((1.9, 1.9, 0.3), (0, 0, 0.15), paint, bevel=0.08, seg=2)
    box((1.6, 1.6, 0.12), (0, 0, 0.36), paint, bevel=0.04, seg=2)
    top_z = 2.75
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.14, 0.14, top_z - 0.36), (sx * 0.72, sy * 0.72, 0.36 + (top_z - 0.36) / 2), paint, bevel=0.03, seg=1)
    box((1.75, 1.75, 0.16), (0, 0, top_z + 0.08), paint, bevel=0.05, seg=2)
    roof = lathe([(0, 0), (1.22, 0), (1.22, 0.06), (0.2, 0.62), (0, 0.66)], (0, 0, 0), paint, segs=4, angle=10)
    transform(roof, (0, 0, top_z + 0.16), (0, 0, math.radians(45)))
    ring(0.24, 0.05, (0, 0, top_z + 1.05), M["brass"], segs=20, minor_segs=8, rot=(math.radians(90), 0, 0))
    # Pillar candle with a soft melted top, and the flame.
    wax = material("wax", rgb(250, 242, 226), "ceramic", rough=0.55)
    lathe([(0, 0), (0.44, 0), (0.45, 1.25), (0.4, 1.3), (0.3, 1.24), (0, 1.22)], (0, 0, 0.42), wax, segs=28, angle=50)
    cyl(0.02, 0.14, (0, 0, 1.62), M["black"], segs=6, bevel=0)
    lathe([(0, 0), (0.09, 0.08), (0.11, 0.2), (0.06, 0.38), (0, 0.5)], (0, 0, 1.72), M["bulb"], segs=14)
    # Greenery and berries around the base.
    sprig_ring(0, 0, 0.32, 1.05, 18, 3, leaf_m, berry_m)
    return {"light": {"at": [0, 1.95, 0], "brightness": 0.55, "range": 10}}


@item
def cocoa_stool(M):
    h = 0.7 * CELL
    seat = h - 0.42
    lathe([(0, 0), (1.25, 0), (1.32, 0.06), (1.32, 0.2), (1.25, 0.26), (0, 0.26)], (0, 0, seat - 0.26), M["oak"], segs=40)
    cushion((2.3, 2.3, 0.5), (0, 0, seat + 0.2), M["fabric"], round_=0.95, puff=0.18, cuts=4)
    sphere(0.09, (0, 0, seat + 0.48), M["fabric"], scale=(1, 1, 0.5), segs=10, rings=6)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        o = cyl(0.11, seat - 0.2, (0, 0, 0), M["oak"], segs=14, bevel=0.03, r2=0.15)
        transform(o, (0.95 * math.cos(a), 0.95 * math.sin(a), 0), (math.radians(8) * -math.sin(a), math.radians(8) * math.cos(a), 0))
    ring(0.98, 0.06, (0, 0, 1.05), M["oak"], segs=36, minor_segs=8)
    return {}


@item
def drum_stool(M):
    h = 0.65 * CELL
    top = h
    lea = M["leather"]
    # Round padded throne seat with a piped edge.
    lathe([(0, 0), (1.15, 0), (1.3, 0.12), (1.36, 0.3), (1.3, 0.5), (1.0, 0.62), (0, 0.66)], (0, 0, top - 0.66), lea, segs=40, angle=60)
    ring(1.33, 0.05, (0, 0, top - 0.36), lea, segs=40, minor_segs=6)
    lathe([(0, 0), (0.75, 0), (0.75, 0.12), (0, 0.12)], (0, 0, top - 0.8), M["black"], segs=24)
    cyl(0.13, top - 1.1, (0, 0, 0.6), M["chrome"], segs=16, bevel=0.02)
    cyl(0.2, 0.3, (0, 0, 1.4), M["chrome"], segs=16, bevel=0.04)
    cyl(0.06, 0.4, (0.22, 0, 1.55), M["black"], segs=10, bevel=0.02)
    for i in range(3):
        a = i * 2 * math.pi / 3 + math.pi / 2
        tube([(0, 0, 1.3), (1.0 * math.cos(a), 1.0 * math.sin(a), 0.6), (1.7 * math.cos(a), 1.7 * math.sin(a), 0.12)], 0.07, M["chrome"], segs=10, resolution=6)
        sphere(0.14, (1.72 * math.cos(a), 1.72 * math.sin(a), 0.1), M["rubber"], scale=(1, 1, 0.7), segs=12, rings=8)
        tube([(0, 0, 0.95), (0.95 * math.cos(a), 0.95 * math.sin(a), 0.62)], 0.04, M["chrome"], segs=8)
    return {}


def puffy_star(r_out, r_in, depth, m):
    pts = star_outline(r_out, r_in)
    # Round the tips and the valleys a little.
    soft = []
    n = len(pts)
    for i in range(n):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
        m0 = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        m1 = ((b[0] + c[0]) / 2, (b[1] + c[1]) / 2)
        for t in (0.0, 0.2, 0.4, 0.6, 0.8):
            u = 1 - t
            soft.append((u * u * m0[0] + 2 * u * t * b[0] + t * t * m1[0], u * u * m0[1] + 2 * u * t * b[1] + t * t * m1[1]))
    o = extrude_outline(soft, depth, (0, 0, 0), m, bevel=depth * 0.42, seg=4)
    sub = o.modifiers.new("sub", "SUBSURF"); sub.levels = 1
    lib._apply_mods(o)
    for v in o.data.vertices:
        r = math.hypot(v.co.x, v.co.y) / r_out
        f = 0.45 + 0.55 * max(0.0, 1 - r ** 1.6)
        v.co.z = depth / 2 + (v.co.z - depth / 2) * f * 1.25
    finish(o, m, 50)
    return o


@item
def star_pillow(M):
    back = cushion((2.6, 1.0, 1.7), (0, 0, 0), material("pillow_oat", rgb(236, 226, 208), "knit", rough=0.9, bump=0.6), round_=0.5, puff=0.32, front_puff=0.3, cuts=4)
    transform(back, (0.15, 0.85, 0.82), (math.radians(-18), 0, math.radians(8)))
    st = puffy_star(1.55, 0.78, 0.7, M["fabric"])
    transform(st, (0, -0.25, 0.85), (math.radians(68), 0, math.radians(-6)))
    for k in range(3):
        sphere(0.07, (-0.5 + k * 0.5, -0.62, 1.2 + 0.05 * k), M["fabric"], scale=(1, 0.6, 1), segs=8, rings=6, name="tuft")
    return {}


def knit_pouf(M, r, h, m, ribs=26):
    prof = []
    for i in range(13):
        t = i / 12
        z = t * h
        bulge = math.sin(math.pi * t) ** 0.35
        prof.append((max(0.001, r * (0.82 + 0.18 * bulge)), z))
    prof = [(0, 0)] + prof + [(0, h)]
    o = lathe(prof, (0, 0, 0), m, segs=ribs * 4, angle=60)
    for v in o.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 0.3:
            k = 1 + 0.035 * math.cos(a * ribs) * min(1.0, (rr / r) ** 4)
            v.co.x *= k; v.co.y *= k
    return o


@item
def mint_pouf(M):
    h = 0.55 * CELL
    knit_pouf(M, 1.85, h, M["knit"])
    # Top seam and a knit handle loop.
    ring(1.0, 0.07, (0, 0, h - 0.04), M["knit"], segs=36, minor_segs=8)
    return {}


@item
def cloud_pouf(M):
    h = 0.55 * CELL
    boucle = M["knit"]
    sphere(1.55, (0, 0, h * 0.5), boucle, scale=(1, 1, 0.78), segs=28, rings=16)
    for i in range(6):
        a = i * math.pi / 3 + 0.3
        sphere(0.95, (1.05 * math.cos(a), 1.05 * math.sin(a), h * 0.42), boucle, scale=(1, 1, 0.82), segs=22, rings=12)
    cyl(1.5, 0.12, (0, 0, 0), M["birch"], segs=28, bevel=0.04)
    return {}


def rug_2x1(M, art_name, outline, fringe=False, binding=True, bind_m=None):
    img = os.path.join(HERE, "art", art_name + ".png")
    W, Hh = 2 * CELL, CELL
    m = material("rug_" + art_name, (1, 1, 1), "image", rough=0.95, image=img, scale=(W - 0.6, Hh - 0.6), bump=0.35, tint_alpha=True)
    rug_slab(outline, 0.14, m, bevel=0.05)
    if binding:
        pts = [(x, y, 0.1) for x, y in outline]
        tube(pts + [pts[0]], 0.07, bind_m or M["fabric"], segs=8, resolution=1)
    if fringe:
        half_x = max(x for x, _ in outline)
        half_y = max(y for _, y in outline)
        for side in (-1, 1):
            for i in range(22):
                y = -half_y + 0.12 + i * (2 * half_y - 0.24) / 21
                tube([(side * half_x, y, 0.06), (side * (half_x + 0.2), y + 0.02, 0.03), (side * (half_x + 0.36), y - 0.02, 0.02)], 0.035, M["cream"], segs=4, resolution=2)


def rounded_rect(hx, hy, r, n=6):
    pts = []
    for cx, cy, a0 in ((hx - r, -hy + r, -90), (hx - r, hy - r, 0), (-hx + r, hy - r, 90), (-hx + r, -hy + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def ellipse_pts(hx, hy, n=64):
    return [(hx * math.cos(2 * math.pi * i / n), hy * math.sin(2 * math.pi * i / n)) for i in range(n)]


@item
def dot_rug(M):
    rug_2x1(M, "dot_rug", ellipse_pts(CELL - 0.3, CELL / 2 - 0.3), binding=True)
    return {}


@item
def stripe_rug(M):
    rug_2x1(M, "stripe_rug", rounded_rect(CELL - 0.65, CELL / 2 - 0.3, 0.06, 2), fringe=True, binding=False)
    return {}


@item
def checker_rug(M):
    rug_2x1(M, "checker_rug", rounded_rect(CELL - 0.3, CELL / 2 - 0.3, 0.35), binding=True)
    return {}


@item
def plaid_rug(M):
    rug_2x1(M, "plaid_rug", rounded_rect(CELL - 0.3, CELL / 2 - 0.3, 0.2), binding=True, bind_m=M["cream"])
    return {}


@item
def cream_rocker(M):
    paint = M["paint"]
    linen = material("linen_check", rgb(236, 226, 210), "fabric", rough=0.85, sheen=0.3)
    # Curved rockers.
    for sx in (-1, 1):
        x = sx * 1.3
        pts = [(x, -2.05 + 4.1 * i / 10, 0.12 + 0.55 * ((i / 10 - 0.5) * 2) ** 2) for i in range(11)]
        tube(pts, 0.12, paint, segs=10, resolution=2)
    seat = 2.05
    for sx in (-1, 1):
        for y in (-1.25, 1.1):
            z0 = 0.15 + 0.55 * ((y / 2.05) ** 2) * 0.9
            cyl(0.13, seat - z0, (sx * 1.3, y, z0), paint, segs=12, bevel=0.03)
    box((2.95, 2.75, 0.18), (0, -0.05, seat + 0.05), paint, bevel=0.06, seg=2)
    cushion((2.6, 2.4, 0.4), (0, -0.1, seat + 0.33), linen, round_=0.45, puff=0.12, cuts=4)
    # Back posts lean back, spindles, curved top rail.
    lean = math.radians(12)
    bz0, bz1 = seat, 5.0
    for sx in (-1, 1):
        tube([(sx * 1.3, 1.1, bz0), (sx * 1.3, 1.1 + math.tan(lean) * (bz1 - bz0), bz1)], 0.13, paint, segs=12)
        sphere(0.17, (sx * 1.3, 1.1 + math.tan(lean) * (bz1 - bz0), bz1 + 0.05), paint, segs=12, rings=8)
    rail_y = 1.1 + math.tan(lean) * (4.75 - bz0)
    tube([(-1.3, rail_y, 4.7), (0, rail_y + 0.25, 4.85), (1.3, rail_y, 4.7)], 0.13, paint, segs=10, resolution=6)
    for i in range(5):
        x = -0.9 + i * 0.45
        tube([(x, 1.1 + math.tan(lean) * 0.3, seat + 0.3), (x, rail_y + 0.12 - 0.05 * abs(x), 4.65)], 0.06, paint, segs=8)
    # Arms.
    for sx in (-1, 1):
        y_back = 1.1 + math.tan(lean) * (3.35 - bz0)
        tube([(sx * 1.38, -1.3, 3.3), (sx * 1.42, 0.0, 3.4), (sx * 1.35, y_back, 3.35)], 0.12, paint, segs=10, resolution=6)
        cyl(0.1, 3.3 - seat, (sx * 1.38, -1.25, seat), paint, segs=10, bevel=0.02)
    p = cushion((1.7, 0.45, 1.25), (0, 0, 0), linen, round_=0.5, puff=0.3, front_puff=0.3, cuts=4)
    transform(p, (0, 1.05, seat + 1.15), (math.radians(-14), 0, 0))
    return {}


@item
def reader_chair(M):
    fab = M["fabric"]
    leg_h = 0.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe([(0, 0), (0.12, 0), (0.15, 0.1), (0.1, 0.2), (0.16, 0.42), (0.12, 0.62), (0, 0.62)], (sx * 1.45, sy * 1.35, 0), M["walnut"], segs=14)
    cushion((3.6, 3.4, 1.1), (0, 0.05, leg_h + 0.55), fab, round_=0.3, puff=0.04, cuts=3)
    cushion((2.5, 2.7, 0.65), (0, -0.25, leg_h + 1.1 + 0.3), fab, round_=0.45, puff=0.15, front_puff=0.12, cuts=4)
    back = cushion((3.0, 0.8, 3.4), (0, 0, 0), fab, round_=0.4, puff=0.1, front_puff=0.08, cuts=5)
    transform(back, (0, 1.3, leg_h + 1.1 + 1.65), (math.radians(-8), 0, 0))
    # Tufting on the back.
    for row in range(2):
        for i in range(3 - row):
            x = -0.8 + i * 0.8 + row * 0.4
            sphere(0.09, (x, 0.88 + 0.05 * row, 2.95 + row * 0.85), fab, scale=(1, 0.6, 1), segs=10, rings=6)
    for sx in (-1, 1):
        arm = cushion((0.65, 3.1, 1.2), (0, 0, 0), fab, round_=0.45, puff=0.08, cuts=3)
        transform(arm, (sx * 1.45, -0.1, leg_h + 1.1 + 0.55), (0, 0, 0))
        tube([(sx * 1.45, -1.62, leg_h + 2.1), (sx * 1.45, 1.0, leg_h + 2.1)], 0.36, fab, segs=14, resolution=2)
        wing = cushion((0.55, 1.3, 2.4), (0, 0, 0), fab, round_=0.45, puff=0.06, cuts=3)
        transform(wing, (sx * 1.5, 0.75, leg_h + 3.4), (0, 0, math.radians(sx * 14)))
    throw = material("throw_cream", rgb(246, 238, 222), "knit", rough=0.9, bump=0.7)
    t = box((1.0, 3.0, 0.14), (0, 0, 0), throw, bevel=0.06, seg=2, cuts=6)
    bend(t, 1.2, (0, 0))
    transform(t, (1.45, -0.2, leg_h + 2.55), (0, math.radians(90), 0))
    return {}


@item
def birch_side(M):
    h = 0.75 * CELL
    paint = M["paint"]
    lathe([(0, 0), (1.85, 0), (1.95, 0.08), (1.95, 0.2), (1.85, 0.26), (0, 0.26)], (0, 0, h - 0.26), M["birch"], segs=48)
    lathe([(0, 0), (1.3, 0), (1.35, 0.06), (1.35, 0.14), (0, 0.14)], (0, 0, 1.1), M["birch"], segs=40)
    for i in range(3):
        a = i * 2 * math.pi / 3 + math.pi / 2
        o = cyl(0.1, h - 0.24, (0, 0, 0), paint, segs=14, bevel=0.03, r2=0.15)
        transform(o, (1.15 * math.cos(a), 1.15 * math.sin(a), 0), (math.radians(7) * -math.sin(a), math.radians(7) * math.cos(a), 0))
    # A little pine sprig in a jar and a candle.
    lathe([(0, 0), (0.28, 0), (0.3, 0.5), (0.22, 0.6), (0.24, 0.66), (0, 0.66)], (-0.55, 0.3, h), M["white"], segs=20)
    random.seed(9)
    leaf_m = material("pine_sprig", rgb(64, 120, 88), "leaf", rough=0.6)
    for i in range(7):
        a = i * 0.9
        lb = leaf_blade(0.7, 0.16, bend=0.25, segs=3)
        finish(lb, leaf_m)
        transform(lb, (-0.55, 0.3, h + 0.6), (0, math.radians(-50), a))
    cyl(0.26, 0.5, (0.65, -0.4, h), material("wax2", rgb(250, 242, 226), "ceramic", rough=0.55), segs=18, bevel=0.03)
    cyl(0.02, 0.1, (0.65, -0.4, h + 0.5), M["black"], segs=6, bevel=0)
    book(0.4, 0.65, h, 1.1, 0.8, 0.18, rgb(96, 150, 120), yaw=-0.3)
    return {}


@item
def entry_bench(M):
    w, d = 2 * CELL, CELL
    oak = M["oak"]
    seat = 1.95
    for sx in (-1, 1):
        box((0.3, d - 1.0, seat - 0.1), (sx * (w / 2 - 0.55), 0.1, (seat - 0.1) / 2), oak, bevel=0.06, seg=2)
        box((0.3, 0.3, 3.6 - seat + 0.2), (sx * (w / 2 - 0.55), d / 2 - 0.65, seat + (3.6 - seat) / 2), oak, bevel=0.06, seg=2)
    box((w - 0.8, d - 0.9, 0.2), (0, 0.1, seat), oak, bevel=0.06, seg=2)
    box((w - 1.3, d - 1.2, 0.14), (0, 0.1, 0.45), oak, bevel=0.04, seg=2)
    box((w - 0.9, 0.22, 0.4), (0, d / 2 - 0.65, 3.45), oak, bevel=0.06, seg=2)
    for i in range(7):
        x = -(w - 1.6) / 2 + i * (w - 1.6) / 6
        box((0.12, 0.12, 3.3 - seat - 0.2), (x, d / 2 - 0.65, seat + 0.1 + (3.3 - seat - 0.2) / 2), oak, bevel=0.03, seg=1)
    cushion((w - 1.0, d - 1.25, 0.45), (0, 0.0, seat + 0.32), M["fabric"], round_=0.4, puff=0.1, front_puff=0.08, cuts=5)
    wicker = material("wicker", rgb(206, 170, 120), "knit", rough=0.8, bump=0.8)
    for sx in (-1, 1):
        box((2.6, d - 1.6, 1.15), (sx * 1.9, 0.15, 0.52 + 0.58), wicker, bevel=0.12, seg=2)
        ring(0.25, 0.05, (sx * 1.9, -(d - 1.6) / 2 + 0.12, 1.45), wicker, segs=14, minor_segs=6, rot=(math.radians(90), 0, 0))
    p = cushion((1.4, 0.45, 1.2), (0, 0, 0), M["cream"], round_=0.5, puff=0.3, front_puff=0.3, cuts=4)
    transform(p, (-2.4, d / 2 - 1.05, seat + 1.05), (math.radians(-12), 0, math.radians(10)))
    return {}


@item
def berry_pot(M):
    pot(M, M["tintceramic"], 1.0, 1.45)
    leaf_m, berry_m = holly_mats()
    random.seed(21)
    for i in range(70):
        a = i * 2.39996
        t = (i % 10) / 10
        r = 0.2 + 1.05 * math.sqrt(random.random())
        z = 1.45 + 0.55 + 1.3 * (1 - (r / 1.3) ** 2) * random.uniform(0.7, 1.0)
        lb = leaf_blade(random.uniform(0.55, 0.7), random.uniform(0.32, 0.4), bend=0.2, segs=4)
        finish(lb, leaf_m)
        transform(lb, (r * math.cos(a) * 0.8, r * math.sin(a) * 0.8, z - 0.2), (0, math.radians(random.uniform(-40, 10)), a))
    for i in range(12):
        a = i * 2.1
        r = random.uniform(0.3, 1.05)
        z = 1.45 + 0.55 + 1.3 * (1 - (r / 1.3) ** 2) * 0.95
        berries(r * math.cos(a) * 0.85, r * math.sin(a) * 0.85, z, 4, 0.14, 50 + i, berry_m)
    return {}


# ------------------------------------------------------------ room shell
SHELL = set()


def shell(fn):
    SHELL.add(fn.__name__)
    return item(fn)


def pleated_panel(w, L, m, pleats=6, depth=0.11, flare=0.12, nu=40, nv=22, name="panel"):
    """Curtain panel hanging from z = 0 down to -L, across x in [0, w]."""
    bm = lib.bmesh.new()
    grid = []
    for j in range(nv + 1):
        v = j / nv
        row = []
        for i in range(nu + 1):
            u = i / nu
            amp = depth * (0.75 + 0.6 * v)
            y = -amp * math.sin(u * pleats * 2 * math.pi)
            x = u * w * (1 + flare * v) - w * flare * v * 0.5
            z = -v * L
            if j == nv:
                z += 0.05 * math.sin(u * pleats * 2 * math.pi + 1.0)
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    o = lib._mesh_obj(name, bm)
    sol = o.modifiers.new("sol", "SOLIDIFY"); sol.thickness = 0.04; sol.offset = 0
    lib._apply_mods(o)
    return finish(o, m, 50)


@shell
def curtains(M):
    """Pinch-pleat drapes and a brass rod for the back-wall window (engine studs)."""
    fab = M["fabric"]
    win_w = 9.0
    panel_w = 2.5
    rod_z = 0.0
    L = 12.3
    half = win_w / 2 + 0.2
    for sx in (-1, 1):
        x0 = sx * half - (panel_w if sx > 0 else 0) * 0 + (0 if sx > 0 else -panel_w)
        p = pleated_panel(panel_w, L, fab)
        transform(p, (x0, -0.45, rod_z - 0.32))
        for k in range(7):
            ring(0.17, 0.035, (x0 + k * panel_w / 6, -0.45, rod_z), M["brass"], segs=14, minor_segs=6, rot=(0, math.radians(90), 0))
        # Header band.
        box((panel_w + 0.05, 0.1, 0.42), (x0 + panel_w / 2, -0.45, rod_z - 0.48), fab, bevel=0.03, seg=1)
    rod_half = half + panel_w + 0.6
    rod = cyl(0.09, 2 * rod_half, (0, 0, -rod_half), M["brass"], segs=14, bevel=0.0)
    transform(rod, (0, -0.45, rod_z), (0, math.radians(90), 0))
    for sx in (-1, 1):
        sphere(0.2, (sx * (rod_half + 0.12), -0.45, rod_z), M["brass"], segs=14, rings=8)
        box((0.18, 0.45, 0.18), (sx * (rod_half - 0.35), -0.22, rod_z), M["brass"], bevel=0.04, seg=1)
    return {}


# ------------------------------------------------------------ wall items
# Wall items: back flat on y = 0, the front toward -Y, bottom at z = 0,
# centered on x. Engine side: MeshFit.fitWall hangs them on the wall face.
WALL = set()


def wall(fn):
    WALL.add(fn.__name__)
    return item(fn)


def needle(x, y, z, phi, m, length=0.5, width=0.075, tilt=0.0):
    """One fir needle spray lying in the wall plane, pointing at angle phi (XZ)."""
    lb = leaf_blade(length, width, bend=0.08, segs=2)
    finish(lb, m)
    transform(lb, (x, y, z), (math.radians(-90) + tilt, -phi, 0))
    return lb


def fir_mats():
    return (material("fir", rgb(58, 112, 84), "leaf", rough=0.55, color2=rgb(36, 84, 62)),
            material("fir_dark", rgb(34, 72, 54), "leaf", rough=0.7, color2=rgb(26, 56, 42)))


def ribbon_strip(points, width, m, thick=0.035, name="ribbon"):
    """Flat ribbon along a polyline in the wall plane, its face toward -Y."""
    bm = lib.bmesh.new()
    rows = []
    n = len(points)
    for i, (x, y, z) in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(n - 1, i + 1)]
        tx, tz = b[0] - a[0], b[2] - a[2]
        L = math.hypot(tx, tz) or 1.0
        sx, sz = -tz / L, tx / L
        rows.append((bm.verts.new((x + sx * width / 2, y, z + sz * width / 2)), bm.verts.new((x - sx * width / 2, y, z - sz * width / 2))))
    for i in range(n - 1):
        bm.faces.new((rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1]))
    o = lib._mesh_obj(name, bm)
    sol = o.modifiers.new("sol", "SOLIDIFY"); sol.thickness = thick; sol.offset = 0
    lib._apply_mods(o)
    return finish(o, m, 50)


def catenary(x0, x1, top, sag, y=-0.2, n=16, bulge=0.15):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, y - bulge * math.sin(math.pi * t), top - sag * math.sin(math.pi * t) ** 1.2))
    return pts


def bow(cx, cy, cz, s, m, tails=True):
    for side in (-1, 1):
        lp = ring(0.42 * s, 0.12 * s, (0, 0, 0), m, segs=18, minor_segs=8, rot=(math.radians(90), 0, 0))
        transform(lp, (cx + side * 0.42 * s, cy, cz + 0.06 * s), (0, side * math.radians(-18), 0), (1.0, 0.55, 0.62))
        if tails:
            ribbon_strip([(cx + side * 0.06 * s, cy + 0.02, cz - 0.05 * s), (cx + side * 0.25 * s, cy - 0.03, cz - 0.55 * s),
                          (cx + side * 0.42 * s, cy, cz - 1.05 * s)], 0.26 * s, m, name="tail")
    sphere(0.16 * s, (cx, cy - 0.06 * s, cz), m, scale=(1.1, 0.8, 1.0), segs=12, rings=8, name="knot")


def bell(x, y, z, s, m, clapper_m):
    """Hand bell hanging from (x, y, z): mouth down."""
    prof = [(0, 0), (0.55 * s, 0), (0.6 * s, 0.07 * s), (0.5 * s, 0.2 * s), (0.36 * s, 0.45 * s), (0.3 * s, 0.75 * s), (0.2 * s, 0.9 * s), (0, 0.95 * s)]
    lathe(prof, (x, y, z - 1.1 * s), m, segs=24, cap_bottom=False, angle=50)
    sphere(0.14 * s, (x, y, z - 1.12 * s), clapper_m, segs=10, rings=6)
    ring(0.12 * s, 0.03 * s, (x, y, z - 0.1 * s), m, segs=12, minor_segs=6, rot=(math.radians(90), 0, 0))


def frame_rect(cx, cz, w, h, m, bw=0.34, depth=0.32, lip_m=None):
    """Picture frame molding: outer rails, a stepped inner lip and a back board."""
    for dz in (-1, 1):
        box((w, depth, bw), (cx, -depth / 2, cz + dz * (h / 2 - bw / 2)), m, bevel=0.08, seg=3)
    for dx in (-1, 1):
        box((bw, depth, h - 2 * bw + 0.02), (cx + dx * (w / 2 - bw / 2), -depth / 2, cz), m, bevel=0.08, seg=3)
    lip = lip_m or m
    iw, ih = w - 2 * bw, h - 2 * bw
    for dz in (-1, 1):
        box((iw + 0.02, 0.1, 0.09), (cx, -depth + 0.13, cz + dz * (ih / 2 - 0.045)), lip, bevel=0.03, seg=1)
    for dx in (-1, 1):
        box((0.09, 0.1, ih), (cx + dx * (iw / 2 - 0.045), -depth + 0.13, cz), lip, bevel=0.03, seg=1)
    box((w - 0.1, 0.06, h - 0.1), (cx, -0.03, cz), M_BACK(), bevel=0.0)
    return iw, ih


def M_BACK():
    return material("frame_back", rgb(120, 96, 80), "plain", rough=0.8)


def art_panel(name, cx, cz, w, h, y=-0.1, tint=False):
    img = os.path.join(HERE, "art", name + ".png")
    m = material("art_" + name, (1, 1, 1), "image", rough=0.55, image=img, scale=(w, h), bump=0.08,
                 tint_alpha=tint, plane="xz", image_at=(cx, cz))
    box((w, 0.04, h), (cx, y, cz), m, bevel=0.0)
    return m


@wall
def cocoa_wreath(M):
    fir, fir_dark = fir_mats()
    leaf_m, berry_m = holly_mats()
    R, cz, y0 = 1.55, 2.4, -0.3
    base = ring(R, 0.36, (0, 0, 0), fir_dark, segs=32, minor_segs=8, rot=(math.radians(90), 0, 0))
    transform(base, (0, y0 - 0.05, cz), (0, 0, 0), (1, 0.7, 1))
    rnd = random.Random(5)
    for i in range(300):
        a = rnd.uniform(0, 2 * math.pi)
        dr = rnd.uniform(-0.5, 0.5)
        r = R + dr
        y = y0 - 0.12 - 0.42 * math.cos(dr / 0.5 * math.pi / 2) * rnd.uniform(0.55, 1.0)
        phi = a + math.pi / 2 + rnd.uniform(-0.9, 0.9)
        needle(r * math.cos(a), y, cz + r * math.sin(a), phi, fir if i % 3 else fir_dark,
               length=rnd.uniform(0.42, 0.6), tilt=rnd.uniform(-0.35, 0.35))
    for k in range(8):
        a = k * 2 * math.pi / 8 + 0.3
        if abs(a % (2 * math.pi) - 3 * math.pi / 2) < 0.4:
            continue
        x, z = R * math.cos(a), cz + R * math.sin(a)
        for j in range(3):
            lb = leaf_blade(0.5, 0.24, bend=0.12, segs=3)
            finish(lb, leaf_m)
            transform(lb, (x, y0 - 0.62, z), (math.radians(-90), -(a + j * 2.1), 0))
        berries(x, y0 - 0.78, z, 3, 0.12, 30 + k, berry_m)
    for k, a in enumerate((0.9, 2.3, 4.0, 5.6)):
        x, z = (R + 0.1) * math.cos(a), cz + (R + 0.1) * math.sin(a)
        cone = lathe([(0, 0), (0.16, 0.06), (0.2, 0.2), (0.16, 0.36), (0.08, 0.46), (0, 0.5)], (0, 0, 0), M["walnut"], segs=10, angle=40)
        transform(cone, (x, y0 - 0.55, z), (math.radians(70), 0, a))
        for j in range(3):
            ring(0.16 - j * 0.03, 0.035, (x, y0 - 0.6, z + 0.05 - j * 0.1), M["walnut"], segs=10, minor_segs=4, rot=(math.radians(70), 0, a))
    bow(0, y0 - 0.85, cz - R - 0.05, 1.05, M["fabric"])
    return {"mount": "wall"}


def stocking_outline(L, toe):
    """Boot outline (x right, y up) hanging from y = 0 down to -L."""
    raw = [(-0.6, 0), (0.6, 0), (0.62, -L * 0.62), (0.7, -L * 0.74), (toe, -L * 0.8), (toe + 0.25, -L * 0.9),
           (toe, -L), (0.0, -L), (-0.55, -L * 0.94), (-0.68, -L * 0.8), (-0.62, -L * 0.6)]
    pts = raw
    for _ in range(2):  # Chaikin rounding
        nxt = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            nxt += [(0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]), (0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1])]
        pts = nxt
    return pts


@wall
def stocking_row(M):
    cuff_m = material("cuff", rgb(250, 246, 238), "knit", rough=0.95, bump=0.6)
    heel_m = material("heel", rgb(240, 232, 220), "knit", rough=0.95, bump=0.5)
    W = 2 * CELL
    rail_z = 4.15
    box((W - 0.5, 0.36, 0.5), (0, -0.18, rail_z), M["oak"], bevel=0.08, seg=2)
    box((W - 0.3, 0.46, 0.12), (0, -0.23, rail_z + 0.31), M["oak"], bevel=0.04, seg=2)
    for k, (x, L) in enumerate(((-3.0, 2.7), (0.0, 2.95), (3.0, 2.6))):
        top = rail_z - 0.55
        tube([(x, -0.3, rail_z - 0.1), (x, -0.55, rail_z - 0.2), (x, -0.5, rail_z - 0.42)], 0.05, M["brass"], segs=8, resolution=4)
        o = extrude_outline(stocking_outline(L, 0.95), 0.5, (0, 0, 0), M["knit"], bevel=0.2, seg=3)
        transform(o, (x, -0.22, top), (math.radians(90), 0, 0))
        # Cream heel and toe patches, slightly proud of the front.
        sphere(0.34, (x + 0.95, -0.76, top - L * 0.93), heel_m, scale=(1.0, 0.25, 0.75), segs=14, rings=8)
        sphere(0.3, (x - 0.48, -0.76, top - L * 0.88), heel_m, scale=(1.0, 0.25, 0.85), segs=14, rings=8)
        cushion((1.55, 0.72, 0.62), (x, -0.5, top - 0.18), cuff_m, round_=0.4, puff=0.05, cuts=2)
        ring(0.14, 0.035, (x, -0.42, top + 0.18), cuff_m, segs=12, minor_segs=6, rot=(math.radians(90), 0, 0))
        sphere(0.16, (x - 0.55, -0.9, top - 0.2), cuff_m, segs=10, rings=6, name="pom")
    return {"mount": "wall"}


@wall
def ribbon_sash(M):
    fab = M["fabric"]
    top = 3.9
    xs = (-4.3, 0.0, 4.3)
    for i in range(2):
        pts = catenary(xs[i], xs[i + 1], top, 1.25, y=-0.2, n=18, bulge=0.25)
        ribbon_strip(pts, 0.7, fab, name="swag")
        # A thinner satin edge ribbon riding on top.
        edge = [(x, y - 0.04, z - 0.28) for x, y, z in pts]
        ribbon_strip(edge, 0.12, M["cream"], thick=0.03, name="edge")
    for x in xs:
        bow(x, -0.42, top + 0.05, 1.0 if x == 0 else 0.85, fab)
    return {"mount": "wall"}


@wall
def frosted_frame(M):
    w, h, cz = 3.6, 4.2, 2.3
    iw, ih = frame_rect(0, cz, w, h, M["paint"], lip_m=M["white"])
    art_panel("winter_scene", 0, cz, iw - 0.1, ih - 0.1)
    snow = material("snow", rgb(250, 252, 255), "ceramic", rough=0.6, bump=0.4)
    rnd = random.Random(8)
    for i in range(14):
        x = rnd.uniform(-w / 2 + 0.2, w / 2 - 0.2)
        sphere(rnd.uniform(0.14, 0.26), (x, -0.2, cz + h / 2 + 0.02), snow, scale=(1.6, 1.0, 0.55), segs=12, rings=6)
    for sx, sz in ((-1, 1), (1, -1)):
        for j in range(4):
            sphere(0.16 + 0.03 * j, (sx * (w / 2 - 0.25 - 0.2 * j), -0.36, cz + sz * (h / 2 - 0.25)), snow, scale=(1.2, 0.5, 0.8), segs=10, rings=6)
    fir, _ = fir_mats()
    leaf_m, berry_m = holly_mats()
    for j in range(9):
        needle(-w / 2 + 0.35, -0.5, cz + h / 2 - 0.3, math.radians(-30 + j * 14), fir, length=0.55)
    berries(-w / 2 + 0.35, -0.6, cz + h / 2 - 0.3, 3, 0.1, 77, berry_m)
    return {"mount": "wall"}


@wall
def nutcracker_frame(M):
    w, h, cz = 3.4, 4.3, 2.35
    iw, ih = frame_rect(0, cz, w, h, M["paint"], bw=0.38, lip_m=M["brass"])
    art_panel("nutcracker", 0, cz, iw - 0.1, ih - 0.1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sphere(0.17, (sx * (w / 2 - 0.19), -0.36, cz + sz * (h / 2 - 0.19)), M["brass"], scale=(1, 0.5, 1), segs=14, rings=8)
    # Little crest on top.
    lathe([(0, 0), (0.35, 0), (0.28, 0.2), (0.12, 0.34), (0, 0.4)], (0, -0.16, cz + h / 2 - 0.05), M["brass"], segs=16)
    return {"mount": "wall"}


@wall
def globe_frame(M):
    cz, R = 2.35, 1.82
    o = ring(R, 0.24, (0, 0, 0), M["paint"], segs=48, minor_segs=10, rot=(math.radians(90), 0, 0))
    transform(o, (0, -0.24, cz), (0, 0, 0), (1, 0.8, 1))
    ring(R - 0.26, 0.06, (0, -0.3, cz), M["brass"], segs=48, minor_segs=6, rot=(math.radians(90), 0, 0))
    img = os.path.join(HERE, "art", "snow_globe.png")
    m = material("art_snow_globe", (1, 1, 1), "image", rough=0.5, image=img, scale=(2 * R - 0.3, 2 * R - 0.3), bump=0.05,
                 plane="xz", image_at=(0, cz))
    disc = cyl(R - 0.2, 0.05, (0, 0, 0), m, segs=48, bevel=0)
    transform(disc, (0, -0.08, cz), (math.radians(90), 0, 0))
    back = lathe([(0, 0), (R - 0.1, 0), (R - 0.1, 0.06), (0, 0.06)], (0, 0, 0), M_BACK(), segs=32)
    transform(back, (0, -0.02, cz), (math.radians(90), 0, 0))
    bow(0, -0.5, cz + R + 0.15, 0.7, M["cream"], tails=True)
    return {"mount": "wall"}


@wall
def quilt_square(M):
    img = os.path.join(HERE, "art", "quilt.png")
    q = 3.7
    cz = 2.05
    m = material("quilt_patch", (1, 1, 1), "image", rough=0.92, image=img, scale=(q, q), bump=0.3, tint_alpha=True,
                 plane="xz", image_at=(0, cz))
    o = cushion((q, 0.24, q), (0, 0, 0), m, round_=0.25, puff=0.0, cuts=6, front_puff=0.05)
    transform(o, (0, -0.16, cz))
    tuft = material("tuft", rgb(250, 244, 230), "fabric", rough=0.9)
    for gx in range(1, 4):
        for gz in range(1, 4):
            sphere(0.06, (-q / 2 + gx * q / 4, -0.31, cz - q / 2 + gz * q / 4), tuft, scale=(1, 0.6, 1), segs=8, rings=5)
    rod = cyl(0.09, q + 0.7, (0, 0, -(q + 0.7) / 2), M["oak"], segs=12, bevel=0.0)
    transform(rod, (0, -0.25, cz + q / 2 + 0.32), (0, math.radians(90), 0))
    for sx in (-1, 1):
        sphere(0.15, (sx * (q / 2 + 0.38), -0.25, cz + q / 2 + 0.32), M["oak"], segs=12, rings=8)
    for k in range(5):
        x = -q / 2 + 0.3 + k * (q - 0.6) / 4
        box((0.36, 0.3, 0.62), (x, -0.22, cz + q / 2 + 0.16), tuft, bevel=0.08, seg=2)
    return {"mount": "wall"}


@wall
def bell_banner(M):
    fir, fir_dark = fir_mats()
    top = 3.8
    xs = (-4.2, 0.0, 4.2)
    rnd = random.Random(12)
    for i in range(2):
        pts = catenary(xs[i], xs[i + 1], top, 1.0, y=-0.3, n=24, bulge=0.2)
        tube(pts[::3], 0.16, fir_dark, segs=8, resolution=3)
        for k, (x, y, z) in enumerate(pts):
            for j in range(5):
                phi = rnd.uniform(0, 2 * math.pi)
                needle(x + rnd.uniform(-0.1, 0.1), y - rnd.uniform(0.05, 0.3), z + rnd.uniform(-0.12, 0.12), phi,
                       fir if (k + j) % 3 else fir_dark, length=rnd.uniform(0.38, 0.52), tilt=rnd.uniform(-0.4, 0.4))
        ribbon_strip([(x, y - 0.3, z + 0.1 * math.sin(k * 1.3)) for k, (x, y, z) in enumerate(pts)], 0.3, M["fabric"], name="weave")
    clapper = M["black"]
    for x in xs:
        s = 1.0 if x == 0 else 0.8
        bow(x, -0.62, top + 0.1, 0.8, M["fabric"], tails=False)
        bell(x, -0.6, top - 0.15, s, M["brass"], clapper)
    return {"mount": "wall"}


@wall
def string_lights(M):
    W = 3 * CELL
    top = 4.1
    xs = [-W / 2 + 0.6 + k * (W - 1.2) / 3 for k in range(4)]
    wire = material("wire", rgb(46, 78, 58), "plain", rough=0.5)
    glow = material("bulb_tint", (0.98, 0.96, 0.9), "plain", tint=True, rough=0.18, emit=0.8)
    for x in xs:
        tube([(x, -0.02, top + 0.1), (x, -0.22, top + 0.14), (x, -0.24, top - 0.02)], 0.04, M["brass"], segs=6, resolution=3)
    for i in range(3):
        pts = catenary(xs[i], xs[i + 1], top, 0.9, y=-0.24, n=30, bulge=0.12)
        tube(pts, 0.035, wire, segs=6, resolution=2)
        for k in range(1, 9):
            x, y, z = pts[int(k * 30 / 9)]
            cyl(0.07, 0.18, (x, y, z - 0.2), wire, segs=8, bevel=0.0)
            lathe([(0, 0), (0.1, 0.03), (0.15, 0.14), (0.12, 0.3), (0.075, 0.42), (0.07, 0.46), (0, 0.46)],
                  (x, y, z - 0.64), glow, segs=12, angle=50)
    return {"mount": "wall", "light": {"at": [0, top - 0.9, 0.4], "brightness": 0.5, "range": 11, "color": [255, 220, 160]}}


@shell
def ceiling_lamp(M):
    """Semi-flush drum light hanging from the ceiling at z = 0 (engine studs)."""
    linen = material("linen", rgb(250, 244, 232), "fabric", rough=0.9, sheen=0.3)
    lathe([(0, 0), (0.6, 0), (0.62, -0.04), (0.55, -0.16), (0, -0.18)], (0, 0, 0), M["brass"], segs=28)
    cyl(0.06, 0.75, (0, 0, -0.9), M["brass"], segs=10, bevel=0.0)
    lathe([(0, 0), (0.32, 0), (0.3, 0.12), (0, 0.14)], (0, 0, -1.0), M["brass"], segs=20)
    # Drum shade, open at the bottom with a frosted diffuser.
    lathe([(1.45, 0), (1.48, 0.02), (1.48, 1.0), (1.45, 1.02), (1.4, 1.02), (1.4, 0.0)], (0, 0, -2.05), linen, segs=40,
          cap_top=False, cap_bottom=False, angle=50)
    ring(1.47, 0.04, (0, 0, -2.05), M["brass"], segs=40, minor_segs=6)
    ring(1.47, 0.04, (0, 0, -1.03), M["brass"], segs=40, minor_segs=6)
    lathe([(0, 0), (1.38, 0), (1.38, 0.03), (0, 0.06)], (0, 0, -1.95), M["bulb"], segs=32)
    for k in range(3):
        a = k * 2 * math.pi / 3
        tube([(0.3 * math.cos(a), 0.3 * math.sin(a), -1.0), (1.4 * math.cos(a), 1.4 * math.sin(a), -1.06)], 0.025, M["brass"], segs=6, resolution=1)
    return {"light": {"at": [0, -1.6, 0], "brightness": 0.6, "range": 24}}
