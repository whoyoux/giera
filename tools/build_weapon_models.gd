extends Node
## Narzedzie: buduje kodem modele Desert Eagle i AWP i zapisuje je jako .glb w assets/weapons.
## Uzycie: godot --path . --headless -- --tool=res://tools/build_weapon_models.gd
## Potem: godot --headless --path . --import, a ikony: --tool=res://tools/render_icons.gd --only=deagle,awp
## Uklad jak w paczce blasterow: lufa w -Z, gora w +Y, a wezel "magazine" wypada przy przeladowaniu.

const GOLD := Color("e9b949")
const GOLD_DARK := Color("b8862f")
const INK := Color("3b3552")
const GRIP := Color("6b4a3a")
const STEEL := Color("8f96a8")
const TEAL := Color("2f8f83")
const TEAL_DARK := Color("226b62")
const CORAL := Color("ef6f6c")
const GLASS := Color("7fd3ff")


func _ready() -> void:
	_save(_deagle(), "res://assets/weapons/deagle.glb")
	_save(_awp(), "res://assets/weapons/awp.glb")
	get_tree().quit()


## Ciezki pistolet: zloty zamek, ciemna rama i drewniana rekojesc.
func _deagle() -> Node3D:
	var root := Node3D.new()
	root.name = "Deagle"
	LowPoly.part(root, LowPoly.box(Vector3(0.075, 0.075, 0.36), 0.018), GOLD, Vector3(0.0, 0.105, -0.13))
	LowPoly.part(root, LowPoly.box(Vector3(0.08, 0.02, 0.2), 0.008), GOLD_DARK, Vector3(0.0, 0.07, -0.21))
	for i in 5:
		LowPoly.part(root, LowPoly.box(Vector3(0.082, 0.05, 0.008), 0.002), GOLD_DARK, Vector3(0.0, 0.11, 0.0 - i * 0.018))
	LowPoly.part(root, LowPoly.box(Vector3(0.052, 0.052, 0.03), 0.01), INK, Vector3(0.0, 0.105, -0.32))
	LowPoly.part(root, LowPoly.box(Vector3(0.068, 0.055, 0.25), 0.014), INK, Vector3(0.0, 0.045, -0.09))
	LowPoly.part(root, LowPoly.box(Vector3(0.014, 0.022, 0.014), 0.004), INK, Vector3(0.0, 0.152, -0.29))
	LowPoly.part(root, LowPoly.box(Vector3(0.05, 0.02, 0.014), 0.004), INK, Vector3(0.0, 0.152, 0.03))
	LowPoly.part(root, LowPoly.box(Vector3(0.03, 0.04, 0.03), 0.008), INK, Vector3(0.0, 0.13, 0.055), Vector3(-25, 0, 0))
	# Kablak spustu: dwie belki i spust.
	LowPoly.part(root, LowPoly.box(Vector3(0.02, 0.012, 0.1), 0.004), INK, Vector3(0.0, -0.025, -0.04))
	LowPoly.part(root, LowPoly.box(Vector3(0.02, 0.05, 0.012), 0.004), INK, Vector3(0.0, -0.002, -0.085))
	LowPoly.part(root, LowPoly.box(Vector3(0.012, 0.035, 0.012), 0.004), STEEL, Vector3(0.0, 0.0, -0.035), Vector3(15, 0, 0))
	var grip := LowPoly.part(root, LowPoly.box(Vector3(0.064, 0.17, 0.085), 0.02), GRIP, Vector3(0.0, -0.045, 0.035), Vector3(14, 0, 0))
	grip.name = "Grip"
	var magazine := Node3D.new()
	magazine.name = "magazine"
	magazine.position = Vector3(0.0, -0.12, 0.055)
	magazine.rotation_degrees = Vector3(14, 0, 0)
	root.add_child(magazine)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.05, 0.04, 0.07), 0.01), INK)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.056, 0.014, 0.08), 0.005), GOLD_DARK, Vector3(0.0, -0.024, 0.0))
	return root


## Snajperka: dlugi turkusowy korpus, ciemna lufa, gruba luneta z koralowymi oslonami.
func _awp() -> Node3D:
	var root := Node3D.new()
	root.name = "Awp"
	LowPoly.part(root, LowPoly.box(Vector3(0.075, 0.13, 0.32), 0.03), TEAL, Vector3(0.0, -0.005, 0.34))
	LowPoly.part(root, LowPoly.box(Vector3(0.08, 0.14, 0.05), 0.02), INK, Vector3(0.0, -0.005, 0.51))
	LowPoly.part(root, LowPoly.box(Vector3(0.06, 0.05, 0.2), 0.015), TEAL_DARK, Vector3(0.0, 0.07, 0.32))
	LowPoly.part(root, LowPoly.box(Vector3(0.085, 0.095, 0.36), 0.022), TEAL, Vector3(0.0, 0.035, -0.01))
	LowPoly.part(root, LowPoly.box(Vector3(0.07, 0.06, 0.34), 0.018), TEAL_DARK, Vector3(0.0, 0.0, -0.33))
	LowPoly.part(root, LowPoly.cylinder(0.019, 0.019, 0.5, 8), INK, Vector3(0.0, 0.045, -0.55), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.box(Vector3(0.05, 0.05, 0.08), 0.012), INK, Vector3(0.0, 0.045, -0.82))
	for i in 3:
		LowPoly.part(root, LowPoly.box(Vector3(0.056, 0.012, 0.012), 0.003), STEEL, Vector3(0.0, 0.045, -0.80 - i * 0.02))
	# Luneta na dwoch uchwytach.
	LowPoly.part(root, LowPoly.cylinder(0.034, 0.034, 0.3, 10), INK, Vector3(0.0, 0.14, -0.03), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.cylinder(0.05, 0.036, 0.08, 10), CORAL, Vector3(0.0, 0.14, -0.21), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.cylinder(0.036, 0.046, 0.06, 10), CORAL, Vector3(0.0, 0.14, 0.14), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.cylinder(0.04, 0.04, 0.012, 10), GLASS, Vector3(0.0, 0.14, -0.252), Vector3(90, 0, 0), 0.05)
	LowPoly.part(root, LowPoly.cylinder(0.012, 0.012, 0.03, 6), INK, Vector3(0.0, 0.18, -0.03))
	LowPoly.part(root, LowPoly.cylinder(0.012, 0.012, 0.03, 6), INK, Vector3(0.035, 0.14, -0.03), Vector3(0, 0, 90))
	for z: float in [-0.12, 0.06]:
		LowPoly.part(root, LowPoly.box(Vector3(0.03, 0.05, 0.03), 0.008), STEEL, Vector3(0.0, 0.095, z))
	# Rygiel zamka po prawej stronie.
	LowPoly.part(root, LowPoly.cylinder(0.008, 0.008, 0.07, 6), STEEL, Vector3(0.06, 0.05, 0.1), Vector3(0, 0, 90))
	LowPoly.part(root, LowPoly.box(Vector3(0.034, 0.034, 0.034), 0.01), CORAL, Vector3(0.095, 0.05, 0.1))
	var grip := LowPoly.part(root, LowPoly.box(Vector3(0.055, 0.14, 0.07), 0.018), INK, Vector3(0.0, -0.08, 0.12), Vector3(18, 0, 0))
	grip.name = "Grip"
	LowPoly.part(root, LowPoly.box(Vector3(0.02, 0.012, 0.09), 0.004), INK, Vector3(0.0, -0.06, 0.05))
	var magazine := Node3D.new()
	magazine.name = "magazine"
	magazine.position = Vector3(0.0, -0.05, -0.08)
	root.add_child(magazine)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.055, 0.09, 0.08), 0.014), CORAL)
	return root


func _save(model: Node3D, path: String) -> void:
	add_child(model)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(model, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	print("[test] %s: %s" % [path, error_string(error)])
	model.queue_free()
