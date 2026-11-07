extends RefCounted
## Czyste decyzje launchera, bez plikow i sieci: czy manifest jest poprawny i co zainstalowac.

enum Runtime { KEEP, COPY_SELF, DOWNLOAD }

const SCHEMA := 1
const SAFE_NAME := "^[A-Za-z0-9._-]+$"
const SHA256_LENGTH := 64


## Zwraca wpis dla platformy z dodana wersja albo pusty slownik, gdy manifestowi nie mozna ufac.
static func read_manifest(text: String, platform: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or int(data.get("schema", 0)) != SCHEMA:
		return {}
	var version := str(data.get("version", ""))
	if not _safe(version):
		return {}
	var entry: Variant = data.get(platform)
	if not entry is Dictionary or not _valid_file(entry.get("pack")) or not _valid_file(entry.get("runtime")):
		return {}
	if str(entry.runtime.get("id", "")).is_empty():
		return {}
	var result := { "version": version, "pack": entry.pack, "runtime": entry.runtime }
	var launcher: Variant = entry.get("launcher")
	if launcher != null:
		if not _valid_file(launcher) or str(launcher.get("id", "")).is_empty():
			return {}
		result["launcher"] = launcher
	return result


## Podpis chroni graczy przed podmienionym wydaniem nawet po przejeciu konta na GitHubie.
static func is_signed(data: PackedByteArray, signature: PackedByteArray, public_pem: String) -> bool:
	var key := CryptoKey.new()
	if signature.is_empty() or key.load_from_string(public_pem, true) != OK:
		return false
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return Crypto.new().verify(HashingContext.HASH_SHA256, context.finish(), signature, key)


## Co zrobic, zeby z zainstalowanego stanu dojsc do wpisu z manifestu.
static func decide(entry: Dictionary, installed: Dictionary, own_runtime_id: String, has_pack: bool, has_runtime: bool) -> Dictionary:
	var version := str(entry.version)
	# Logika launchera jest skompilowana dla konkretnego silnika, wiec starszy jej nie uruchomi.
	var launcher: Dictionary = entry.get("launcher", {})
	var new_launcher: bool = str(launcher.get("id", "")) == own_runtime_id \
		and str(installed.get("launcher_sha", "")) != str(launcher.get("sha256", ""))
	var rejected := str(installed.get("bad_version", "")) == version
	if rejected and has_pack and has_runtime:
		return { "runtime": Runtime.KEEP, "pack": false, "launcher": new_launcher }
	var wanted := str(entry.runtime.id)
	var runtime := Runtime.KEEP
	if not has_runtime or str(installed.get("runtime_id", "")) != wanted:
		runtime = Runtime.COPY_SELF if own_runtime_id == wanted else Runtime.DOWNLOAD
	var pack := not has_pack or str(installed.get("version", "")) != version
	return { "runtime": runtime, "pack": pack, "launcher": new_launcher }


static func _valid_file(file: Variant) -> bool:
	if not file is Dictionary:
		return false
	var sha := str(file.get("sha256", ""))
	return _safe(str(file.get("file", ""))) \
		and int(file.get("size", 0)) > 0 \
		and sha.length() == SHA256_LENGTH and sha.is_valid_hex_number()


## Wartosc trafia do adresu i nazwy pliku, wiec nie moze zawierac sciezki.
static func _safe(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile(SAFE_NAME)
	return regex.search(text) != null and not text.contains("..")
