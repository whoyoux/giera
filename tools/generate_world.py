"""Generuje pierwsza wersje scenes/world.tscn.

Uzyty raz do rozstawienia mapy. Scene mozna dalej edytowac w Godocie, ale
ponowne uruchomienie tego skryptu nadpisze takie zmiany.
"""
import math
from pathlib import Path

GRASS = "7cc95a"
DIRT = "c9a66b"
CLIFF = "c9ab86"
WOOD = "b5763f"
CRATE = "e0a458"
STONE = "aab0c4"
PLASTER = "f2e3c6"
ROOF = "d9534f"
BLUE = "4f9dde"

nodes: list[str] = []
counter = {"Block": 0, "Prop": 0}


def transform(x, y, z, rot_x=0.0, rot_y=0.0, rot_z=0.0):
    cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    cz, sz = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
    # R = Ry * Rx * Rz
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


def block(group, name, size, at, color, rot=(0, 0, 0), outline=True):
    counter["Block"] += 1
    extra = "" if outline else "outline = false\n"
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{group}"]\n'
        f"transform = {transform(*at, *rot)}\n"
        f'script = ExtResource("block")\n'
        f"size = Vector3({size[0]}, {size[1]}, {size[2]})\n"
        f"color = {tscn_color(color)}\n{extra}"
    )


def prop(group, name, kind, x, z, size=1.0, y=0.0, rot=0):
    counter["Prop"] += 1
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{group}"]\n'
        f"transform = {transform(x, y, z, 0, rot)}\n"
        f'script = ExtResource("prop")\n'
        f"kind = {kind}\nsize = {size}\n"
    )


def group(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n')


TREE, PINE, ROCK, BUSH = 0, 1, 2, 3
HALF = 32

group("Terrain")
block("Terrain", "Ground", (170, 2, 170), (0, -1, 0), GRASS, outline=False)
block("Terrain", "PathNS", (5, 0.04, HALF * 2), (0, 0, 0), DIRT, outline=False)
block("Terrain", "PathEW", (HALF * 2, 0.06, 5), (0, 0, 0), DIRT, outline=False)
block("Terrain", "WallN", (HALF * 2 + 4, 4, 2), (0, 2, -HALF - 1), CLIFF)
block("Terrain", "WallS", (HALF * 2 + 4, 4, 2), (0, 2, HALF + 1), CLIFF)
block("Terrain", "WallE", (2, 4, HALF * 2 + 4), (HALF + 1, 2, 0), CLIFF)
block("Terrain", "WallW", (2, 4, HALF * 2 + 4), (-HALF - 1, 2, 0), CLIFF)

group("Center")
height = 3.0
block("Center", "Tower", (9, height, 9), (0, height / 2, 0), STONE)
length = 8.0
angle = math.degrees(math.asin(height / length))
run = math.cos(math.radians(angle)) * length / 2
thick = 0.5
lift = height / 2 - thick / 2 * math.cos(math.radians(angle))
block("Center", "RampS", (4.5, thick, length), (0, lift, 4.5 + run), DIRT, rot=(angle, 0, 0))
block("Center", "RampN", (4.5, thick, length), (0, lift, -4.5 - run), DIRT, rot=(-angle, 0, 0))
block("Center", "ParapetW", (0.5, 1.1, 9), (-4.25, height + 0.55, 0), STONE)
block("Center", "ParapetE", (0.5, 1.1, 9), (4.25, height + 0.55, 0), STONE)
block("Center", "CoverA", (2.4, 1.2, 0.6), (0, height + 0.6, -1.8), WOOD)
block("Center", "CoverB", (2.4, 1.2, 0.6), (0, height + 0.6, 1.8), WOOD)


def hut(name, x, z, rot):
    """Domek z otworem drzwiowym, zbudowany z osobnych scian."""
    group_name = f"{name}"
    nodes.append(
        f'[node name="{group_name}" type="Node3D" parent="."]\n'
        f"transform = {transform(x, 0, z, 0, rot)}\n"
    )
    w, d, h, t = 8.0, 6.0, 3.2, 0.4
    block(group_name, "Back", (w, h, t), (0, h / 2, -d / 2), PLASTER)
    block(group_name, "Left", (t, h, d), (-w / 2, h / 2, 0), PLASTER)
    block(group_name, "Right", (t, h, d), (w / 2, h / 2, 0), PLASTER)
    block(group_name, "FrontA", (2.8, h, t), (-2.6, h / 2, d / 2), PLASTER)
    block(group_name, "FrontB", (2.8, h, t), (2.6, h / 2, d / 2), PLASTER)
    block(group_name, "Lintel", (2.4, 0.7, t), (0, h - 0.35, d / 2), PLASTER)
    block(group_name, "Roof", (w + 1.2, 0.5, d + 1.2), (0, h + 0.25, 0), ROOF)
    block(group_name, "Crate", (1.2, 1.2, 1.2), (2.6, 0.6, -1.8), CRATE)


hut("HutEast", 21, -11, -90)
hut("HutWest", -21, 11, 90)

group("Cover")
crates = [
    (9, 9, 2.0), (11.2, 9.4, 1.4), (-9, -9, 2.0), (-11.2, -9.5, 1.4),
    (14, 22, 2.0), (-14, -22, 2.0), (-22, -20, 1.6), (22, 20, 1.6),
    (9, -22, 1.6), (-9, 22, 1.6),
]
for i, (x, z, s) in enumerate(crates):
    block("Cover", f"Crate{i + 1}", (s, s, s), (x, s / 2, z), CRATE, rot=(0, (i * 23) % 40, 0))
walls = [
    (-12, 3.5, 7, 0), (12, -3.5, 7, 0), (-24, -5, 6, 90), (24, 5, 6, 90),
    (3.5, 18, 6, 90), (-3.5, -18, 6, 90),
]
for i, (x, z, l, r) in enumerate(walls):
    block("Cover", f"Wall{i + 1}", (l, 1.5, 0.7), (x, 0.75, z), BLUE, rot=(0, r, 0))

group("Nature")
trees = [
    (TREE, -27, -27, 1.2), (TREE, 27, 27, 1.2), (PINE, -27, 26, 1.3), (PINE, 26, -27, 1.3),
    (TREE, -16, -14, 1.0), (TREE, 16, 14, 1.0), (PINE, -8, 27, 1.1), (PINE, 8, -27, 1.1),
    (PINE, -28, -6, 1.2), (PINE, 28, 6, 1.2), (TREE, 17, -24, 1.1), (TREE, -17, 24, 1.1),
]
for i, (kind, x, z, s) in enumerate(trees):
    prop("Nature", f"Tree{i + 1}", kind, x, z, s, rot=i * 47)
rocks = [(-7, 14, 1.0), (7, -14, 1.0), (-28, 16, 1.4), (28, -16, 1.4), (15, 4, 0.8), (-15, -4, 0.8), (-5, -27, 1.1), (5, 27, 1.1)]
for i, (x, z, s) in enumerate(rocks):
    prop("Nature", f"Rock{i + 1}", ROCK, x, z, s, rot=i * 61)
bushes = [(-20, -2, 1.0), (20, 2, 1.0), (-10, -16, 1.1), (10, 16, 1.1), (-25, 24, 1.0), (25, -24, 1.0)]
for i, (x, z, s) in enumerate(bushes):
    prop("Nature", f"Bush{i + 1}", BUSH, x, z, s, rot=i * 33)

group("Horizon")
for i in range(44):
    # Stale przesuniecia zamiast losowania, zeby kazdy przebieg dawal te sama mape.
    angle_rad = i / 44 * math.tau
    radius = 44 + (i * 7 % 13)
    x, z = math.cos(angle_rad) * radius, math.sin(angle_rad) * radius
    kind = PINE if i % 3 else TREE
    prop("Horizon", f"Far{i + 1}", kind, round(x, 1), round(z, 1), 1.8 + (i * 5 % 9) * 0.15, rot=i * 37)

group("SpawnPoints")
spawns = [(-30, -24), (24, -30), (30, 24), (-24, 30), (0, -29), (0, 29), (-29, 0), (29, 0), (-13, -27), (13, 27)]
for i, (x, z) in enumerate(spawns):
    nodes.append(
        f'[node name="Spawn{i + 1}" type="Marker3D" parent="SpawnPoints" groups=["spawn_points"]]\n'
        f"transform = {transform(x, 0.1, z)}\n"
    )

header = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/block.gd" id="block"]
[ext_resource type="Script" path="res://scripts/world/prop.gd" id="prop"]

[sub_resource type="ProceduralSkyMaterial" id="sky_material"]
sky_top_color = Color(0.32, 0.62, 0.95, 1)
sky_horizon_color = Color(0.78, 0.92, 1, 1)
sky_curve = 0.18
ground_bottom_color = Color(0.5, 0.78, 0.38, 1)
ground_curve = 0.5
ground_horizon_color = Color(0.62, 0.86, 0.72, 1)
sun_angle_max = 8.0

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_material")

[sub_resource type="Environment" id="environment"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 2
ambient_light_color = Color(0.86, 0.85, 0.95, 1)
ambient_light_energy = 0.62
tonemap_mode = 0
fog_enabled = true
fog_light_color = Color(0.78, 0.9, 1, 1)
fog_density = 0.0012
fog_sky_affect = 0.0

[node name="World" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.77, -0.45, 0.45, 0, 0.71, 0.71, -0.64, -0.54, 0.54, 0, 30, 0)
light_color = Color(1, 0.96, 0.86, 1)
light_energy = 0.62
shadow_enabled = true
directional_shadow_mode = 0
directional_shadow_max_distance = 110.0

"""

target = Path(__file__).resolve().parent.parent / "scenes" / "world.tscn"
target.write_text(header + "\n".join(nodes), encoding="utf-8", newline="\n")
print(f"zapisano {target}: {counter}")
