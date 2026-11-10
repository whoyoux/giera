extends Node
## Narzedzie: buduje kodem modele Desert Eagle, AWP i Uzi i zapisuje je jako .glb w assets/weapons.
## Uzycie: godot --path . --headless -- --tool=res://tools/build_weapon_models.gd [--only=deagle]
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
const SILVER := Color("c4cbd9")


func _ready() -> void:
	var only: String = Net.args.get("only", "")
	if only.is_empty() or only.split(",").has("deagle"):
		_save(_deagle(), "res://assets/weapons/deagle.glb")
	if only.is_empty() or only.split(",").has("awp"):
		_save(_awp(), "res://assets/weapons/awp.glb")
	if only.is_empty() or only.split(",").has("uzi"):
		_save(_uzi(), "res://assets/weapons/uzi.glb")
	get_tree().quit()


## Ciezki pistolet: masywny stalowy zamek z wycieciem i zlotymi akcentami, trojkatna lufa na wierzchu,
## ciemna rama, kurek, kablak i rekojesc z okladzinami. Zamek i kurek to osobne wezly "slide"
## i "hammer", wiec przy strzale moga sie cofnac, a "magazine" wypada przy przeladowaniu.
func _deagle() -> Node3D:
	var root := Node3D.new()
	root.name = "Deagle"
	# Rama: ciemny korpus pod zamkiem, prowadnica i wystajaca dolna szczeka z przodu.
	LowPoly.part(root, LowPoly.box(Vector3(0.068, 0.05, 0.26), 0.012), INK, Vector3(0.0, 0.045, -0.085))
	LowPoly.part(root, LowPoly.box(Vector3(0.062, 0.03, 0.05), 0.01), INK, Vector3(0.0, 0.035, -0.215))
	LowPoly.part(root, LowPoly.box(Vector3(0.074, 0.008, 0.2), 0.003), STEEL.darkened(0.25), Vector3(0.0, 0.072, -0.11))
	# Lufa: nieruchoma oslona z trojkatnym grzbietem, koncowka i muszka z koralowa kropka.
	LowPoly.part(root, LowPoly.box(Vector3(0.07, 0.06, 0.15), 0.012), SILVER.darkened(0.12), Vector3(0.0, 0.1, -0.225))
	var barrel := LowPoly.part(root, LowPoly.cylinder(0.03, 0.03, 0.15, 3), SILVER.darkened(0.04), Vector3(0.0, 0.127, -0.225), Vector3(90, 0, 0))
	barrel.name = "Barrel"
	LowPoly.part(root, LowPoly.cylinder(0.019, 0.019, 0.014, 10), INK, Vector3(0.0, 0.1, -0.3), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.box(Vector3(0.012, 0.022, 0.018), 0.004), INK, Vector3(0.0, 0.158, -0.275))
	LowPoly.part(root, LowPoly.box(Vector3(0.008, 0.008, 0.004), 0.002), CORAL, Vector3(0.0, 0.163, -0.265))
	# Zamek: osobny wezel, ktory przy strzale jedzie do tylu po prowadnicy.
	var slide := Node3D.new()
	slide.name = "slide"
	root.add_child(slide)
	LowPoly.part(slide, LowPoly.box(Vector3(0.08, 0.072, 0.22), 0.016), SILVER, Vector3(0.0, 0.108, -0.04))
	# Wyciecie na prawym boku zamka (okno wyrzutnika) i ciemne wnetrze.
	LowPoly.part(slide, LowPoly.box(Vector3(0.012, 0.03, 0.07), 0.004), INK, Vector3(0.037, 0.118, -0.07))
	LowPoly.part(slide, LowPoly.box(Vector3(0.006, 0.022, 0.06), 0.002), GOLD, Vector3(0.042, 0.118, -0.07))
	# Zlote pasy wzdluz bokow i ryflowanie z tylu do przeladowania.
	for side: float in [-1.0, 1.0]:
		LowPoly.part(slide, LowPoly.box(Vector3(0.004, 0.01, 0.2), 0.002), GOLD, Vector3(side * 0.041, 0.085, -0.04))
	for i in 6:
		LowPoly.part(slide, LowPoly.box(Vector3(0.084, 0.05, 0.007), 0.002), SILVER.darkened(0.3), Vector3(0.0, 0.112, 0.055 - i * 0.014))
	# Szczerbinka na tylnej krawedzi zamka.
	for side: float in [-1.0, 1.0]:
		LowPoly.part(slide, LowPoly.box(Vector3(0.016, 0.022, 0.016), 0.004), INK, Vector3(side * 0.016, 0.153, 0.05))
	LowPoly.part(slide, LowPoly.box(Vector3(0.006, 0.006, 0.004), 0.002), CORAL, Vector3(0.0, 0.15, 0.06))
	# Kurek za zamkiem: osobny wezel, ktory przy strzale opada.
	var hammer := Node3D.new()
	hammer.name = "hammer"
	hammer.position = Vector3(0.0, 0.095, 0.075)
	root.add_child(hammer)
	LowPoly.part(hammer, LowPoly.box(Vector3(0.024, 0.045, 0.018), 0.006), INK, Vector3(0.0, 0.022, 0.0), Vector3(-20, 0, 0))
	LowPoly.part(hammer, LowPoly.box(Vector3(0.028, 0.012, 0.022), 0.004), GOLD_DARK, Vector3(0.0, 0.043, 0.008), Vector3(-20, 0, 0))
	# Bezpiecznik i zaczep zamka po lewej stronie.
	LowPoly.part(root, LowPoly.box(Vector3(0.01, 0.014, 0.05), 0.003), GOLD, Vector3(-0.039, 0.062, -0.02))
	LowPoly.part(root, LowPoly.box(Vector3(0.012, 0.02, 0.02), 0.004), INK, Vector3(-0.041, 0.1, 0.06))
	# Kablak: przod z kwadratowym zagieciem, dol i spust w kolorze akcentu.
	LowPoly.part(root, LowPoly.box(Vector3(0.022, 0.012, 0.11), 0.004), INK, Vector3(0.0, -0.028, -0.045))
	LowPoly.part(root, LowPoly.box(Vector3(0.022, 0.06, 0.014), 0.004), INK, Vector3(0.0, 0.0, -0.096))
	LowPoly.part(root, LowPoly.box(Vector3(0.014, 0.036, 0.014), 0.004), GOLD, Vector3(0.0, 0.004, -0.035), Vector3(18, 0, 0))
	# Rekojesc: rama, okladziny z ciemnego drewna z jasnymi wstawkami i stalowy tyl.
	var grip := LowPoly.part(root, LowPoly.box(Vector3(0.056, 0.17, 0.08), 0.016), INK, Vector3(0.0, -0.045, 0.035), Vector3(14, 0, 0))
	grip.name = "Grip"
	for side: float in [-1.0, 1.0]:
		var panel := LowPoly.part(root, LowPoly.box(Vector3(0.008, 0.13, 0.062), 0.006), GRIP, Vector3(side * 0.031, -0.045, 0.034), Vector3(14, 0, 0))
		panel.name = "Panel%s" % ("L" if side < 0.0 else "R")
		for i in 3:
			LowPoly.part(root, LowPoly.box(Vector3(0.006, 0.006, 0.04), 0.002), GRIP.lightened(0.3), Vector3(side * 0.036, -0.005 - i * 0.032, 0.026 + i * 0.008), Vector3(14, 0, 0))
		LowPoly.part(root, LowPoly.cylinder(0.008, 0.008, 0.006, 6), GOLD, Vector3(side * 0.036, -0.045, 0.034), Vector3(0, 0, 90))
	LowPoly.part(root, LowPoly.box(Vector3(0.05, 0.15, 0.012), 0.004), STEEL, Vector3(0.0, -0.04, 0.078), Vector3(14, 0, 0))
	LowPoly.part(root, LowPoly.box(Vector3(0.05, 0.03, 0.04), 0.008), STEEL, Vector3(0.0, 0.04, 0.072))
	var magazine := Node3D.new()
	magazine.name = "magazine"
	magazine.position = Vector3(0.0, -0.12, 0.055)
	magazine.rotation_degrees = Vector3(14, 0, 0)
	root.add_child(magazine)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.048, 0.04, 0.068), 0.01), INK)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.058, 0.016, 0.084), 0.005), GOLD, Vector3(0.0, -0.025, 0.0))
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
	# Rygiel zamka po prawej stronie: osobny wezel "bolt", ktory po strzale obraca sie i cofa.
	var bolt := Node3D.new()
	bolt.name = "bolt"
	bolt.position = Vector3(0.03, 0.05, 0.1)
	root.add_child(bolt)
	LowPoly.part(bolt, LowPoly.cylinder(0.008, 0.008, 0.07, 6), STEEL, Vector3(0.03, 0.0, 0.0), Vector3(0, 0, 90))
	LowPoly.part(bolt, LowPoly.box(Vector3(0.034, 0.034, 0.034), 0.01), CORAL, Vector3(0.065, 0.0, 0.0))
	var grip := LowPoly.part(root, LowPoly.box(Vector3(0.055, 0.14, 0.07), 0.018), INK, Vector3(0.0, -0.08, 0.12), Vector3(18, 0, 0))
	grip.name = "Grip"
	LowPoly.part(root, LowPoly.box(Vector3(0.02, 0.012, 0.09), 0.004), INK, Vector3(0.0, -0.06, 0.05))
	var magazine := Node3D.new()
	magazine.name = "magazine"
	magazine.position = Vector3(0.0, -0.05, -0.08)
	root.add_child(magazine)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.055, 0.09, 0.08), 0.014), CORAL)
	return root


## Pistolet maszynowy: kanciasta komora z blachy, krotka lufa z nakretka, dlugi magazynek w rekojesci
## i zlozona kolba pod spodem. Galka napinacza na wierzchu to wezel "slide", ktory skacze przy strzale.
func _uzi() -> Node3D:
	var root := Node3D.new()
	root.name = "Uzi"
	# Komora: dluga skrzynka z jasniejsza pokrywa i zebrami po bokach.
	LowPoly.part(root, LowPoly.box(Vector3(0.07, 0.085, 0.3), 0.014), INK, Vector3(0.0, 0.07, -0.08))
	LowPoly.part(root, LowPoly.box(Vector3(0.062, 0.016, 0.28), 0.006), STEEL, Vector3(0.0, 0.118, -0.08))
	for side: float in [-1.0, 1.0]:
		for i in 4:
			LowPoly.part(root, LowPoly.box(Vector3(0.006, 0.05, 0.012), 0.002), STEEL.darkened(0.2), Vector3(side * 0.036, 0.07, -0.19 + i * 0.03))
		LowPoly.part(root, LowPoly.box(Vector3(0.005, 0.012, 0.12), 0.002), CORAL, Vector3(side * 0.036, 0.095, 0.0))
	# Lufa z nakretka i wylotem.
	var barrel := LowPoly.part(root, LowPoly.cylinder(0.02, 0.02, 0.09, 8), STEEL.darkened(0.1), Vector3(0.0, 0.075, -0.27), Vector3(90, 0, 0))
	barrel.name = "Barrel"
	LowPoly.part(root, LowPoly.cylinder(0.03, 0.03, 0.03, 8), INK, Vector3(0.0, 0.075, -0.24), Vector3(90, 0, 0))
	LowPoly.part(root, LowPoly.cylinder(0.012, 0.012, 0.006, 8), INK.darkened(0.4), Vector3(0.0, 0.075, -0.316), Vector3(90, 0, 0))
	# Przyrzady: muszka w oslonie z przodu i szczerbinka z tylu.
	for side: float in [-1.0, 1.0]:
		LowPoly.part(root, LowPoly.box(Vector3(0.008, 0.03, 0.02), 0.003), INK, Vector3(side * 0.016, 0.138, -0.2))
		LowPoly.part(root, LowPoly.box(Vector3(0.008, 0.026, 0.016), 0.003), INK, Vector3(side * 0.016, 0.136, 0.045))
	LowPoly.part(root, LowPoly.box(Vector3(0.006, 0.018, 0.006), 0.002), CORAL, Vector3(0.0, 0.134, -0.2))
	# Galka napinacza: osobny wezel, zeby przy strzale mogla skoczyc do tylu.
	var slide := Node3D.new()
	slide.name = "slide"
	root.add_child(slide)
	LowPoly.part(slide, LowPoly.box(Vector3(0.03, 0.02, 0.04), 0.006), GOLD, Vector3(0.0, 0.136, -0.1))
	# Rekojesc na srodku, kablak i spust.
	var grip := LowPoly.part(root, LowPoly.box(Vector3(0.056, 0.15, 0.07), 0.014), GRIP, Vector3(0.0, -0.045, 0.0), Vector3(8, 0, 0))
	grip.name = "Grip"
	LowPoly.part(root, LowPoly.box(Vector3(0.012, 0.012, 0.1), 0.004), INK, Vector3(0.0, -0.035, -0.085))
	LowPoly.part(root, LowPoly.box(Vector3(0.012, 0.05, 0.012), 0.004), INK, Vector3(0.0, -0.01, -0.13))
	LowPoly.part(root, LowPoly.box(Vector3(0.01, 0.03, 0.012), 0.003), GOLD, Vector3(0.0, 0.0, -0.06), Vector3(-15, 0, 0))
	# Zlozona kolba: dwa prety pod komora i stopka z tylu.
	for side: float in [-1.0, 1.0]:
		LowPoly.part(root, LowPoly.box(Vector3(0.008, 0.01, 0.16), 0.003), STEEL.darkened(0.25), Vector3(side * 0.03, 0.03, 0.12))
	LowPoly.part(root, LowPoly.box(Vector3(0.07, 0.06, 0.014), 0.005), STEEL.darkened(0.25), Vector3(0.0, 0.05, 0.2))
	# Dlugi magazynek wystaje z rekojesci i wypada przy przeladowaniu.
	var magazine := Node3D.new()
	magazine.name = "magazine"
	magazine.position = Vector3(0.0, -0.17, 0.012)
	magazine.rotation_degrees = Vector3(8, 0, 0)
	root.add_child(magazine)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.04, 0.14, 0.05), 0.008), STEEL)
	LowPoly.part(magazine, LowPoly.box(Vector3(0.046, 0.014, 0.056), 0.004), CORAL, Vector3(0.0, -0.07, 0.0))
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
