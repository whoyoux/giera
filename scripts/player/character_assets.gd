class_name CharacterAssets
extends RefCounted
## Wczytywanie modeli postaci i broni. Serwer bez ekranu ich nie uzywa.

const CHARACTERS: Array[String] = ["Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded"]
## Paczka ma postac wysoka na 2,3 m, a kapsula gracza ma 1,8 m.
const MODEL_SCALE := 0.78
const SLEEVES: Array[Color] = [Color("5b8def"), Color("ef6f6c"), Color("2ec4b6"), Color("9b7bff"), Color("f9a03f")]


static func color_for(peer_id: int) -> Color:
	return SLEEVES[absi(hash(peer_id)) % SLEEVES.size()]


static func character_for(peer_id: int) -> Node3D:
	var character_name := CHARACTERS[absi(hash(peer_id)) % CHARACTERS.size()]
	var path := "res://assets/characters/%s.glb" % character_name
	return (load(path) as PackedScene).instantiate() as Node3D


static func skeleton_of(character: Node3D) -> Skeleton3D:
	return character.find_child("Skeleton3D", true, false) as Skeleton3D


static func player_of(character: Node3D) -> AnimationPlayer:
	return character.get_node("AnimationPlayer") as AnimationPlayer


## Chowa bronie z paczki i przygotowuje miejsce na przedmiot w prawej dloni.
static func prepare_hands(character: Node3D) -> Node3D:
	var slots: Array[Node] = [character.find_child("handslot_r", true, false), character.find_child("handslot_l", true, false)]
	for slot in slots:
		for child in slot.get_children():
			if child is MeshInstance3D:
				child.visible = false
	var holder := Node3D.new()
	holder.name = "GunHolder"
	# Bronie z paczki postaci sa skierowane w +Z kosci dloni, a blaster w -Z.
	holder.rotation_degrees = Vector3(0, 180, 0)
	holder.position = Vector3(0.0, 0.0, 0.12)
	holder.scale = Vector3.ONE * 1.25
	slots[0].add_child(holder)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.03, -0.42)
	holder.add_child(muzzle)
	return holder


## Podmienia model w uchwycie.
static func set_gun_model(holder: Node3D, path: String) -> void:
	var old := holder.get_node_or_null("Gun")
	if old != null:
		holder.remove_child(old)
		old.queue_free()
	var gun := (load(path) as PackedScene).instantiate() as Node3D
	gun.name = "Gun"
	holder.add_child(gun)
