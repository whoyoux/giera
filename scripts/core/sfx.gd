class_name Sfx
extends RefCounted
## Dzwieki generowane w kodzie, zeby prototyp nie potrzebowal plikow audio.

const RATE := 22050
const RELOAD_SOUND_SECONDS := 1.6
const BIRD_VARIANTS := 3
## Dlugosc petli tla i czas przenikania jej konca z poczatkiem.
const LOOP_SECONDS := 9.0
const LOOP_FADE_SECONDS := 1.0
## Sredni poziom petli tla. Roznice miedzy nimi ustawia juz sama glosnosc odtwarzania.
const LOOP_LOUDNESS := 0.16
## Dzwieki interfejsu. Kazdy odpowiada za jedno znaczenie, wiec gracz rozroznia je bez patrzenia.
enum UiCue { NONE, HOVER, PRESS, CONFIRM, BACK, TOGGLE_ON, TOGGLE_OFF, SLIDER, OPEN, CLOSE, ERROR, NOTE, SWITCH }

static var _cache := {}


## Strzal zbudowany z parametrow broni: im nizszy koniec opadania, tym ciezszy dzwiek.
static func shot(stats: WeaponStats) -> AudioStreamWAV:
	var seconds := stats.shot_seconds
	var key := "shot_%f_%f_%f_%f" % [stats.shot_start_hz, stats.shot_end_hz, seconds, stats.shot_noise]
	return _make(key, seconds, func(t: float, phase: float) -> float:
		var envelope := pow(1.0 - t / seconds, 2.0)
		var square := 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		return (square * (1.0 - stats.shot_noise) + randf_range(-stats.shot_noise, stats.shot_noise)) * envelope
	, func(t: float) -> float: return lerpf(stats.shot_start_hz, stats.shot_end_hz, sqrt(t / seconds)))


## Swist noza w powietrzu.
static func knife_swing() -> AudioStreamWAV:
	return _make("knife_swing", 0.2, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) * 0.35 + randf_range(-0.5, 0.5)) * sin(PI * t / 0.2)
	, func(t: float) -> float: return lerpf(380.0, 1100.0, t / 0.2))


## Swist zakonczony tepym uderzeniem, gdy ostrze w cos trafi.
static func knife_hit() -> AudioStreamWAV:
	return _make("knife_hit", 0.24, func(t: float, phase: float) -> float:
		var swing := (sin(TAU * phase) * 0.3 + randf_range(-0.35, 0.35)) * maxf(1.0 - t / 0.08, 0.0)
		var since := maxf(t - 0.05, 0.0)
		var thud := (sin(TAU * 190.0 * since) * 0.9 + randf_range(-0.2, 0.2)) * exp(-since * 24.0) if t >= 0.05 else 0.0
		return swing + thud
	, func(t: float) -> float: return lerpf(380.0, 1100.0, minf(t / 0.08, 1.0)))


## Trafienie w glowe: wyzszy, podwojny dzwiek.
static func headshot() -> AudioStreamWAV:
	return _make("headshot", 0.16, func(t: float, phase: float) -> float:
		var gate := 1.0 if t < 0.06 or t > 0.09 else 0.0
		return sin(TAU * phase) * (1.0 - t / 0.16) * gate
	, func(t: float) -> float: return 2100.0 if t < 0.08 else 2800.0)


## Fanfara serii zabojstw: trzy nuty w gore.
static func streak() -> AudioStreamWAV:
	return _make("streak", 0.5, func(t: float, phase: float) -> float:
		var note := fmod(t, 0.16) / 0.16
		return (1.0 if fposmod(phase, 1.0) < 0.5 else -1.0) * 0.3 * (1.0 - note * 0.6)
	, func(t: float) -> float: return [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.16), 3)])


static func hit() -> AudioStreamWAV:
	return _make("hit", 0.08, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.08)
	, func(_t: float) -> float: return 1500.0)


static func hurt() -> AudioStreamWAV:
	return _make("hurt", 0.24, func(t: float, phase: float) -> float:
		var envelope := pow(1.0 - t / 0.24, 1.5)
		return (sin(TAU * phase) * 0.8 + randf_range(-0.25, 0.25)) * envelope
	, func(t: float) -> float: return lerpf(240.0, 70.0, t / 0.24))


## Magazynek wypada, nowy wchodzi, a na koncu zamek. Czasy odpowiadaja animacji broni.
static func reload_sound() -> AudioStreamWAV:
	var events: Array[Array] = [[0.24, 900.0, 55.0, 0.8], [0.5, 170.0, 22.0, 0.6], [1.22, 620.0, 45.0, 0.9], [1.4, 1100.0, 70.0, 0.7], [1.5, 780.0, 60.0, 0.9]]
	return _make("reload", RELOAD_SOUND_SECONDS, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for event in events:
			if t >= event[0]:
				var since: float = t - event[0]
				sample += (sin(TAU * event[1] * since) * 0.7 + randf_range(-0.3, 0.3)) * exp(-since * event[2]) * event[3]
		return sample
	, func(_t: float) -> float: return 0.0)


## Krotki trzask przy zmianie broni.
static func switch_item() -> AudioStreamWAV:
	return _make("switch_item", 0.14, func(t: float, _phase: float) -> float:
		var first := exp(-t * 90.0) * sin(TAU * 1250.0 * t)
		var second := exp(-maxf(t - 0.06, 0.0) * 70.0) * sin(TAU * 780.0 * t) if t >= 0.06 else 0.0
		return (first + second) * 0.7 + randf_range(-0.05, 0.05)
	, func(_t: float) -> float: return 0.0)


## Dwa rosnace dzwieki: cos wpadlo do kieszeni.
static func item_pickup() -> AudioStreamWAV:
	return _make("item_pickup", 0.2, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * pow(1.0 - t / 0.2, 1.2) * 0.8
	, func(t: float) -> float: return 620.0 if t < 0.07 else 930.0)


## Krotki swist w dol przy rzucie.
static func item_drop() -> AudioStreamWAV:
	return _make("item_drop", 0.16, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) * 0.6 + randf_range(-0.25, 0.25)) * (1.0 - t / 0.16)
	, func(t: float) -> float: return lerpf(520.0, 190.0, t / 0.16))


## Plastikowe stukniecie o ziemie.
static func item_land() -> AudioStreamWAV:
	return _make("item_land", 0.14, func(t: float, _phase: float) -> float:
		var knock := sin(TAU * 240.0 * t) * exp(-t * 32.0)
		var click := sin(TAU * 1050.0 * t) * exp(-t * 90.0) * 0.5
		return (knock + click) * 0.9
	, func(_t: float) -> float: return 0.0)


## Cichy dzwoneczek: tu jest cos do otwarcia.
static func chest_twinkle() -> AudioStreamWAV:
	return _make("chest_twinkle", 0.5, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for note: Array in [[0.0, 1320.0], [0.09, 1760.0], [0.18, 2093.0]]:
			if t >= note[0]:
				var since: float = t - note[0]
				sample += sin(TAU * note[1] * since) * exp(-since * 11.0) * 0.4
		return sample
	, func(_t: float) -> float: return 0.0)


## Plastikowe stukanie wieka, powtarzane przez czas otwierania.
static func chest_rattle() -> AudioStreamWAV:
	return _make("chest_rattle", 0.24, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for start: float in [0.0, 0.08, 0.16]:
			if t >= start:
				var since: float = t - start
				sample += (sin(TAU * 410.0 * since) * 0.7 + randf_range(-0.2, 0.2)) * exp(-since * 55.0)
		return sample * 0.7
	, func(_t: float) -> float: return 0.0)


## Trzask wieka i rosnace akordy. Lepszy lup gra wyzej.
static func chest_open() -> AudioStreamWAV:
	return _make("chest_open", 0.8, func(t: float, _phase: float) -> float:
		var sample := (sin(TAU * 170.0 * t) + randf_range(-0.5, 0.5)) * exp(-t * 26.0) * 0.8
		for note: Array in [[0.05, 523.0], [0.13, 659.0], [0.21, 784.0], [0.29, 1047.0]]:
			if t >= note[0]:
				var since: float = t - note[0]
				sample += sin(TAU * note[1] * since) * exp(-since * 5.5) * 0.3
		return sample
	, func(_t: float) -> float: return 0.0)


## Krok zalezy od podloza pod stopami.
static func footstep_on(ground: int) -> AudioStreamWAV:
	match ground:
		ForestTerrain.Ground.DIRT:
			return _footstep_dirt()
		ForestTerrain.Ground.STONE:
			return _footstep_stone()
		ForestTerrain.Ground.WATER:
			return _footstep_water()
		ForestTerrain.Ground.CONCRETE:
			return _footstep_concrete()
		ForestTerrain.Ground.METAL:
			return _footstep_metal()
	return _footstep_grass()


## Krotkie klapniecie podeszwy o beton z odrobina piasku.
static func _footstep_concrete() -> AudioStreamWAV:
	return _make("footstep_concrete", 0.1, func(t: float, _phase: float) -> float:
		var slap := sin(TAU * 210.0 * t) * exp(-t * 60.0) * 0.7
		return slap + randf_range(-0.3, 0.3) * exp(-t * 55.0)
	, func(_t: float) -> float: return 0.0)


## Dzwieczne uderzenie w blache, ktore chwile brzmi.
static func _footstep_metal() -> AudioStreamWAV:
	return _make("footstep_metal", 0.3, func(t: float, _phase: float) -> float:
		var thud := sin(TAU * 140.0 * t) * exp(-t * 40.0) * 0.6
		var ring := (sin(TAU * 820.0 * t) * 0.3 + sin(TAU * 1310.0 * t) * 0.2) * exp(-t * 14.0)
		return thud + ring + randf_range(-0.1, 0.1) * exp(-t * 60.0)
	, func(_t: float) -> float: return 0.0)


## Daleki szum ruchu ulicznego: niski i rowny, z wolnymi falami.
static func city_hum_loop() -> AudioStreamWAV:
	return _noise_loop("city_hum", 0.02, func(t: float) -> float:
		return 0.75 + 0.25 * sin(TAU * t / LOOP_SECONDS * 3.0))


## Kilka gruchniec golebi.
static func pigeons() -> AudioStreamWAV:
	return _make("pigeons", 1.2, func(t: float, phase: float) -> float:
		var beat := fmod(t, 0.4)
		return sin(TAU * phase) * sin(PI * clampf(beat / 0.25, 0.0, 1.0)) * 0.5 * (1.0 if beat < 0.25 else 0.0)
	, func(t: float) -> float: return 420.0 + 120.0 * sin(TAU * fmod(t, 0.4) / 0.25))


## Krotki klakson zabawkowego auta.
static func car_horn() -> AudioStreamWAV:
	return _make("car_horn", 0.5, func(t: float, phase: float) -> float:
		var square := 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		var gate := 1.0 if t < 0.18 or (t > 0.26 and t < 0.46) else 0.0
		return square * 0.35 * gate
	, func(_t: float) -> float: return 392.0)


## Dzwonek roweru: dwa jasne brzdekniecia.
static func bike_bell() -> AudioStreamWAV:
	return _make("bike_bell", 0.7, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for start: float in [0.0, 0.2]:
			if t >= start:
				var since := t - start
				sample += (sin(TAU * 2350.0 * since) * 0.4 + sin(TAU * 3720.0 * since) * 0.2) * exp(-since * 9.0)
		return sample
	, func(_t: float) -> float: return 0.0)


## Szelest trawy i miekkie klapniecie.
static func _footstep_grass() -> AudioStreamWAV:
	return _make("footstep_grass", 0.17, func(t: float, _phase: float) -> float:
		var thump := sin(TAU * 95.0 * t) * exp(-t * 50.0) * 0.7
		var rustle := randf_range(-0.42, 0.42) * sin(PI * minf(t / 0.17, 1.0))
		return thump + rustle
	, func(_t: float) -> float: return 0.0)


## Twardsza ziemia: gluche uderzenie i troche chrzestu.
static func _footstep_dirt() -> AudioStreamWAV:
	return _make("footstep_dirt", 0.12, func(t: float, _phase: float) -> float:
		var thump := sin(TAU * 120.0 * t) * exp(-t * 42.0) * 0.8
		return thump + randf_range(-0.35, 0.35) * exp(-t * 34.0)
	, func(_t: float) -> float: return 0.0)


## Twarde stukniecie o kamien.
static func _footstep_stone() -> AudioStreamWAV:
	return _make("footstep_stone", 0.09, func(t: float, _phase: float) -> float:
		var knock := sin(TAU * 310.0 * t) * exp(-t * 70.0) * 0.8
		var click := sin(TAU * 1450.0 * t) * exp(-t * 150.0) * 0.4
		return knock + click + randf_range(-0.1, 0.1) * exp(-t * 90.0)
	, func(_t: float) -> float: return 0.0)


## Chlupniecie w plytkiej wodzie.
static func _footstep_water() -> AudioStreamWAV:
	return _make("footstep_water", 0.26, func(t: float, phase: float) -> float:
		var splash := randf_range(-0.6, 0.6) * exp(-t * 15.0)
		return splash + sin(TAU * phase) * exp(-t * 18.0) * 0.35
	, func(t: float) -> float: return lerpf(240.0, 520.0, t / 0.26))


## Niski, zmienny szum wiatru.
static func wind_loop() -> AudioStreamWAV:
	return _noise_loop("wind", 0.012, func(t: float) -> float:
		return 0.72 + 0.28 * sin(TAU * t / LOOP_SECONDS * 2.0) * sin(TAU * t / LOOP_SECONDS * 3.0))


## Wyzszy szelest, ktory narasta i opada falami.
static func leaves_loop() -> AudioStreamWAV:
	return _noise_loop("leaves", 0.3, func(t: float) -> float:
		var waves := sin(TAU * t / LOOP_SECONDS * 4.0) * 0.5 + sin(TAU * t / LOOP_SECONDS * 7.0) * 0.3 + 0.2
		return clampf(0.35 + waves * 0.65, 0.05, 1.0))


## Szybki, gesty szmer wody z lekkim bulgotaniem.
static func creek_loop() -> AudioStreamWAV:
	return _noise_loop("creek", 0.14, func(t: float) -> float:
		return 0.8 + 0.2 * sin(TAU * t / LOOP_SECONDS * 11.0))


## Dwie nuty w gore: mecz sie zaczal.
static func match_start() -> AudioStreamWAV:
	return _melody("match_start", [523.25, 783.99], 0.14, 7.0)


## Radosna fanfara dla zwyciezcy.
static func match_win() -> AudioStreamWAV:
	return _melody("match_win", [523.25, 659.25, 783.99, 1046.5], 0.12, 5.0)


## Spokojne zejscie w dol dla pozostalych.
static func match_end() -> AudioStreamWAV:
	return _melody("match_end", [659.25, 523.25, 392.0], 0.18, 6.0)


## Niskie, pulsujace buczenie poza strefa.
static func zone_hum() -> AudioStreamWAV:
	return _noise_loop("zone", 0.03, func(t: float) -> float:
		return 0.7 + 0.3 * sin(TAU * t / LOOP_SECONDS * 8.0))


## Kilka nut ptaka. Kazdy wariant ma inny rytm i wysokosc.
static func bird(variant: int) -> AudioStreamWAV:
	var songs: Array[Array] = [
		[[0.0, 0.1, 3300.0, 4100.0], [0.14, 0.1, 3400.0, 4300.0], [0.28, 0.16, 4200.0, 3200.0]],
		[[0.0, 0.18, 2500.0, 2100.0], [0.24, 0.26, 2100.0, 2750.0]],
		[[0.0, 0.05, 4600.0, 4900.0], [0.08, 0.05, 4600.0, 4900.0], [0.16, 0.05, 4600.0, 4900.0], [0.27, 0.2, 3900.0, 3000.0]],
	]
	var song: Array = songs[variant % songs.size()]
	var last: Array = song[song.size() - 1]
	var duration: float = last[0] + last[1] + 0.05
	return _make("bird_%d" % variant, duration, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for note: Array in song:
			if t >= note[0] and t < note[0] + note[1]:
				var part: float = (t - note[0]) / note[1]
				# Ton liczony wprost z czasu nuty, bo kazda ma wlasny przebieg.
				var pitch: float = lerpf(note[2], note[3], part)
				sample += sin(TAU * pitch * (t - note[0])) * sin(PI * part) * 0.7
		return sample
	, func(_t: float) -> float: return 0.0)


## Petla z wygladzonego szumu. Koniec przenika sie z poczatkiem, wiec nie slychac laczenia.
static func _noise_loop(id: String, smoothing: float, envelope: Callable) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var fade := int(LOOP_FADE_SECONDS * RATE)
	var count := int(LOOP_SECONDS * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count + fade)
	var low := 0.0
	var slow := 0.0
	for i in samples.size():
		low += (randf_range(-1.0, 1.0) - low) * smoothing
		# Roznica dwoch filtrow usuwa powolny dryf, ktory bylby trzaskiem na laczeniu.
		slow += (low - slow) * smoothing * 0.05
		samples[i] = low - slow
	for i in fade:
		var mix := float(i) / fade
		samples[i] = samples[i] * mix + samples[count + i] * (1.0 - mix)
	var energy := 0.0
	for i in count:
		energy += samples[i] * samples[i]
	var gain := LOOP_LOUDNESS / maxf(sqrt(energy / count), 0.0001)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var sample: float = samples[i] * gain * envelope.call(float(i) / RATE)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	_cache[id] = stream
	return stream


## Krotki dzwiek w gore przy wybiciu.
static func jump() -> AudioStreamWAV:
	return _make("jump", 0.14, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.14) * 0.55
	, func(t: float) -> float: return lerpf(210.0, 430.0, t / 0.14))


## Gluche uderzenie o podloge.
static func land() -> AudioStreamWAV:
	return _make("land", 0.18, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) + randf_range(-0.25, 0.25)) * exp(-t * 26.0)
	, func(t: float) -> float: return lerpf(130.0, 60.0, t / 0.18))


## Opadajacy dzwiek przy smierci.
static func death() -> AudioStreamWAV:
	return _make("death", 0.55, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.55) * 0.8
	, func(t: float) -> float: return lerpf(520.0, 90.0, sqrt(t / 0.55)))


## Wesoly akord po powrocie do gry.
static func respawn() -> AudioStreamWAV:
	return _make("respawn", 0.4, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for note: Array in [[0.0, 523.0], [0.07, 784.0], [0.14, 1047.0]]:
			if t >= note[0]:
				var since: float = t - note[0]
				sample += sin(TAU * note[1] * since) * exp(-since * 9.0) * 0.35
		return sample
	, func(_t: float) -> float: return 0.0)


## Zadyszka: koniec speeda.
static func exhausted() -> AudioStreamWAV:
	return _make("exhausted", 0.26, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) * 0.5 + randf_range(-0.2, 0.2)) * sin(PI * t / 0.26)
	, func(t: float) -> float: return lerpf(340.0, 240.0, t / 0.26))


## Otwarcie apteczki, szelest bandaza i rosnacy dzwonek na koncu.
static func medkit_use() -> AudioStreamWAV:
	var clicks: Array[Array] = [[0.12, 980.0, 70.0, 0.8], [0.3, 640.0, 60.0, 0.7], [1.0, 320.0, 30.0, 0.35], [1.35, 320.0, 30.0, 0.35], [1.7, 320.0, 30.0, 0.35]]
	return _make("medkit_use", 2.5, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for click in clicks:
			if t >= click[0]:
				var since: float = t - click[0]
				sample += (sin(TAU * click[1] * since) * 0.5 + randf_range(-0.4, 0.4)) * exp(-since * click[2]) * click[3]
		for note: Array in [[2.05, 660.0], [2.17, 880.0], [2.29, 1175.0]]:
			if t >= note[0]:
				var since: float = t - note[0]
				sample += sin(TAU * note[1] * since) * exp(-since * 8.0) * 0.35
		return sample
	, func(_t: float) -> float: return 0.0)


## Akord po uleczeniu.
static func heal() -> AudioStreamWAV:
	return _make("heal", 0.5, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for frequency: float in [523.0, 659.0, 1047.0]:
			sample += sin(TAU * frequency * t) * exp(-t * 6.0) * 0.3
		return sample
	, func(_t: float) -> float: return 0.0)


## Ciche klikniecie przy unoszeniu broni do oka.
static func aim() -> AudioStreamWAV:
	return _make("aim", 0.07, func(t: float, _phase: float) -> float:
		return (sin(TAU * 720.0 * t) * 0.6 + randf_range(-0.2, 0.2)) * exp(-t * 70.0)
	, func(_t: float) -> float: return 0.0)


## Wyciagniecie zawleczki przy odbezpieczeniu.
static func grenade_pin() -> AudioStreamWAV:
	return _make("grenade_pin", 0.16, func(t: float, _phase: float) -> float:
		var pull := sin(TAU * 2300.0 * t) * exp(-t * 70.0) * 0.55
		var spring := sin(TAU * 3400.0 * maxf(t - 0.07, 0.0)) * exp(-maxf(t - 0.07, 0.0) * 60.0) * 0.4 if t >= 0.07 else 0.0
		return pull + spring
	, func(_t: float) -> float: return 0.0)


## Swist rzutu.
static func grenade_throw() -> AudioStreamWAV:
	return _make("grenade_throw", 0.22, func(t: float, _phase: float) -> float:
		return randf_range(-0.55, 0.55) * sin(PI * t / 0.22)
	, func(_t: float) -> float: return 0.0)


## Metaliczne stukniecie o ziemie.
static func grenade_bounce() -> AudioStreamWAV:
	return _make("grenade_bounce", 0.12, func(t: float, _phase: float) -> float:
		return (sin(TAU * 720.0 * t) * 0.6 + sin(TAU * 1730.0 * t) * 0.35) * exp(-t * 42.0)
	, func(_t: float) -> float: return 0.0)


## Krotki sygnal ostrzegawczy.
static func grenade_beep() -> AudioStreamWAV:
	return _make("grenade_beep", 0.06, func(t: float, _phase: float) -> float:
		return sin(TAU * 1680.0 * t) * sin(PI * t / 0.06) * 0.6
	, func(_t: float) -> float: return 0.0)


## Trzask na poczatku i dlugie, niskie dudnienie.
static func explosion() -> AudioStreamWAV:
	return _make("explosion", 1.5, func(t: float, phase: float) -> float:
		var crack := randf_range(-1.0, 1.0) * exp(-t * 16.0)
		var rumble := sin(TAU * phase) * exp(-t * 3.0) * 0.9
		var dirt := randf_range(-0.28, 0.28) * exp(-t * 2.6)
		return crack + rumble + dirt
	, func(t: float) -> float: return lerpf(92.0, 32.0, minf(t / 0.8, 1.0)))


static func kill() -> AudioStreamWAV:
	return _make("kill", 0.26, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.26)
	, func(t: float) -> float: return 880.0 if t < 0.1 else 1320.0)


## Ledwie slyszalne tykniecie pod kursorem. Pada czesto, wiec musi byc najcichsze i najkrotsze.
static func ui_hover() -> AudioStreamWAV:
	return _make("ui_hover", 0.035, func(t: float, _phase: float) -> float:
		return sin(TAU * 1900.0 * t) * sin(PI * t / 0.035)
	, func(_t: float) -> float: return 0.0)


## Drewniane stukniecie w chwili wcisniecia, zeby reakcja nie czekala na puszczenie przycisku.
static func ui_press() -> AudioStreamWAV:
	return _make("ui_press", 0.05, func(t: float, _phase: float) -> float:
		return _marimba(t, 560.0, 90.0)
	, func(_t: float) -> float: return 0.0)


## Dwie rosnace nuty: idziemy dalej.
static func ui_confirm() -> AudioStreamWAV:
	return _make("ui_confirm", 0.24, func(t: float, _phase: float) -> float:
		return _marimba(t, 659.0, 26.0) * 0.6 + (_marimba(t - 0.07, 988.0, 18.0) * 0.8 if t >= 0.07 else 0.0)
	, func(_t: float) -> float: return 0.0)


## Te same dwie nuty w dol: wycofujemy sie.
static func ui_back() -> AudioStreamWAV:
	return _make("ui_back", 0.22, func(t: float, _phase: float) -> float:
		return _marimba(t, 740.0, 28.0) * 0.6 + (_marimba(t - 0.07, 494.0, 20.0) * 0.8 if t >= 0.07 else 0.0)
	, func(_t: float) -> float: return 0.0)


static func ui_toggle_on() -> AudioStreamWAV:
	return _make("ui_toggle_on", 0.08, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * sin(PI * t / 0.08)
	, func(t: float) -> float: return lerpf(520.0, 980.0, t / 0.08))


static func ui_toggle_off() -> AudioStreamWAV:
	return _make("ui_toggle_off", 0.08, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * sin(PI * t / 0.08)
	, func(t: float) -> float: return lerpf(720.0, 400.0, t / 0.08))


## Zabek suwaka. Wysokosc zmienia sie przy odtwarzaniu razem z wartoscia.
static func ui_slider() -> AudioStreamWAV:
	return _make("ui_slider", 0.03, func(t: float, _phase: float) -> float:
		return sin(TAU * 1250.0 * t) * sin(PI * t / 0.03)
	, func(_t: float) -> float: return 0.0)


## Miekki poslizg w gore: okno sie wysuwa.
static func ui_open() -> AudioStreamWAV:
	return _make("ui_open", 0.18, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) * 0.8 + randf_range(-0.12, 0.12)) * sin(PI * t / 0.18)
	, func(t: float) -> float: return lerpf(320.0, 760.0, t / 0.18))


static func ui_close() -> AudioStreamWAV:
	return _make("ui_close", 0.14, func(t: float, phase: float) -> float:
		return (sin(TAU * phase) * 0.8 + randf_range(-0.12, 0.12)) * sin(PI * t / 0.14)
	, func(t: float) -> float: return lerpf(640.0, 280.0, t / 0.14))


## Dwa niskie burkniecia: nie da sie. Niskie, bo wysoki pisk przy bledzie irytuje.
static func ui_error() -> AudioStreamWAV:
	return _make("ui_error", 0.22, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for start: float in [0.0, 0.11]:
			if t >= start:
				var since: float = t - start
				sample += (sin(TAU * 196.0 * since) + sin(TAU * 392.0 * since) * 0.45) * exp(-since * 24.0)
		return sample * 0.75
	, func(_t: float) -> float: return 0.0)


## Nuta cymbalkow, strojona przy odtwarzaniu. Graja na niej literki tytulu.
static func ui_note() -> AudioStreamWAV:
	return _make("ui_note", 0.4, func(t: float, _phase: float) -> float:
		return _marimba(t, 523.25, 11.0)
	, func(_t: float) -> float: return 0.0)


## Nuta jak z drewnianej sztabki: ton i krotki, jasny atak.
static func _melody(id: String, notes: Array[float], step: float, decay: float) -> AudioStreamWAV:
	return _make(id, notes.size() * step + 0.6, func(t: float, _phase: float) -> float:
		var sample := 0.0
		for index in notes.size():
			var start := index * step
			if t >= start:
				sample += _marimba(t - start, notes[index], decay) * 0.55
		return sample
	, func(_t: float) -> float: return 0.0)


static func _marimba(t: float, hz: float, decay: float) -> float:
	return sin(TAU * hz * t) * exp(-t * decay) + sin(TAU * hz * 4.0 * t) * exp(-t * decay * 3.0) * 0.25


static func _make(id: String, duration: float, wave: Callable, pitch: Callable) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += pitch.call(t) / RATE
		var sample: float = clampf(wave.call(t, phase), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	_cache[id] = stream
	return stream
