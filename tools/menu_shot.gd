extends Node
## Narzedzie: zrzut menu glownego, np. do sprawdzenia kart trybow. Uzycie: -- --tool=res://tools/menu_shot.gd --shot=C:/plik.png


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var path: String = Net.args.get("shot", "user://menu.png")
	print("[zrzut] %s" % error_string(get_viewport().get_texture().get_image().save_png(path)))
	get_tree().quit()
