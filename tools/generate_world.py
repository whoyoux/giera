"""Generuje pierwsza wersje scenes/world.tscn: pokoj z wielkimi zabawkami.

Uzyty raz do rozstawienia mapy. Scene mozna dalej edytowac w Godocie, ale
ponowne uruchomienie tego skryptu nadpisze takie zmiany.
"""
import math
from pathlib import Path

WOOD = "c9925e"
WOOD_DARK = "a97646"
MAT = "7fc4a8"
ROAD = "5f6b7a"
WALL = "f4dfc0"
TRIM = "fff6e0"
RED = "ef6f6c"
ORANGE = "f9a03f"
YELLOW = "f5d547"
GREEN = "6fcf97"
BLUE = "5b8def"
PURPLE = "9b7bff"
PINK = "f29ac2"
NATURAL = "e6c79c"
GLASS = "bfe8ff"

nodes: list[str] = []
counter = {"Block": 0, "Prop": 0}


def transform(x, y, z, rot_x=0.0, rot_y=0.0, rot_z=0.0):
    cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    cz, sz = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
    m = [
        [cy * cz + sy * sx * sz, cy * -sz + sy * sx * cz, sy * cx],
        [cx * sz, cx * cz, -sx],
        [-sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx],
    ]
    values = [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], x, y, z]
    return "Transform3D(" + ", ".join(f"{v:.5g}" for v in values) + ")"


def tscn_color(value):
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, 1)"


def block(parent, name, size, at, color, rot=(0, 0, 0), bevel=None, letter=None):
    counter["Block"] += 1
    extra = "" if bevel is None else f"bevel = {bevel}\n"
    extra += "" if letter is None else f'letter = "{letter}"\n'
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
        f"transform = {transform(*at, *rot)}\n"
        f'script = ExtResource("block")\n'
        f"size = Vector3({size[0]}, {size[1]}, {size[2]})\n"
        f"color = {tscn_color(color)}\n{extra}"
    )


def prop(parent, name, kind, x, z, size=1.0, color=RED, rot=0):
    counter["Prop"] += 1
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
        f"transform = {transform(x, 0, z, 0, rot)}\n"
        f'script = ExtResource("prop")\n'
        f"kind = {kind}\nsize = {size}\ncolor = {tscn_color(color)}\n"
    )


def group(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n')


BALL, RINGS, PENCIL, CONE, CRATE = 0, 1, 2, 3, 4
HALF = 32
WALL_H = 22

# Pokoj: drewniana podloga z mata, sciany z listwa, okna z widokiem na niebo.
group("Room")
block("Room", "Floor", (HALF * 2 + 40, 2, HALF * 2 + 40), (0, -1, 0), WOOD, bevel=0)
for i in range(-3, 4):
    block("Room", f"Plank{i + 4}", (HALF * 2 + 4, 0.03, 0.08), (0, 0.0, i * 9), WOOD_DARK, bevel=0)
block("Room", "Mat", (46, 0.06, 46), (0, 0.0, 0), MAT, bevel=0)
block("Room", "RoadNS", (6, 0.09, 46), (0, 0.0, 0), ROAD, bevel=0)
block("Room", "RoadEW", (46, 0.11, 6), (0, 0.0, 0), ROAD, bevel=0)
for i in range(-3, 4):
    if i:
        block("Room", f"DashNS{i + 4}", (0.4, 0.13, 3), (0, 0.0, i * 6.5), TRIM, bevel=0)
        block("Room", f"DashEW{i + 4}", (3, 0.13, 0.4), (i * 6.5, 0.0, 0), TRIM, bevel=0)
for name, size, at in [
    ("WallN", (HALF * 2 + 4, WALL_H, 2), (0, WALL_H / 2, -HALF - 1)),
    ("WallS", (HALF * 2 + 4, WALL_H, 2), (0, WALL_H / 2, HALF + 1)),
    ("WallE", (2, WALL_H, HALF * 2 + 4), (HALF + 1, WALL_H / 2, 0)),
    ("WallW", (2, WALL_H, HALF * 2 + 4), (-HALF - 1, WALL_H / 2, 0)),
]:
    block("Room", name, size, at, WALL, bevel=0)
block("Room", "TrimN", (HALF * 2, 1.2, 0.3), (0, 0.6, -HALF + 0.1), TRIM, bevel=0.04)
block("Room", "TrimS", (HALF * 2, 1.2, 0.3), (0, 0.6, HALF - 0.1), TRIM, bevel=0.04)
block("Room", "TrimE", (0.3, 1.2, HALF * 2), (HALF - 0.1, 0.6, 0), TRIM, bevel=0.04)
block("Room", "TrimW", (0.3, 1.2, HALF * 2), (-HALF + 0.1, 0.6, 0), TRIM, bevel=0.04)
for i, x in enumerate((-16, 16)):
    block("Room", f"Window{i + 1}", (11, 11, 0.2), (x, 11, -HALF + 0.05), GLASS, bevel=0)
    block("Room", f"FrameV{i + 1}", (0.5, 11.5, 0.4), (x, 11, -HALF + 0.15), TRIM, bevel=0.05)
    block("Room", f"FrameH{i + 1}", (11.5, 0.5, 0.4), (x, 11, -HALF + 0.15), TRIM, bevel=0.05)
    block("Room", f"FrameT{i + 1}", (11.8, 0.6, 0.5), (x, 16.8, -HALF + 0.2), TRIM, bevel=0.05)
    block("Room", f"FrameB{i + 1}", (11.8, 0.6, 0.5), (x, 5.2, -HALF + 0.2), TRIM, bevel=0.05)

# Srodek: wieza z ksiazek i wielkich klockow.
group("Center")
height = 3.0
block("Center", "BookA", (11, 1.0, 10), (0, 0.5, 0), BLUE, bevel=0.12)
block("Center", "BookB", (10.4, 1.0, 9.4), (0.15, 1.5, 0), RED, bevel=0.12)
block("Center", "BookC", (9.6, 1.0, 9), (-0.1, 2.5, 0), YELLOW, bevel=0.12)
length = 8.5
angle = math.degrees(math.asin(height / length))
run = math.cos(math.radians(angle)) * length / 2
thick = 0.5
lift = height / 2 - thick / 2 * math.cos(math.radians(angle))
block("Center", "RulerS", (4.6, thick, length), (0, lift, 4.5 + run), ORANGE, rot=(angle, 0, 0), bevel=0.06)
block("Center", "RulerN", (4.6, thick, length), (0, lift, -4.5 - run), ORANGE, rot=(-angle, 0, 0), bevel=0.06)
block("Center", "TopW", (1.5, 1.5, 1.5), (-3.3, height + 0.75, -2.8), PURPLE, letter="A")
block("Center", "TopE", (1.5, 1.5, 1.5), (3.3, height + 0.75, 2.8), GREEN, letter="B")
block("Center", "TopMid", (2.4, 1.1, 0.8), (0, height + 0.55, 0), PINK)


def fort(name, x, z, rot, color):
    """Fort z klockow z otworem na wejscie."""
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n' f"transform = {transform(x, 0, z, 0, rot)}\n")
    w, d, h, t = 9.0, 7.0, 3.4, 0.7
    block(name, "Back", (w, h, t), (0, h / 2, -d / 2), NATURAL)
    block(name, "Left", (t, h, d), (-w / 2, h / 2, 0), NATURAL)
    block(name, "Right", (t, h, d), (w / 2, h / 2, 0), NATURAL)
    block(name, "FrontA", (3.0, h, t), (-3.0, h / 2, d / 2), NATURAL)
    block(name, "FrontB", (3.0, h, t), (3.0, h / 2, d / 2), NATURAL)
    block(name, "Lintel", (3.0, 0.9, t), (0, h - 0.45, d / 2), color)
    block(name, "Roof", (w + 1.6, 0.7, d + 1.6), (0, h + 0.35, 0), color, bevel=0.15)
    block(name, "RoofTop", (w - 2, 1.4, 2.2), (0, h + 1.4, 0), color, bevel=0.15)


fort("FortEast", 22, -12, -90, RED)
fort("FortWest", -22, 12, 90, BLUE)

group("Cover")
letters = "GIERATOYSBOX"
palette = [RED, ORANGE, YELLOW, GREEN, BLUE, PURPLE, PINK]
blocks = [
    (9, 9, 2.4), (11.7, 9.5, 1.6), (11.2, 11.6, 1.6), (-9, -9, 2.4), (-11.7, -9.5, 1.6), (-11.2, -11.6, 1.6),
    (14, 23, 2.4), (-14, -23, 2.4), (-23, -20, 2.0), (23, 20, 2.0), (9, -23, 2.0), (-9, 23, 2.0),
]
for i, (x, z, s) in enumerate(blocks):
    block("Cover", f"Letter{i + 1}", (s, s, s), (x, s / 2, z), palette[i % len(palette)], rot=(0, (i * 23) % 40, 0), letter=letters[i])
walls = [(-12, 3.5, 8, 0, GREEN), (12, -3.5, 8, 0, PURPLE), (-25, -5, 7, 90, ORANGE), (25, 5, 7, 90, PINK), (3.8, 18, 7, 90, BLUE), (-3.8, -18, 7, 90, RED)]
for i, (x, z, l, r, c) in enumerate(walls):
    block("Cover", f"Domino{i + 1}", (l, 1.7, 0.9), (x, 0.85, z), c, rot=(0, r, 0), bevel=0.14)

group("Toys")
for i, (x, z, s, c) in enumerate([(-7, 14, 1.0, RED), (7, -14, 1.0, BLUE), (15, 4, 0.85, YELLOW), (-15, -4, 0.85, PINK), (-28, 18, 1.5, GREEN), (28, -18, 1.5, PURPLE)]):
    prop("Toys", f"Ball{i + 1}", BALL, x, z, s, c, rot=i * 61)
for i, (x, z, s) in enumerate([(-27, -27, 1.5), (27, 27, 1.5), (-17, -15, 1.1), (17, 15, 1.1)]):
    prop("Toys", f"Rings{i + 1}", RINGS, x, z, s, rot=i * 47)
for i, (x, z, c) in enumerate([(-28, 7, BLUE), (28, -7, RED), (-6, 28, GREEN), (6, -28, YELLOW)]):
    prop("Toys", f"Pencil{i + 1}", PENCIL, x, z, 1.0, c, rot=i * 33)
for i, (x, z) in enumerate([(5, 5.5), (-5, -5.5), (-5, 16), (5, -16), (18, -3), (-18, 3)]):
    prop("Toys", f"Cone{i + 1}", CONE, x, z, 0.7, rot=i * 20)
prop("Toys", "CrateA", CRATE, 18, 27, 1.0, rot=0)
prop("Toys", "CrateB", CRATE, -18, -27, 1.0, rot=180)

group("SpawnPoints")
spawns = [(-30, -22), (22, -30), (30, 22), (-22, 30), (0, -29), (0, 29), (-29, 0), (29, 0), (-13, -29), (13, 29)]
for i, (x, z) in enumerate(spawns):
    nodes.append(
        f'[node name="Spawn{i + 1}" type="Marker3D" parent="SpawnPoints" groups=["spawn_points"]]\n'
        f"transform = {transform(x, 0.2, z)}\n"
    )

group("ChestSpots")
chest_spots = [
    (22, 0.03, -12, -90), (-22, 0.03, 12, 90), (-2.5, 3.0, 2.5, 20),
    (-8, 0.03, -12, 200), (8, 0.03, 12, 20),
    (28.5, 0.0, -28.5, -45), (-28.5, 0.0, 28.5, 135),
    (-6, 0.03, -18, 90), (6, 0.03, 18, -90),
    (27, 0.0, 6, -90), (-27, 0.0, -6, 90),
]
for i, (x, y, z, rot) in enumerate(chest_spots):
    nodes.append(
        f'[node name="Chest{i + 1}" type="Marker3D" parent="ChestSpots" groups=["chest_spots"]]\n'
        f"transform = {transform(x, y, z, 0, rot)}\n"
    )

header = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/block.gd" id="block"]
[ext_resource type="Script" path="res://scripts/world/prop.gd" id="prop"]

[sub_resource type="ProceduralSkyMaterial" id="sky_material"]
sky_top_color = Color(0.42, 0.68, 0.96, 1)
sky_horizon_color = Color(0.86, 0.94, 1, 1)
ground_bottom_color = Color(0.72, 0.62, 0.5, 1)
ground_horizon_color = Color(0.86, 0.94, 1, 1)
sun_angle_max = 2.0

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_material")

[sub_resource type="Environment" id="environment"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 3
ambient_light_color = Color(1, 0.97, 0.92, 1)
ambient_light_sky_contribution = 0.6
ambient_light_energy = 0.55
tonemap_mode = 2
tonemap_white = 1.6
ssao_enabled = true
ssao_radius = 1.4
ssao_intensity = 1.3
ssao_sharpness = 0.9
glow_enabled = true
glow_intensity = 0.2

[node name="World" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.77, -0.45, 0.45, 0, 0.71, 0.71, -0.64, -0.54, 0.54, 0, 30, 0)
light_color = Color(1, 0.93, 0.8, 1)
light_energy = 1.9
shadow_enabled = true
shadow_bias = 0.04
shadow_normal_bias = 1.2
shadow_blur = 1.6
directional_shadow_mode = 2
directional_shadow_fade_start = 0.9
directional_shadow_max_distance = 85.0

"""

target = Path(__file__).resolve().parent.parent / "scenes" / "world.tscn"
target.write_text(header + "\n".join(nodes), encoding="utf-8", newline="\n")
print(f"zapisano {target}: {counter}")
