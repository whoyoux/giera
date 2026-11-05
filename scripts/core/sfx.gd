class_name Sfx
extends RefCounted
## Dzwieki generowane w kodzie, zeby prototyp nie potrzebowal plikow audio.

const RATE := 22050

static var _cache := {}


static func shot() -> AudioStreamWAV:
	return _make("shot", 0.2, func(t: float, phase: float) -> float:
		var envelope := pow(1.0 - t / 0.2, 2.0)
		var square := 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		return (square * 0.65 + randf_range(-0.35, 0.35)) * envelope
	, func(t: float) -> float: return lerpf(880.0, 130.0, sqrt(t / 0.2)))


static func hit() -> AudioStreamWAV:
	return _make("hit", 0.08, func(t: float, phase: float) -> float:
		return sin(TAU * phase) * (1.0 - t / 0.08)
	, func(_t: float) -> float: return 1500.0)


static func hurt() -> AudioStreamWAV:
	return _make("hurt", 0.24, func(t: float, phase: float) -> float:
		var envelope := pow(1.0 - t / 0.24, 1.5)
		return (sin(TAU * phase) * 0.8 + randf_range(-0.25, 0.25)) * envelope
	, func(t: float) -> float: return lerpf(240.0, 70.0, t / 0.24))


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
