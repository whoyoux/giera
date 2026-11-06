class_name UpdatePlan
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
	return { "version": version, "pack": entry.pack, "runtime": entry.runtime }


## Co zrobic, zeby z zainstalowanego stanu dojsc do wpisu z manifestu.
static func decide(entry: Dictionary, installed: Dictionary, own_runtime_id: String, has_pack: bool, has_runtime: bool) -> Dictionary:
	var version := str(entry.version)
	var rejected := str(installed.get("bad_version", "")) == version
	if rejected and has_pack and has_runtime:
		return { "runtime": Runtime.KEEP, "pack": false }
	var wanted := str(entry.runtime.id)
	var runtime := Runtime.KEEP
	if not has_runtime or str(installed.get("runtime_id", "")) != wanted:
		runtime = Runtime.COPY_SELF if own_runtime_id == wanted else Runtime.DOWNLOAD
	var pack := not has_pack or str(installed.get("version", "")) != version
	return { "runtime": runtime, "pack": pack }


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
