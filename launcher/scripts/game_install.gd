class_name GameInstall
extends RefCounted
## Pliki gry w danych uzytkownika. Launcher nie zapisuje nic w swoim folderze,
## bo na macOS aplikacja moze dzialac z miejsca tylko do odczytu.
##
## Oficjalne szablony Godota szukaja PCK obok exe pod ta sama nazwa i nie maja --main-pack,
## wiec gra ma wlasna kopie silnika.

const GAME_NAME := "GieraGame"
const STATE_FILE := "installed.json"
const MARKER_FILE := "started.txt"
const CHUNK_SIZE := 1 << 20

var dir: String
var state := {}


func _init(game_dir: String) -> void:
	dir = game_dir
	DirAccess.make_dir_recursive_absolute(dir)
	_recover()
	var text := FileAccess.get_file_as_string(_path(STATE_FILE))
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if data is Dictionary:
		state = data


func exe_path() -> String:
	return _path(GAME_NAME + (".exe" if OS.has_feature("windows") else ""))


func pack_path() -> String:
	return _path(GAME_NAME + ".pck")


func marker_path() -> String:
	return _path(MARKER_FILE)


func temp_path(name: String) -> String:
	return _path(name + ".tmp")


func has_pack() -> bool:
	return FileAccess.file_exists(pack_path())


func has_runtime() -> bool:
	return FileAccess.file_exists(exe_path())


func is_playable() -> bool:
	return has_pack() and has_runtime()


func save_state() -> void:
	var temp := temp_path(STATE_FILE)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	_replace(temp, _path(STATE_FILE))


## Podmienia PCK. Stary plik zostaje, dopoki nowa wersja nie uruchomi sie poprawnie.
func install_pack(temp: String, version: String) -> bool:
	var previous := pack_path() + ".prev"
	if has_pack() and not _replace(pack_path(), previous):
		return false
	if not _replace(temp, pack_path()):
		if FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, pack_path())
		return false
	state["previous_version"] = state.get("version", "")
	state["version"] = version
	save_state()
	return true


## Wraca do poprzedniego PCK i zapamietuje zla wersje, zeby nie pobierac jej w kolko.
func roll_back() -> bool:
	var previous := pack_path() + ".prev"
	if not FileAccess.file_exists(previous) or not _replace(previous, pack_path()):
		return false
	state["bad_version"] = state.get("version", "")
	state["version"] = state.get("previous_version", "")
	save_state()
	return true


## Pierwsza instalacja bez pobierania: launcher ma ten sam silnik co gra.
func copy_runtime_from_self(runtime_id: String) -> bool:
	var source := OS.get_executable_path()
	if not _copy(source, exe_path()):
		return false
	for file in DirAccess.get_files_at(source.get_base_dir()):
		if file.get_extension().to_lower() == "dll" and not _copy(source.get_base_dir().path_join(file), _path(file)):
			return false
	_mark_runtime(runtime_id)
	return true


## Rozpakowuje silnik i biblioteki do plikow tymczasowych, a potem je podmienia.
func install_runtime(zip_path: String, runtime_id: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	var done: Array[Array] = []
	var ok := true
	for name in zip.get_files():
		if name.contains("/") or name.contains("\\") or name.contains(".."):
			ok = false
			break
		var temp := temp_path("runtime-" + name)
		var file := FileAccess.open(temp, FileAccess.WRITE)
		if file == null:
			ok = false
			break
		file.store_buffer(zip.read_file(name))
		file.close()
		var is_engine := name == "Giera" or name == "Giera.exe"
		done.append([temp, exe_path() if is_engine else _path(name)])
	zip.close()
	if ok:
		for pair in done:
			if not _replace(pair[0], pair[1]):
				ok = false
				break
	for pair in done:
		if FileAccess.file_exists(pair[0]):
			DirAccess.remove_absolute(pair[0])
	if not ok or not has_runtime():
		return false
	_mark_runtime(runtime_id)
	return true


## Pytamy system, bo Godot zna tylko procesy uruchomione przez siebie w tym samym przebiegu.
func is_game_running() -> bool:
	var output: Array = []
	if OS.has_feature("windows"):
		var exe := exe_path().get_file()
		OS.execute("tasklist", ["/FI", "IMAGENAME eq " + exe, "/NH"], output)
		return not output.is_empty() and str(output[0]).to_lower().contains(exe.to_lower())
	return OS.execute("/usr/bin/pgrep", ["-x", GAME_NAME], output) == 0


func start_game(args: PackedStringArray) -> int:
	if FileAccess.file_exists(marker_path()):
		DirAccess.remove_absolute(marker_path())
	return OS.create_process(exe_path(), args)


## Suma pliku. Oddaje klatke co kawalek, zeby okno nie stanelo przy duzym pliku.
static func sha256(path: String, tree: SceneTree) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(CHUNK_SIZE))
		await tree.process_frame
	# Otwarty plik zablokowalby na Windows jego podmiane.
	file.close()
	return context.finish().hex_encode()


func _mark_runtime(runtime_id: String) -> void:
	FileAccess.set_unix_permissions(exe_path(), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	state["runtime_id"] = runtime_id
	save_state()


## Awaria miedzy dwiema zmianami nazwy nie moze zostawic gry bez PCK.
func _recover() -> void:
	var previous := pack_path() + ".prev"
	if not has_pack() and FileAccess.file_exists(previous):
		DirAccess.rename_absolute(previous, pack_path())


func _replace(from: String, to: String) -> bool:
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(to) != OK:
		return false
	return DirAccess.rename_absolute(from, to) == OK


## Kopia bajt po bajcie, bo na macOS kwarantanna przechodzi na kopie z atrybutami.
func _copy(from: String, to: String) -> bool:
	var source := FileAccess.open(from, FileAccess.READ)
	var target := FileAccess.open(to, FileAccess.WRITE)
	if source == null or target == null:
		return false
	while source.get_position() < source.get_length():
		target.store_buffer(source.get_buffer(CHUNK_SIZE))
	var ok := target.get_error() == OK
	target.close()
	return ok


func _path(name: String) -> String:
	return dir.path_join(name)
