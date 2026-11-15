class_name CharacterAssets
extends RefCounted
## Wczytywanie modeli postaci i broni. Serwer bez ekranu ich nie uzywa.

## Lista postaci do wyboru. "id" idzie przez siec, wiec nie zmieniaj go po wydaniu gry.
## Nazwy mowia o roli, a nie o klasie z bajki. Rekaw to kolor munduru w widoku z pierwszej osoby.
const ROSTER: Array[Dictionary] = [
	{ "id": "knight", "name": "Szturmowiec", "file": "Knight", "sleeve": Color("3d5476") },
	{ "id": "barbarian", "name": "Ciężki", "file": "Barbarian", "sleeve": Color("7a3a2e") },
	{ "id": "mage", "name": "Technik", "file": "Mage", "sleeve": Color("4f3a5c") },
	{ "id": "rogue", "name": "Zwiadowca", "file": "Rogue", "sleeve": Color("3f5a3a") },
	{ "id": "rogue_hooded", "name": "Snajper", "file": "Rogue_Hooded", "sleeve": Color("5e4e36") },
	{ "id": "skeleton_warrior", "name": "Kościej", "file": "Skeleton_Warrior", "sleeve": BONE, "bare_rig": true },
	{ "id": "skeleton_rogue", "name": "Kościej zwiadowca", "file": "Skeleton_Rogue", "sleeve": BONE, "bare_rig": true },
	{ "id": "skeleton_mage", "name": "Kościej technik", "file": "Skeleton_Mage", "sleeve": BONE, "bare_rig": true },
	{ "id": "skeleton_minion", "name": "Kościej rekrut", "file": "Skeleton_Minion", "sleeve": BONE, "bare_rig": true },
]
const BONE := Color("bdb6a4")
## Fantastyczne dodatki z paczki, ktore gra chowa: kapelusze, rogi, hełm z kolcami, peleryny
## i płaszcze. Sprawdzane po poczatku nazwy siatki.
const HIDDEN_PARTS: Array[String] = ["Mage_Hat", "Barbarian_Hat", "Skeleton_Warrior_Helmet", "Skeleton_Mage_Hat"]
const HIDDEN_SUFFIXES: Array[String] = ["_Cape", "_Cloak"]
## Szkielety nie maja wlasnych animacji, ale ich kosci nazywaja sie tak samo jak u tej postaci.
const ANIMATION_SOURCE := "res://assets/characters/Knight.glb"
## Paczka ma postac wysoka na 2,3 m, a kapsula gracza ma 1,8 m.
const MODEL_SCALE := 0.78
## Punkt uchwytu, w ktorym dlon postaci i rekawica trzymaja kazda bron.
const HAND_POINT := Vector3(0.0, -0.17, 0.11)

static var _shared_animations: AnimationLibrary


static func index_of(id: String) -> int:
	for index in ROSTER.size():
		if ROSTER[index].id == id:
			return index
	return -1


## Poprawna postac gracza. Bez wyboru, np. u bota, wynika ona z numeru gracza.
static func resolve(id: String, peer_id: int) -> String:
	return id if index_of(id) >= 0 else ROSTER[absi(hash(peer_id)) % ROSTER.size()].id


static func sleeve_of(id: String) -> Color:
	return ROSTER[maxi(index_of(id), 0)].sleeve


static func character_for(id: String) -> Node3D:
	var entry: Dictionary = ROSTER[maxi(index_of(id), 0)]
	var character := (load("res://assets/characters/%s.glb" % entry.file) as PackedScene).instantiate() as Node3D
	if entry.get("bare_rig", false):
		_equip_bare_rig(character)
	_hide_fantasy_parts(character)
	return character


## Chowa kapelusze, rogi, peleryny i podobne dodatki, ktore nie pasuja do strzelanki.
static func _hide_fantasy_parts(character: Node3D) -> void:
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var part := String(node.name)
		if part in HIDDEN_PARTS or HIDDEN_SUFFIXES.any(func(suffix: String) -> bool: return part.ends_with(suffix)):
			(node as MeshInstance3D).visible = false


## Szkielety to sam model, wiec dostaja wspolne animacje i miejsca na bron w dloniach.
static func _equip_bare_rig(character: Node3D) -> void:
	character.get_node("Rig_Medium").name = "Rig"
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library(&"", _bare_rig_animations(skeleton_of(character)))
	character.add_child(player)
	for side: String in ["r", "l"]:
		var slot := BoneAttachment3D.new()
		slot.name = "handslot_" + side
		slot.bone_name = "handslot." + side
		skeleton_of(character).add_child(slot)


## Animacje bez torow dla kosci pomocniczych, ktorych nie ma w tych modelach.
static func _bare_rig_animations(skeleton: Skeleton3D) -> AnimationLibrary:
	if _shared_animations != null:
		return _shared_animations
	var source := (load(ANIMATION_SOURCE) as PackedScene).instantiate()
	var library := source.get_node("AnimationPlayer").get_animation_library(&"").duplicate(true) as AnimationLibrary
	source.free()
	for clip in library.get_animation_list():
		var animation := library.get_animation(clip)
		for track in range(animation.get_track_count() - 1, -1, -1):
			if skeleton.find_bone(animation.track_get_path(track).get_concatenated_subnames()) < 0:
				animation.remove_track(track)
	_shared_animations = library
	return library


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


## Podmienia model w uchwycie tak, zeby jego rekojesc trafila w dlon.
static func set_gun_model(holder: Node3D, visual: ItemVisual) -> void:
	var old := holder.get_node_or_null("Gun")
	if old != null:
		holder.remove_child(old)
		old.queue_free()
	var gun := (load(visual.model_path) as PackedScene).instantiate() as Node3D
	gun.name = "Gun"
	gun.scale = Vector3.ONE * visual.model_scale
	gun.position = HAND_POINT - visual.grip * visual.model_scale
	holder.add_child(gun)
	(holder.get_node("Muzzle") as Node3D).position = HAND_POINT + (visual.muzzle - visual.grip) * visual.model_scale
