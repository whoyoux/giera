class_name AmbienceSfx
extends RefCounted
## Dzwieki otoczenia map, generowane w kodzie. Wiatr to szum przepuszczony przez wedrujace filtry
## pasmowe, wiec faluje i swiszcze zamiast rowno syczec. Woda to cichy szum z pojedynczymi kroplami,
## a skrzypienie to seria impulsow pobudzajaca rezonans, jak tarcie drewna o drewno.
## Kazdy generator ma wlasne ziarno i nie dotyka wezlow, wiec MapSounds liczy je w watku.

const RATE := 22050
const FADE_SECONDS := 1.0
## Co tyle probek odswiezamy powolne zmiany filtra i glosnosci.
const CONTROL_STEP := 64
const PEAK := 24000.0

static var _cache := {}
static var _lock := Mutex.new()


# --- Wiatr -------------------------------------------------------------------

## Pustynia: niski, falujacy podmuch z lekkim swistem, bez stalego syku.
static func desert_wind() -> AudioStreamWAV:
	return _wind("desert_wind", 12.0, 0.13, 0.45, [
		{ "hz": 250.0, "sweep": 0.45, "cycles": 2, "damping": 0.9, "gain": 1.0, "depth": 0.7, "amp_cycles": 3 },
		{ "hz": 540.0, "sweep": 0.35, "cycles": 3, "damping": 0.55, "gain": 0.4, "depth": 0.85, "amp_cycles": 5 },
	])


## Kanion: waski rezonans daje wycie wiatru miedzy scianami.
static func canyon_howl() -> AudioStreamWAV:
	return _wind("canyon_howl", 10.0, 0.13, 0.25, [
		{ "hz": 360.0, "sweep": 0.22, "cycles": 2, "damping": 0.1, "gain": 1.0, "depth": 0.8, "amp_cycles": 3 },
		{ "hz": 545.0, "sweep": 0.18, "cycles": 3, "damping": 0.14, "gain": 0.45, "depth": 0.9, "amp_cycles": 2 },
	])


## Las: ciemny szum w koronach, prawie bez swistu.
static func forest_wind() -> AudioStreamWAV:
	return _wind("forest_wind", 12.0, 0.14, 0.6, [
		{ "hz": 170.0, "sweep": 0.3, "cycles": 2, "damping": 1.2, "gain": 1.0, "depth": 0.5, "amp_cycles": 3 },
		{ "hz": 880.0, "sweep": 0.3, "cycles": 5, "damping": 1.0, "gain": 0.25, "depth": 0.8, "amp_cycles": 4 },
	])


## Dolina: otwarta przestrzen, wiec wiatr jest jasniejszy i bardziej przewiewny.
static func valley_wind() -> AudioStreamWAV:
	return _wind("valley_wind", 12.0, 0.13, 0.3, [
		{ "hz": 330.0, "sweep": 0.5, "cycles": 3, "damping": 0.8, "gain": 1.0, "depth": 0.65, "amp_cycles": 2 },
		{ "hz": 1350.0, "sweep": 0.4, "cycles": 4, "damping": 0.9, "gain": 0.3, "depth": 0.85, "amp_cycles": 5 },
	])


## Miasteczko: daleki, miekki szum ulicy bez buczacego tonu.
static func city_bed() -> AudioStreamWAV:
	return _wind("city_bed", 12.0, 0.13, 0.8, [
		{ "hz": 115.0, "sweep": 0.2, "cycles": 2, "damping": 1.1, "gain": 1.0, "depth": 0.4, "amp_cycles": 3 },
		{ "hz": 430.0, "sweep": 0.3, "cycles": 3, "damping": 1.2, "gain": 0.3, "depth": 0.7, "amp_cycles": 4 },
	])


## Wydmy: wysoki, ziarnisty syk przesypywanego piasku.
static func sand_hiss() -> AudioStreamWAV:
	return _wind("sand_hiss", 8.0, 0.1, 0.0, [
		{ "hz": 5200.0, "sweep": 0.2, "cycles": 4, "damping": 0.8, "gain": 1.0, "depth": 0.9, "amp_cycles": 5 },
	])


## Szelest lisci palm: jasny szum w wyraznych falach.
static func palm_rustle() -> AudioStreamWAV:
	return _wind("palm_rustle", 8.0, 0.11, 0.0, [
		{ "hz": 2600.0, "sweep": 0.3, "cycles": 3, "damping": 0.9, "gain": 1.0, "depth": 0.95, "amp_cycles": 4 },
		{ "hz": 4300.0, "sweep": 0.2, "cycles": 5, "damping": 0.9, "gain": 0.5, "depth": 0.95, "amp_cycles": 3 },
	])


# --- Woda --------------------------------------------------------------------

## Oaza: spokojna woda z pojedynczymi pluskami.
static func oasis_water() -> AudioStreamWAV:
	return _water("oasis_water", 8.0, 0.11, 1300.0, 0.3, 5.0, Vector2(380.0, 900.0))


## Fontanna: gesty, jasny plusk spadajacej wody.
static func fountain() -> AudioStreamWAV:
	return _water("fountain", 6.0, 0.13, 2600.0, 0.9, 16.0, Vector2(700.0, 1700.0))


## Jezioro: wolne fale przy brzegu i rzadkie chlupniecia.
static func lake_lap() -> AudioStreamWAV:
	return _water("lake_lap", 10.0, 0.12, 750.0, 0.7, 2.0, Vector2(300.0, 650.0))


# --- Pojedyncze odglosy ------------------------------------------------------

## Skrzypiacy szyld na targu.
static func sign_creak() -> AudioStreamWAV:
	return _creak("sign_creak", 0.9, 620.0, Vector2(14.0, 38.0))


## Ciezkie skrzypienie wiezy cisnien.
static func tower_creak() -> AudioStreamWAV:
	return _creak("tower_creak", 1.7, 235.0, Vector2(7.0, 19.0))


## Liny mostu naprezaja sie pod wiatrem.
static func rope_creak() -> AudioStreamWAV:
	return _creak("rope_creak", 1.2, 410.0, Vector2(10.0, 30.0))


## Stare drewno w wiosce i gospodarstwie.
static func wood_creak() -> AudioStreamWAV:
	return _creak("wood_creak", 0.8, 520.0, Vector2(12.0, 26.0))


## Blacha wagonu stukajaca na wietrze.
static func tin_clank() -> AudioStreamWAV:
	return _clank("tin_clank", 0.9, [812.0, 1370.0, 2190.0, 3320.0], 8.0, [0.0, 0.21])


## Dwa stukniecia mlotka o drewno, gdzies w obejsciu.
static func wood_knock() -> AudioStreamWAV:
	return _clank("wood_knock", 0.7, [190.0, 415.0, 760.0], 34.0, [0.0, 0.26, 0.5])


## Plotno daszku lopocze: kilka gluchych uderzen powietrza.
static func canvas_flap() -> AudioStreamWAV:
	var key := "canvas_flap"
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var count := int(0.7 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var hit := 0.0
		for start: float in [0.0, 0.17, 0.29, 0.46]:
			if t >= start:
				hit += exp(-(t - start) * 26.0) * (1.0 if start < 0.2 else 0.6)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.06
		samples[i] = low * hit
	return _store(key, samples, 0.5, false)


## Daleki gwizd pociagu: trzy tony naraz, lekko drzace, z szumem pary.
static func train_whistle() -> AudioStreamWAV:
	var key := "train_whistle"
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var seconds := 2.4
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var breath := 0.0
	for i in count:
		var t := float(i) / RATE
		var envelope := minf(t / 0.18, 1.0) * minf((seconds - t) / 0.7, 1.0)
		var vibrato := 1.0 + 0.006 * sin(TAU * 5.5 * t)
		var tone := 0.0
		for hz: float in [311.0, 370.0, 466.0]:
			tone += sin(TAU * hz * vibrato * t) + 0.3 * sin(TAU * hz * 2.0 * vibrato * t)
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.2
		samples[i] = (tone * 0.25 + breath * 0.35) * envelope
	return _store(key, samples, 0.5, false)


## Krzyk jastrzebia: opadajacy, chrapliwy gwizd.
static func hawk_cry() -> AudioStreamWAV:
	var key := "hawk_cry"
	if _has(key):
		return _cache[key]
	var seconds := 1.0
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var part := t / seconds
		phase += lerpf(3300.0, 2050.0, part * part) / RATE
		var rasp := 0.7 + 0.3 * sin(TAU * 58.0 * t)
		var envelope := minf(t / 0.05, 1.0) * pow(1.0 - part, 1.4)
		samples[i] = (sin(TAU * phase) + 0.35 * sin(TAU * phase * 2.0)) * rasp * envelope
	return _store(key, samples, 0.45, false)


## Cykady w upale: wysoki, pulsujacy ton, ktory narasta i opada.
static func cicadas() -> AudioStreamWAV:
	var key := "cicadas"
	if _has(key):
		return _cache[key]
	var seconds := 6.0
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		# Wszystkie czestotliwosci mieszcza sie w petli cala liczbe razy, wiec nie slychac laczenia.
		var pulse := absf(sin(TAU * 45.0 * t))
		var swell := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * t / seconds * 2.0), 2.0)
		samples[i] = (sin(TAU * 4300.0 * t) + 0.6 * sin(TAU * 4650.0 * t)) * pulse * pulse * swell
	return _store(key, samples, 0.08, true)


## Suchy trzask galazek toczacego sie krzaka.
static func tumbleweed_rustle() -> AudioStreamWAV:
	var key := "tumbleweed"
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var count := int(2.0 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for click in 150:
		var at := rng.randi() % count
		var strength := rng.randf_range(0.3, 1.0)
		var length := rng.randi_range(20, 90)
		for i in length:
			samples[(at + i) % count] += rng.randf_range(-1.0, 1.0) * strength * (1.0 - float(i) / length)
	return _store(key, samples, 0.12, true)


# --- Generatory --------------------------------------------------------------

## Szum przez wedrujace filtry pasmowe. "rumble" dodaje niski pomruk pod spodem.
static func _wind(key: String, seconds: float, loudness: float, rumble: float, bands: Array) -> AudioStreamWAV:
	if _has(key):
		return _cache[key]
	return _store(key, _band_noise(_rng(key), seconds, rumble, bands), loudness, true)


## Cichy szum wody i krople: krotkie tony, ktore szybko rosna i gasna. Krople przechodza przez
## koniec petli na jej poczatek, wiec petla nie ma szwu.
static func _water(key: String, seconds: float, loudness: float, bed_hz: float, bed_gain: float, drops_per_second: float, drop_hz: Vector2) -> AudioStreamWAV:
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var samples := _band_noise(rng, seconds, 0.0, [
		{ "hz": bed_hz, "sweep": 0.2, "cycles": 3, "damping": 1.0, "gain": 1.0, "depth": 0.5, "amp_cycles": 4 },
		{ "hz": bed_hz * 1.9, "sweep": 0.2, "cycles": 2, "damping": 1.1, "gain": 0.5, "depth": 0.6, "amp_cycles": 5 },
	])
	var count := samples.size()
	for i in count:
		samples[i] *= bed_gain
	for drop in int(seconds * drops_per_second):
		var at := rng.randi() % count
		var hz := rng.randf_range(drop_hz.x, drop_hz.y)
		var length := int(rng.randf_range(0.05, 0.12) * RATE)
		var strength := rng.randf_range(0.6, 1.6)
		var phase := 0.0
		for i in length:
			var part := float(i) / length
			phase += hz * (1.0 + part * 0.7) / RATE
			samples[(at + i) % count] += sin(TAU * phase) * sin(PI * part) * (1.0 - part) * strength
	return _store(key, samples, loudness, true)


## Tarcie: impulsy o zmiennym tempie pobudzaja dwa rezonanse. Tempo najpierw rosnie, potem opada.
static func _creak(key: String, seconds: float, hz: float, rate: Vector2) -> AudioStreamWAV:
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low_a := 0.0
	var band_a := 0.0
	var low_b := 0.0
	var band_b := 0.0
	for i in count:
		var part := float(i) / count
		var bend := sin(PI * part)
		phase += lerpf(rate.x, rate.y, bend) / RATE
		var impulse := 0.0
		if phase >= 1.0:
			phase -= 1.0
			impulse = rng.randf_range(0.6, 1.0)
		var tune := 1.0 + 0.12 * bend
		var f_a := 2.0 * sin(PI * hz * tune / RATE)
		var high_a := impulse - low_a - 0.06 * band_a
		band_a += f_a * high_a
		low_a += f_a * band_a
		var f_b := 2.0 * sin(PI * hz * 2.37 * tune / RATE)
		var high_b := impulse - low_b - 0.09 * band_b
		band_b += f_b * high_b
		low_b += f_b * band_b
		samples[i] = (band_a + band_b * 0.5) * sin(PI * part)
	return _store(key, samples, 0.4, false)


## Uderzenie w cos twardego: kilka nieharmonicznych tonow, ktore gasna, powtorzone w chwilach "hits".
static func _clank(key: String, seconds: float, partials: Array, decay: float, hits: Array) -> AudioStreamWAV:
	if _has(key):
		return _cache[key]
	var rng := _rng(key)
	var count := int(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0
		for index in hits.size():
			var since: float = t - float(hits[index])
			if since < 0.0:
				continue
			var strength := 1.0 if index == 0 else 0.6
			for partial in partials.size():
				sample += sin(TAU * float(partials[partial]) * since) * exp(-since * decay * (1.0 + partial * 0.5)) * strength / (partial + 1.0)
			if since < 0.004:
				sample += rng.randf_range(-1.0, 1.0) * strength
		samples[i] = sample
	return _store(key, samples, 0.45, false)


## Petla szumu po filtrach pasmowych. Filtr i glosnosc kazdego pasma kraza z okresem bedacym czescia
## petli, a koniec przenika sie z poczatkiem, wiec nie slychac laczenia.
static func _band_noise(rng: RandomNumberGenerator, seconds: float, rumble: float, bands: Array) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var fade := int(FADE_SECONDS * RATE)
	var total := count + fade
	var raw := PackedFloat32Array()
	raw.resize(total)
	var band_count := bands.size()
	var lows := PackedFloat32Array()
	var mids := PackedFloat32Array()
	var tunes := PackedFloat32Array()
	var gains := PackedFloat32Array()
	var dampings := PackedFloat32Array()
	lows.resize(band_count)
	mids.resize(band_count)
	tunes.resize(band_count)
	gains.resize(band_count)
	dampings.resize(band_count)
	var phases := PackedFloat32Array()
	phases.resize(band_count * 2)
	for index in phases.size():
		phases[index] = rng.randf() * TAU
	for index in band_count:
		dampings[index] = float(bands[index].damping)
	var rumble_low := 0.0
	var rumble_slow := 0.0
	for i in total:
		if i % CONTROL_STEP == 0:
			var turn := TAU * float(i) / count
			for index in band_count:
				var band: Dictionary = bands[index]
				var hz: float = float(band.hz) * (1.0 + float(band.sweep) * sin(turn * int(band.cycles) + phases[index * 2]))
				# Filtr liczy sie dwa razy na probke, bo przy jednym razie rozjezdza sie powyzej ok. 3,5 kHz.
				tunes[index] = 2.0 * sin(PI * minf(hz, RATE * 0.3) / (RATE * 2.0))
				var wave := 0.5 + 0.5 * sin(turn * int(band.amp_cycles) + phases[index * 2 + 1])
				gains[index] = float(band.gain) * (1.0 - float(band.depth) + float(band.depth) * wave * wave)
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := 0.0
		for index in band_count:
			for pass_index in 2:
				var high := noise - lows[index] - dampings[index] * mids[index]
				mids[index] += tunes[index] * high
				lows[index] += tunes[index] * mids[index]
			sample += mids[index] * gains[index]
		if rumble > 0.0:
			rumble_low += (noise - rumble_low) * 0.012
			rumble_slow += (rumble_low - rumble_slow) * 0.0006
			sample += (rumble_low - rumble_slow) * rumble * 6.0
		raw[i] = sample
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		samples[i] = raw[i]
	for i in fade:
		var mix := float(i) / fade
		samples[i] = raw[i] * mix + raw[count + i] * (1.0 - mix)
	return samples


## Wyrownuje glosnosc do "loudness" (srednia dla petli, szczyt dla krotkich dzwiekow) i zapisuje.
static func _store(key: String, samples: PackedFloat32Array, loudness: float, looped: bool) -> AudioStreamWAV:
	var count := samples.size()
	var energy := 0.0
	var peak := 0.0001
	for i in count:
		energy += samples[i] * samples[i]
		peak = maxf(peak, absf(samples[i]))
	var gain := loudness / maxf(sqrt(energy / count), 0.0001) if looped else loudness / peak
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * PEAK))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	_lock.lock()
	_cache[key] = stream
	_lock.unlock()
	return stream


static func _has(key: String) -> bool:
	_lock.lock()
	var known := _cache.has(key)
	_lock.unlock()
	return known


## Stale ziarno z nazwy: ten sam dzwiek brzmi tak samo przy kazdym uruchomieniu.
static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng
