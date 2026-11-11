extends Node
## Test dzwiekow otoczenia: kazdy generator z AmbienceSfx daje slyszalny dzwiek bez przesterowania,
## a na mapie petle zaczynaja grac po policzeniu w watku i suwak je wycisza.
## Uzycie (z oknem, bo bez okna mapy nie maja dzwiekow): godot --path . -- --map=desert --tool=res://tools/ambience_sounds_test.gd
##         Z --wav-dir=C:/folder zapisuje kazdy dzwiek do pliku WAV do odsluchania.

const PORT := 8177
const MAKERS := {
	"desert_wind": "petla", "canyon_howl": "petla", "forest_wind": "petla", "valley_wind": "petla",
	"city_bed": "petla", "sand_hiss": "petla", "palm_rustle": "petla", "oasis_water": "petla",
	"fountain": "petla", "lake_lap": "petla", "cicadas": "petla", "tumbleweed_rustle": "petla",
	"sign_creak": "", "tower_creak": "", "rope_creak": "", "wood_creak": "", "tin_clank": "",
	"wood_knock": "", "canvas_flap": "", "train_whistle": "", "hawk_cry": "",
}

var _failures := 0


func _ready() -> void:
	var wav_dir: String = Net.args.get("wav-dir", "")
	var total_ms := 0
	for maker: String in MAKERS:
		var started := Time.get_ticks_msec()
		var stream := Callable(AmbienceSfx, maker).call() as AudioStreamWAV
		var took := Time.get_ticks_msec() - started
		total_ms += took
		var peak := 0
		var energy := 0.0
		var count := stream.data.size() / 2
		for i in count:
			var sample := stream.data.decode_s16(i * 2)
			peak = maxi(peak, absi(sample))
			energy += float(sample) * sample
		var rms := sqrt(energy / count)
		var looped: bool = MAKERS[maker] == "petla"
		print("[test] %-18s %.1f s, szczyt %5d, srednio %5d, liczenie %4d ms" % [maker, stream.get_length(), peak, roundi(rms), took])
		_check("%s slychac" % maker, rms > 300.0)
		_check("%s bez przesterowania" % maker, peak < 32000)
		_check("%s: petla ustawiona" % maker, (stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == looped)
		if not wav_dir.is_empty():
			stream.save_to_wav(wav_dir.path_join(maker + ".wav"))
	print("[test] liczenie wszystkich dzwiekow: %d ms" % total_ms)

	_check("host startuje", Net.start_server(PORT).is_empty())
	await get_tree().create_timer(1.0).timeout
	var found := get_node("/root/Main/World").find_children("*", "MapSounds", true, false)
	_check("mapa ma dzwieki otoczenia", not found.is_empty())
	if not found.is_empty():
		var sounds := found[0] as MapSounds
		var waited := 0.0
		while waited < 20.0 and not sounds._loops.all(func(entry: Dictionary) -> bool: return entry.player.playing):
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		print("[test] petle graja po %.2f s (%d petli, %d grup odglosow)" % [waited, sounds._loops.size(), sounds._events.size()])
		_check("wszystkie petle graja", sounds._loops.all(func(entry: Dictionary) -> bool: return entry.player.playing))
		_check("odglosy maja dzwieki", sounds._events.all(func(entry: Dictionary) -> bool: return entry.streams.size() == entry.makers.size()))
		await get_tree().create_timer(2.5).timeout
		_check("tlo doszlo do glosnosci", sounds._loops[0].player.volume_db > MapSounds.SILENT_DB + 20.0)
		Settings.set_value("ambience", 0.0)
		await get_tree().create_timer(0.2).timeout
		_check("suwak wycisza tlo", sounds._loops.all(func(entry: Dictionary) -> bool: return entry.player.volume_db <= MapSounds.SILENT_DB + 1.0))
		Settings.set_value("ambience", 1.0)
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(label: String, passed: bool) -> void:
	if not passed:
		print("[test] BLAD: %s" % label)
		_failures += 1
