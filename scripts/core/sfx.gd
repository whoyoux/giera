class_name Sfx
extends RefCounted
## Dzwieki generowane w kodzie, zeby prototyp nie potrzebowal plikow audio.

const RATE := 22050
const RELOAD_SOUND_SECONDS := 1.6

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


## Miekkie klapniecie buta.
static func footstep() -> AudioStreamWAV:
	return _make("footstep", 0.1, func(t: float, _phase: float) -> float:
		return (sin(TAU * 105.0 * t) * 0.8 + randf_range(-0.3, 0.3)) * exp(-t * 48.0)
	, func(_t: float) -> float: return 0.0)


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


static func kill() -> AudioStreamWAV:
	return _make("kill", 0.26, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.26)
	, func(t: float) -> float: return 880.0 if t < 0.1 else 1320.0)


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
