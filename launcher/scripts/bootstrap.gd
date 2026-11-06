extends Node
## Niezmienny poczatek launchera: ten plik zostaje w exe na zawsze, a reszta moze sie aktualizowac.
## Zmiana tutaj dotrze tylko do graczy, ktorzy pobiora nowy ZIP.
##
## Montuje nowa logike z folderu gry. Gdy poprzedni przebieg nie doszedl do uruchomienia gry,
## uznaje ja za zepsuta i wraca do wersji wbudowanej w launcher.

const MAIN_SCENE := "res://launcher_main.tscn"
const PACK := "launcher.pck"
const NEW_PACK := "launcher.pck.new"
const BOOT_FLAG := "launcher.boot"


func _ready() -> void:
	var dir := OS.get_user_data_dir().path_join("game")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game-dir="):
			dir = arg.trim_prefix("--game-dir=")
	_mount(dir)
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


func _mount(dir: String) -> void:
	var pack := dir.path_join(PACK)
	var flag := dir.path_join(BOOT_FLAG)
	if FileAccess.file_exists(dir.path_join(NEW_PACK)):
		_remove(pack)
		_remove(flag)
		DirAccess.rename_absolute(dir.path_join(NEW_PACK), pack)
	if not FileAccess.file_exists(pack):
		return
	if FileAccess.file_exists(flag):
		print("[launcher] nowa logika nie zadzialala, wracam do wbudowanej")
		_remove(pack)
		_remove(flag)
		return
	var file := FileAccess.open(flag, FileAccess.WRITE)
	if file != null:
		file.close()
	if ProjectSettings.load_resource_pack(pack):
		print("[launcher] nowa logika")
	else:
		print("[launcher] nowej logiki nie da sie wczytac")
		_remove(pack)
		_remove(flag)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
