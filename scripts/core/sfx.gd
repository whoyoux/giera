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
