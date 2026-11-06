extends Node
## Narzedzie: zrzut listy zabojstw z kazdym rodzajem przyczyny smierci, w trybie Battle Royale.
## Uzycie: -- --tool=res://tools/kill_feed_shot.gd --shot=C:/plik.png

const KILLS: Array[Dictionary] = [
	{ "killer": 1, "victim": 2, "weapon": { "item": &"shotgun", "tier": Rarity.Tier.LEGENDARY } },
	{ "killer": 3, "victim": 4, "weapon": { "item": &"blaster", "tier": Rarity.Tier.EPIC } },
	{ "killer": 1, "victim": 5, "weapon": { "item": &"knife" } },
	{ "killer": 3, "victim": 6, "weapon": { "item": &"grenade" } },
	{ "killer": GameState.ZONE_ATTACKER, "victim": 7, "weapon": {} },
]


func _ready() -> void:
	Net.player_name = "Kapitan"
	Net.start_server(8041, false, GameMode.Id.BATTLE_ROYALE)
	await get_tree().create_timer(1.0).timeout
	var names := ["Ziutek", "Basia", "Mietek", "Zosia", "Franek", "Dlugi Nick Na Steamie"]
	for index in names.size():
		GameState.server_add_player(index + 2, names[index])
	await get_tree().create_timer(0.3).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for kill in KILLS:
		GameState.players[kill.victim].death_weapon = kill.weapon
		GameState.kill_announced.emit(kill.killer, kill.victim)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://feed.png")
	print("[zrzut] %s" % error_string(get_viewport().get_texture().get_image().save_png(path)))
	get_tree().quit()
