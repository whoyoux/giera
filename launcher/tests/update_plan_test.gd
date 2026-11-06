extends SceneTree
## Uzycie: godot --headless --path launcher --script res://tests/update_plan_test.gd

const UpdatePlan := preload("res://scripts/update_plan.gd")
const SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _errors := 0


func _init() -> void:
	_test_manifest()
	_test_decisions()
	_test_launcher_entry()
	_test_signature()
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


func _test_launcher_entry() -> void:
	var data := _manifest()
	data.windows["launcher"] = { "file": "Giera-Windows-launcher.pck", "size": 5, "sha256": SHA, "id": "r1" }
	var entry := _read(data)
	_check("wpis launchera", entry.has("launcher"))
	var state := { "version": "1.2.0", "runtime_id": "r1" }
	_check("nowy launcher sie instaluje", UpdatePlan.decide(entry, state, "r1", true, true).launcher)
	_check("launcher na inny silnik nie instaluje sie", not UpdatePlan.decide(entry, state, "r0", true, true).launcher)
	state["launcher_sha"] = SHA
	_check("ten sam launcher nie instaluje sie", not UpdatePlan.decide(entry, state, "r1", true, true).launcher)
	data.windows.launcher.file = "../x"
	_check("zly wpis launchera odrzuca manifest", _read(data).is_empty())


func _test_signature() -> void:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var other := crypto.generate_rsa(2048)
	var data := "manifest".to_utf8_buffer()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	var signature := crypto.sign(HashingContext.HASH_SHA256, context.finish(), key)
	var pem := key.save_to_string(true)
	_check("poprawny podpis", UpdatePlan.is_signed(data, signature, pem))
	_check("zmieniona tresc", not UpdatePlan.is_signed("inny".to_utf8_buffer(), signature, pem))
	_check("inny klucz", not UpdatePlan.is_signed(data, signature, other.save_to_string(true)))
	_check("brak podpisu", not UpdatePlan.is_signed(data, PackedByteArray(), pem))
	_check("zepsuty klucz", not UpdatePlan.is_signed(data, signature, "nie klucz"))


func _check(label: String, passed: bool) -> void:
	print("[test] %s: %s" % ["OK " if passed else "BLAD", label])
	if not passed:
		_errors += 1
