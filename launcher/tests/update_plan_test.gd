extends SceneTree
## Uzycie: godot --headless --path launcher --script res://tests/update_plan_test.gd

const SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _errors := 0


func _init() -> void:
	_test_manifest()
	_test_decisions()
	print("[test] %s" % ("BLEDY: %d" % _errors if _errors > 0 else "wszystko OK"))
	quit(1 if _errors > 0 else 0)


func _manifest(overrides := {}) -> Dictionary:
	var data := {
		"schema": 1, "version": "1.2.0",
		"windows": {
			"pack": { "file": "Giera-Windows.pck", "size": 10, "sha256": SHA },
			"runtime": { "file": "Giera-Windows-runtime.zip", "size": 20, "sha256": SHA, "id": "r1" },
		},
	}
	data.merge(overrides, true)
	return data


func _read(data: Dictionary) -> Dictionary:
	return UpdatePlan.read_manifest(JSON.stringify(data), "windows")


func _test_manifest() -> void:
	_check("poprawny manifest", _read(_manifest()).get("version") == "1.2.0")
	_check("wersja probna", _read(_manifest({ "version": "1.2.0-rc1" })).get("version") == "1.2.0-rc1")
	_check("nie JSON", UpdatePlan.read_manifest("<html>", "windows").is_empty())
	_check("nowszy schemat", _read(_manifest({ "schema": 2 })).is_empty())
	_check("brak platformy", UpdatePlan.read_manifest(JSON.stringify(_manifest()), "macos").is_empty())
	_check("wersja ze sciezka", _read(_manifest({ "version": "../../x" })).is_empty())
	var bad_name := _manifest()
	bad_name.windows.pack.file = "../../evil.pck"
	_check("nazwa pliku ze sciezka", _read(bad_name).is_empty())
	var bad_sha := _manifest()
	bad_sha.windows.pack.sha256 = "zz"
	_check("zla suma", _read(bad_sha).is_empty())
	var bad_size := _manifest()
	bad_size.windows.pack.size = 0
	_check("zerowy rozmiar", _read(bad_size).is_empty())
	var no_id := _manifest()
	no_id.windows.runtime.erase("id")
	_check("runtime bez identyfikatora", _read(no_id).is_empty())


func _test_decisions() -> void:
	var entry := _read(_manifest())
	var current := { "version": "1.2.0", "runtime_id": "r1" }
	var plan := UpdatePlan.decide(entry, {}, "r1", false, false)
	_check("pierwsza instalacja kopiuje silnik", plan.runtime == UpdatePlan.Runtime.COPY_SELF and plan.pack)
	plan = UpdatePlan.decide(entry, {}, "inny", false, false)
	_check("stary launcher pobiera silnik", plan.runtime == UpdatePlan.Runtime.DOWNLOAD and plan.pack)
	plan = UpdatePlan.decide(entry, current, "r1", true, true)
	_check("aktualna wersja nic nie robi", plan.runtime == UpdatePlan.Runtime.KEEP and not plan.pack)
	plan = UpdatePlan.decide(entry, { "version": "1.1.0", "runtime_id": "r1" }, "r1", true, true)
	_check("nowa wersja pobiera sam PCK", plan.runtime == UpdatePlan.Runtime.KEEP and plan.pack)
	plan = UpdatePlan.decide(entry, { "version": "1.3.0", "runtime_id": "r1" }, "r1", true, true)
	_check("wycofane wydanie tez sie instaluje", plan.pack)
	plan = UpdatePlan.decide(entry, { "version": "1.1.0", "runtime_id": "r0" }, "r0", true, true)
	_check("nowy silnik pobiera sie mimo starego launchera", plan.runtime == UpdatePlan.Runtime.DOWNLOAD)
	plan = UpdatePlan.decide(entry, current, "r1", false, true)
	_check("brak PCK pobiera PCK", plan.pack)
	plan = UpdatePlan.decide(entry, current, "r1", true, false)
	_check("brak silnika go odtwarza", plan.runtime == UpdatePlan.Runtime.COPY_SELF)
	plan = UpdatePlan.decide(entry, { "version": "1.1.0", "runtime_id": "r1", "bad_version": "1.2.0" }, "r1", true, true)
	_check("zla wersja nie instaluje sie ponownie", plan.runtime == UpdatePlan.Runtime.KEEP and not plan.pack)
	plan = UpdatePlan.decide(entry, { "version": "1.1.0", "runtime_id": "r1", "bad_version": "1.0.0" }, "r1", true, true)
	_check("nowsza wersja po zlej instaluje sie", plan.pack)


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_errors += 1
