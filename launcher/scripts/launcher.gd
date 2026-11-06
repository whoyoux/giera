extends Control
## Sprawdza nowa wersje na GitHub Releases, instaluje ja i uruchamia gre.
## Jesli gra jest juz na dysku, zaden blad aktualizacji jej nie blokuje.
##
## Parametry po "--" w linii polecen. Pozostale trafiaja do gry:
##   --no-update             bez sprawdzania aktualizacji
##   --update-tag=v1.0.0-rc1 konkretne wydanie zamiast najnowszego, np. wersja probna
##   --wait-for-game         najpierw czeka na zamkniecie gry, gdy uruchomila go gra
##   --update-base=URL       inny adres wydan, do testow
##   --update-key=PLIK       inny klucz publiczny, do testow
##   --game-dir=SCIEZKA      inny folder gry, do testow

const UpdatePlan := preload("res://scripts/update_plan.gd")
const GameInstall := preload("res://scripts/game_install.gd")
const Downloader := preload("res://scripts/downloader.gd")
const UpdateKey := preload("res://scripts/update_key.gd")
const RELEASES := "https://github.com/whoyoux/giera/releases/"
const MANIFEST_TIMEOUT := 5.0
const GAME_EXIT_TIMEOUT := 15.0
## Tyle nowa wersja ma na zgloszenie startu. Wolny komputer tez musi zdazyc skompilowac shadery.
const START_TIMEOUT := 60.0
const START_POLL := 0.25
const LOCK_PORT := 47731
const SPACE_MARGIN := 1 << 24
const BYTES_IN_MB := 1048576.0
const PAPER := Color("fff8ec")
const INK := Color("2b2a3a")
const CORAL := Color("f26d6d")
const TEAL := Color("2bc4b6")

var _base := RELEASES
var _tag := ""
var _no_update := false
var _wait_for_game := false
var _public_key: String = UpdateKey.PUBLIC_PEM
var _game_dir := ""
var _game_args := PackedStringArray()
var _headless := false
var _lock := TCPServer.new()
var _install: GameInstall
var _downloader: Downloader
var _status: Label
var _bar: ProgressBar
var _buttons: HBoxContainer
var _play_button: Button
var _download_label := ""


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_read_args()
	_build_ui()
	_downloader = Downloader.new()
	_downloader.progress.connect(_on_progress)
	add_child(_downloader)
	# Drugi launcher nie moze pobierac do tych samych plikow.
	if _lock.listen(LOCK_PORT, "127.0.0.1") != OK:
		print("[launcher] juz dziala")
		get_tree().quit()
		return
	_install = GameInstall.new(_game_dir)
	_run()


func _read_args() -> void:
	_game_dir = OS.get_user_data_dir().path_join("game")
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-update":
			_no_update = true
		elif arg == "--wait-for-game":
			_wait_for_game = true
		elif arg.begins_with("--update-key="):
			_public_key = FileAccess.get_file_as_string(arg.trim_prefix("--update-key="))
		elif arg.begins_with("--update-tag="):
			_tag = arg.trim_prefix("--update-tag=")
		elif arg.begins_with("--update-base="):
			_base = arg.trim_prefix("--update-base=").trim_suffix("/") + "/"
		elif arg.begins_with("--game-dir="):
			_game_dir = arg.trim_prefix("--game-dir=")
		else:
			_game_args.append(arg)


func _run() -> void:
	_buttons.visible = false
	var failure := ""
	var updated := false
	if _wait_for_game:
		_wait_for_game = false
		_show("Czekam na zamknięcie gry…")
		var left := GAME_EXIT_TIMEOUT
		while left > 0.0 and _install.is_game_running():
			await get_tree().create_timer(START_POLL).timeout
			left -= START_POLL
	# Gra czyta PCK przez caly czas dzialania, wiec nie wolno go podmieniac pod dzialajaca gra.
	if not _no_update and not _install.is_game_running():
		_show("Sprawdzam aktualizacje…")
		var entry := await _fetch_entry()
		if not entry.is_empty():
			print("[launcher] najnowsza wersja: %s, zainstalowana: %s" % [entry.version, _install.state.get("version", "brak")])
			var result := await _update(entry)
			failure = result.failure
			updated = result.updated
		elif not _install.is_playable():
			failure = "Nie udało się połączyć z serwerem aktualizacji."
	elif not _install.is_playable():
		failure = "Gra nie jest zainstalowana."
	else:
		print("[launcher] bez aktualizacji")
	if failure.is_empty():
		_play(updated)
	else:
		_show_failure(failure)


func _fetch_entry() -> Dictionary:
	var platform := "windows" if OS.has_feature("windows") else "macos" if OS.has_feature("macos") else ""
	if platform.is_empty():
		return {}
	var data := await _downloader.fetch_bytes(_manifest_url(), MANIFEST_TIMEOUT)
	if data.is_empty():
		return {}
	var signature := await _downloader.fetch_bytes(_manifest_url() + ".sig", MANIFEST_TIMEOUT)
	if not UpdatePlan.is_signed(data, signature, _public_key):
		print("[launcher] manifest bez poprawnego podpisu, pomijam aktualizacje")
		return {}
	return UpdatePlan.read_manifest(data.get_string_from_utf8(), platform)


func _manifest_url() -> String:
	var folder := "download/%s/" % _tag if not _tag.is_empty() else "latest/download/"
	return _base + folder + "manifest.json"


## Instaluje to, czego brakuje. Blad nie cofa tego, co juz sie udalo.
func _update(entry: Dictionary) -> Dictionary:
	var own_id := str(ProjectSettings.get_setting("giera/runtime_id", "dev"))
	var plan := UpdatePlan.decide(entry, _install.state, own_id, _install.has_pack(), _install.has_runtime())
	var tag: String = _tag if not _tag.is_empty() else "v" + str(entry.version)
	if not _has_space_for(entry, plan):
		return _outcome("Za mało miejsca na dysku.")

	if plan.launcher:
		await _update_launcher(tag, entry.launcher)
	if plan.runtime == UpdatePlan.Runtime.COPY_SELF:
		_show("Przygotowuję grę…")
		await get_tree().process_frame
		if not _install.copy_runtime_from_self(own_id):
			return _outcome("Nie udało się skopiować plików gry.")
	elif plan.runtime == UpdatePlan.Runtime.DOWNLOAD:
		_download_label = "Pobieram silnik gry"
		var archive := await _download(tag, entry.runtime)
		if archive.is_empty():
			return _outcome("Nie udało się pobrać silnika gry.")
		_show("Instaluję…")
		await get_tree().process_frame
		var unpacked := _install.install_runtime(archive, str(entry.runtime.id))
		DirAccess.remove_absolute(archive)
		if not unpacked:
			return _outcome("Nie udało się zaktualizować silnika. Zamknij grę i spróbuj ponownie.")

	if not plan.pack:
		return _outcome("")
	_download_label = "Pobieram wersję %s" % entry.version
	var pack := await _download(tag, entry.pack)
	if pack.is_empty():
		return _outcome("Nie udało się pobrać aktualizacji.")
	_show("Instaluję…")
	if not _install.install_pack(pack, str(entry.version)):
		DirAccess.remove_absolute(pack)
		return _outcome("Nie udało się zaktualizować. Zamknij grę i spróbuj ponownie.")
	return _outcome("", true)


## Blad launchera nie moze zatrzymac gry, a nowa logika ma jeszcze szanse przy nastepnym starcie.
func _update_launcher(tag: String, file: Dictionary) -> void:
	_download_label = "Pobieram launcher"
	var temp := await _download(tag, file)
	if not temp.is_empty() and not _install.stage_launcher(temp, str(file.sha256)):
		DirAccess.remove_absolute(temp)


func _outcome(failure: String, updated := false) -> Dictionary:
	return { "failure": failure, "updated": updated }


## Rozpakowany silnik zajmuje kilka razy wiecej niz archiwum.
func _has_space_for(entry: Dictionary, plan: Dictionary) -> bool:
	var needed := int(entry.pack.size) if plan.pack else 0
	if plan.runtime != UpdatePlan.Runtime.KEEP:
		needed += int(entry.runtime.size) * 4
	var folder := DirAccess.open(_install.dir)
	return needed == 0 or folder == null or folder.get_space_left() >= needed + SPACE_MARGIN


## Zwraca plik tymczasowy tylko wtedy, gdy rozmiar i suma zgadzaja sie z manifestem.
func _download(tag: String, file: Dictionary) -> String:
	var temp := _install.temp_path(str(file.file))
	_show(_download_label + "…", true)
	var ok := await _downloader.fetch_file(_base + "download/%s/%s" % [tag, file.file], temp, int(file.size))
	if ok:
		_show("Sprawdzam pobrany plik…")
		var sum: String = await GameInstall.sha256(temp, get_tree())
		ok = FileAccess.get_size(temp) == int(file.size) and sum == str(file.sha256)
		if not ok:
			print("[launcher] plik sie nie zgadza: rozmiar %d, suma %s" % [FileAccess.get_size(temp), sum])
	if not ok:
		print("[launcher] pobieranie nieudane: %s" % file.file)
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)
		return ""
	return temp


func _play(just_updated: bool) -> void:
	_install.confirm_launcher()
	_buttons.visible = false
	_show("Uruchamiam grę…")
	var pid := _start_game()
	if pid == -1:
		print("[launcher] nie udalo sie uruchomic gry")
		if _headless:
			get_tree().quit(1)
			return
		_show("Nie udało się uruchomić gry.")
		_buttons.visible = true
		return
	if just_updated:
		if not _headless:
			get_window().mode = Window.MODE_MINIMIZED
		if not await _started_properly(pid):
			if OS.is_process_running(pid):
				OS.kill(pid)
			if _install.roll_back():
				print("[launcher] nowa wersja nie dziala, wracam do poprzedniej")
				_start_game()
	get_tree().quit()


func _start_game() -> int:
	var args := PackedStringArray()
	if _headless:
		args.append("--headless")
	args.append("--")
	args.append("--launcher-marker=" + _install.marker_path())
	args.append("--launcher-path=" + OS.get_executable_path())
	args.append("--update-manifest=" + _manifest_url())
	args.append_array(_game_args)
	var pid := _install.start_game(args)
	print("[launcher] gra uruchomiona, pid %d" % pid)
	return pid


## Sam dzialajacy proces niczego nie dowodzi, bo zepsuty PCK moze czekac na okienku z bledem.
func _started_properly(pid: int) -> bool:
	var left := START_TIMEOUT
	while left > 0.0:
		await get_tree().create_timer(START_POLL).timeout
		left -= START_POLL
		if FileAccess.file_exists(_install.marker_path()):
			return true
		if not OS.is_process_running(pid):
			return false
	return false


func _show_failure(message: String) -> void:
	_install.confirm_launcher()
	print("[launcher] %s" % message)
	_show(message)
	if _headless:
		if _install.is_playable():
			_play(false)
		else:
			get_tree().quit(1)
		return
	_buttons.visible = true
	_play_button.visible = _install.is_playable()


func _show(message: String, with_bar := false) -> void:
	_status.text = message
	_bar.visible = with_bar
	_bar.value = 0.0


func _on_progress(done: int, total: int) -> void:
	_bar.value = float(done) / max(total, 1)
	_status.text = "%s… %.1f / %.1f MB" % [_download_label, done / BYTES_IN_MB, total / BYTES_IN_MB]


func _build_ui() -> void:
	var font := load("res://assets/Fredoka.ttf") as Font
	var background := ColorRect.new()
	background.color = PAPER
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(_label("GIERA", 44, CORAL, font))
	_status = _label("", 19, INK, font)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.add_theme_stylebox_override("background", _box(INK.lerp(PAPER, 0.8)))
	_bar.add_theme_stylebox_override("fill", _box(TEAL))
	_bar.visible = false
	column.add_child(_bar)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.visible = false
	column.add_child(_buttons)
	var retry := _button("Spróbuj ponownie", TEAL, font)
	retry.pressed.connect(_run)
	_buttons.add_child(retry)
	_play_button = _button("Graj mimo to", CORAL, font)
	_play_button.pressed.connect(_play.bind(false))
	_buttons.add_child(_play_button)


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func _button(text: String, color: Color, font: Font) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	for look in ["normal", "hover", "pressed", "focus"]:
		var box := _box(color.lightened(0.08) if look == "hover" else color)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		node.add_theme_stylebox_override(look, box)
	return node


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	return box
