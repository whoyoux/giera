"""Generuje scenes/world.tscn: polana z ruinami w lesie.

Scene mozna potem edytowac w Godocie, ale ponowne uruchomienie skryptu nadpisze takie zmiany.
Wzor wysokosci jest kopia ForestTerrain.height w scripts/world/forest_terrain.gd.
"""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CELL = 2.5
SEED = 1907

STONE = "85858f"
STONE_LIGHT = "9a9aa2"
STONE_DARK = "6c6c78"
MOSS = "5f8048"
WOOD = "8a6240"

SPAWNS = [(23, 2), (-23, -2), (2, -23), (-16, -16), (16, 13), (-17, 12), (22, -8), (-22, -9), (9, -22), (-9, -22)]
# x, z, y albo None dla ziemi.
CHESTS = [
    (-4.5, -4.5, 3.5), (1.5, 1.5, None), (18, -18, None), (-30, 6, None), (31, -3, None), (-6, 31, None),
    (4, 27.4, None), (-8, -31, None), (-25, -23, None), (26, 23, None), (-13, 4, None),
]
TREES = ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_2_A", "Tree_2_B", "Tree_2_C", "Tree_3_A", "Tree_3_B", "Tree_4_A", "Tree_4_B", "Tree_4_C"]
BARE_TREES = ["Tree_Bare_1_A", "Tree_Bare_2_A"]
ROCKS = ["Rock_1_A", "Rock_1_B", "Rock_1_C", "Rock_1_D", "Rock_1_E", "Rock_1_F", "Rock_1_G", "Rock_1_H"]


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def creek_distance(x, z):
    return abs(z - (25.0 + 5.0 * math.sin(x * 0.13)))


def height(x, z):
    d = math.hypot(x, z)
    noise = math.sin(x * 0.21 + 1.3) * math.cos(z * 0.17 - 0.7) * 0.5 + math.sin(x * 0.07 - z * 0.11) * 0.6
    y = noise * smoothstep(20.0, 30.0, d)
    y += 9.0 * smoothstep(33.0, 44.0, d)
    hill = math.hypot(x - 18.0, z + 18.0) / 6.5
    y += 3.5 * math.exp(-hill * hill)
    y -= 1.2 * (1.0 - smoothstep(1.2, 3.2, creek_distance(x, z))) * (1.0 - smoothstep(33.0, 44.0, d))
    return y


def surface(x, z):
    cx, cz = math.floor(x / CELL), math.floor(z / CELL)
    u, v = x / CELL - cx, z / CELL - cz
    x0, z0 = cx * CELL, cz * CELL
    near, far = height(x0 + CELL, z0), height(x0, z0 + CELL)
    if u + v <= 1.0:
        origin = height(x0, z0)
        return origin + (near - origin) * u + (far - origin) * v
    corner = height(x0 + CELL, z0 + CELL)
    return corner + (far - corner) * (1.0 - u) + (near - corner) * (1.0 - v)


def is_path(x, z):
    if math.hypot(x, z) > 31.0:
        return False
    if z < 0.0 and abs(x - 2.0 * math.sin(z * 0.2)) < 1.6:
        return True
    if x > 0.0 and abs(z - 2.0 * math.sin(x * 0.17)) < 1.6:
        return True
    return x < 0.0 and abs(z - 1.5 * math.sin(x * 0.23)) < 1.6


def transform(x, y, z, rot_x=0.0, rot_y=0.0, rot_z=0.0, scale=1.0):
    cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    cz, sz = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
    m = [
        [cy * cz + sy * sx * sz, cy * -sz + sy * sx * cz, sy * cx],
        [cx * sz, cx * cz, -sx],
        [-sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx],
    ]
    values = [v * scale for row in m for v in row] + [x, y, z]
    return "Transform3D(" + ", ".join(f"{v:.5g}" for v in values) + ")"


def tscn_color(value):
    r, g, b = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, 1)"


nodes = []


def group(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="."]\n')


def block(name, size, at, color, rot=(0, 0, 0), bevel=0.08):
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="Ruin"]\n'
        f"transform = {transform(*at, *rot)}\n"
        f'script = ExtResource("block")\n'
        f"size = Vector3({size[0]}, {size[1]}, {size[2]})\n"
        f"color = {tscn_color(color)}\nbevel = {bevel}\n"
    )


def bounds(model):
    data = json.loads((ROOT / "assets" / "forest" / f"{model}_Color1.gltf").read_text(encoding="utf-8"))
    accessor = data["accessors"][data["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
    return accessor["min"], accessor["max"]


def tree(index, model, x, z, scale, yaw):
    nodes.append(
        f'[node name="Tree{index}" type="StaticBody3D" parent="Forest"]\n'
        f"transform = {transform(x, surface(x, z) - 0.05, z, 0, yaw)}\n"
        f'script = ExtResource("forest_prop")\n'
        f'model = "{model}_Color1"\ntrunk_radius = {0.2 * scale:.3f}\ntrunk_height = {3.2 * scale:.2f}\n'
        f"scale_factor = {scale:.3f}\n"
    )


def rock(index, model, x, z, scale, yaw):
    low, high = bounds(model)
    size = [(high[i] - low[i]) * scale * 0.9 for i in range(3)]
    center = [(high[i] + low[i]) * 0.5 * scale for i in range(3)]
    nodes.append(
        f'[node name="Rock{index}" type="StaticBody3D" parent="Forest"]\n'
        f"transform = {transform(x, surface(x, z) - 0.08, z, 0, yaw)}\n"
        f'script = ExtResource("forest_prop")\n'
        f'model = "{model}_Color1"\n'
        f"box_size = Vector3({size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f})\n"
        f"box_center = Vector3({center[0]:.3f}, {center[1]:.3f}, {center[2]:.3f})\n"
        f"scale_factor = {scale:.3f}\n"
    )


def distance_to_segment(x, z, a, b):
    ax, az = a
    bx, bz = b
    t = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / ((bx - ax) ** 2 + (bz - az) ** 2)))
    return math.hypot(x - (ax + (bx - ax) * t), z - (az + (bz - az) * t))


def is_free(x, z, placed, gap):
    if math.hypot(x, z) < 10.5 or is_path(x, z) or creek_distance(x, z) < 3.6:
        return False
    if math.hypot(x - 18.0, z + 18.0) < 3.0:
        return False
    for sx, sz in SPAWNS:
        # Punkt odrodzenia ma wolna przestrzen i wolny widok w strone polany.
        toward = (sx * 0.65, sz * 0.65)
        if distance_to_segment(x, z, (sx, sz), toward) < 3.0:
            return False
    for cx, cz, _ in CHESTS:
        if math.hypot(x - cx, z - cz) < 3.2:
            return False
    return all(math.hypot(x - px, z - pz) >= gap for px, pz in placed)


def scatter(rng, count, inner, outer, gap, placed):
    spots = []
    tries = 0
    while len(spots) < count and tries < count * 60:
        tries += 1
        angle = rng.random() * math.tau
        distance = math.sqrt(rng.uniform(inner * inner, outer * outer))
        x, z = math.sin(angle) * distance, math.cos(angle) * distance
        if is_free(x, z, placed, gap):
            placed.append((x, z))
            spots.append((x, z))
    return spots


def build_ruin():
    group("Ruin")
    walls = [
        ("WallNorthA", (5, 3.0, 1), (-4.5, 1.5, -7), STONE),
        ("WallNorthB", (5, 2.0, 1), (4.5, 1.0, -7), STONE_DARK),
        ("WallSouthA", (4, 2.2, 1), (-5, 1.1, 7), STONE_LIGHT),
        ("WallSouthB", (4, 3.2, 1), (5, 1.6, 7), STONE),
        ("WallEastA", (1, 2.6, 5), (7, 1.3, -4.5), STONE),
        ("WallEastB", (1, 1.5, 5), (7, 0.75, 4.5), STONE_DARK),
        ("WallWest", (1, 3.0, 5), (-7, 1.5, 4.5), STONE_LIGHT),
    ]
    for name, size, at, color in walls:
        block(name, size, at, color)
    # Wieza z rampa: najlepszy widok na polane i skrzynka na szczycie.
    block("Tower", (5, 3.5, 5), (-4.5, 1.75, -4.5), STONE_DARK)
    for i, (x, z) in enumerate([(-6.6, -6.6), (-2.4, -6.6), (-6.6, -2.4), (-6.6, -4.5), (-4.5, -6.6)]):
        block(f"Battlement{i + 1}", (0.8, 0.9, 0.8), (x, 3.95, z), STONE)
    run, rise = 5.5, 3.5
    length = math.hypot(run, rise)
    angle = math.degrees(math.atan2(rise, run))
    block("Ramp", (length, 0.4, 3.0), (-2.0 + run / 2, rise / 2 - 0.15, -4.5), WOOD, rot=(0, 0, -angle), bevel=0.04)
    for i, (x, z, h, color) in enumerate([(4.5, -1.5, 2.6, STONE_LIGHT), (-2.5, 4.5, 2.0, STONE), (2.0, 5.0, 3.0, MOSS)]):
        block(f"Pillar{i + 1}", (1.0, h, 1.0), (x, h / 2, z), color)
    block("FallenPillar", (3.2, 0.9, 0.9), (4.2, 0.45, 3.2), MOSS, rot=(0, 28, 0))
    block("Rubble1", (1.1, 0.7, 1.1), (-1.5, 0.35, 1.8), STONE_DARK, rot=(0, 20, 0))
    block("Rubble2", (0.7, 0.45, 0.8), (-3.2, 0.22, 2.4), STONE, rot=(0, 55, 0))


def build_forest():
    rng = random.Random(SEED)
    group("Forest")
    placed = []
    index = 1
    # Pojedyncze drzewa na polanie i gesty las dookola.
    for x, z in scatter(rng, 14, 13.0, 24.0, 7.0, placed) + scatter(rng, 120, 25.0, 38.0, 3.4, placed):
        model = rng.choice(BARE_TREES) if rng.random() < 0.07 else rng.choice(TREES)
        tree(index, model, x, z, rng.uniform(1.5, 2.3), rng.uniform(0, 360))
        index += 1
    index = 1
    for x, z in scatter(rng, 16, 11.0, 24.0, 5.0, placed) + scatter(rng, 26, 25.0, 38.0, 4.0, placed):
        rock(index, rng.choice(ROCKS), x, z, rng.uniform(1.3, 2.4), rng.uniform(0, 360))
        index += 1


def build_markers():
    group("SpawnPoints")
    for i, (x, z) in enumerate(SPAWNS):
        nodes.append(
            f'[node name="Spawn{i + 1}" type="Marker3D" parent="SpawnPoints" groups=["spawn_points"]]\n'
            f"transform = {transform(x, surface(x, z) + 0.2, z)}\n"
        )
    group("ChestSpots")
    for i, (x, z, y) in enumerate(CHESTS):
        at_y = surface(x, z) if y is None else y
        yaw = math.degrees(math.atan2(-x, -z))
        nodes.append(
            f'[node name="Chest{i + 1}" type="Marker3D" parent="ChestSpots" groups=["chest_spots"]]\n'
            f"transform = {transform(x, round(at_y, 4), z, 0, yaw)}\n"
        )


header = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/block.gd" id="block"]
[ext_resource type="Script" path="res://scripts/world/forest_prop.gd" id="forest_prop"]
[ext_resource type="Script" path="res://scripts/world/forest_terrain.gd" id="terrain"]

[sub_resource type="ProceduralSkyMaterial" id="sky_material"]
sky_top_color = Color(0.42, 0.68, 0.96, 1)
sky_horizon_color = Color(0.82, 0.92, 0.98, 1)
ground_bottom_color = Color(0.4, 0.55, 0.32, 1)
ground_horizon_color = Color(0.82, 0.92, 0.98, 1)
sun_angle_max = 2.0

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_material")

[sub_resource type="Environment" id="environment"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 3
ambient_light_color = Color(1, 0.97, 0.92, 1)
ambient_light_sky_contribution = 0.6
ambient_light_energy = 0.5
tonemap_mode = 2
tonemap_white = 1.6
ssao_enabled = true
ssao_radius = 1.4
ssao_intensity = 1.3
ssao_sharpness = 0.9
glow_enabled = true
glow_intensity = 0.2
fog_enabled = true
fog_light_color = Color(0.78, 0.88, 0.92, 1)
fog_density = 0.0025
fog_sky_affect = 0.0

[node name="World" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.77, -0.45, 0.45, 0, 0.71, 0.71, -0.64, -0.54, 0.54, 0, 30, 0)
light_color = Color(1, 0.93, 0.8, 1)
light_energy = 1.45
shadow_enabled = true
shadow_bias = 0.04
shadow_normal_bias = 1.2
shadow_blur = 1.6
directional_shadow_mode = 2
directional_shadow_fade_start = 0.9
directional_shadow_max_distance = 85.0

[node name="Terrain" type="StaticBody3D" parent="."]
script = ExtResource("terrain")

"""

build_ruin()
build_forest()
build_markers()
target = ROOT / "scenes" / "world.tscn"
target.write_text(header + "\n".join(nodes), encoding="utf-8", newline="\n")
print(f"zapisano {target}, wezlow: {len(nodes)}")
