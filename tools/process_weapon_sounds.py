"""Obrobka nagran broni do gry: wyciecie strzalu, kompresja, warstwa basu, limiter i glosnosc
zalezna od klasy broni (RMS pierwszych 250 ms), zeby bronie mialy rowna, przewidywalna glosnosc,
a ciezkie bronie mialy wiecej "uderzenia".
Uzycie: python3 -I tools/process_weapon_sounds.py <katalog_zrodel> <katalog_wyjscia>
Zrodla: rozpakowana "Prepared SFX Library" w <katalog_zrodel>/lib/ i pliki przeladowan obok.
Wyniki przerob: afconvert -f WAVE -d LEI16@44100 -c 1 <plik>_raw.wav assets/sfx/weapons/<plik>.wav
Wynik: mono 24-bit w czestotliwosci zrodla. Dalej afconvert robi 16-bit 44.1 kHz.
"""
import math
import os
import sys
import wave

SRC = sys.argv[1]
OUT = sys.argv[2]
LIB = os.path.join(SRC, 'lib', 'Prepared SFX Library')

# Klasa: docelowy RMS (dBFS), sekundy, warstwa basu (glosnosc, Hz startu, Hz konca, zanik s),
# podbicie nisko (0 = brak), kompresja (prog dBFS, stosunek), limiter (wysterowanie).
CLASSES = {
    'smg': dict(rms=-16.0, seconds=0.65, sub=(0.10, 110.0, 70.0, 0.05), low=0.2, comp=(-24.0, 3.0), drive=1.4),
    'rifle': dict(rms=-14.5, seconds=0.95, sub=(0.18, 95.0, 55.0, 0.07), low=0.35, comp=(-22.0, 3.0), drive=1.6),
    'pistol': dict(rms=-13.0, seconds=1.1, sub=(0.30, 85.0, 48.0, 0.09), low=0.5, comp=(-22.0, 3.5), drive=1.8),
    'shotgun': dict(rms=-11.0, seconds=1.6, sub=(0.55, 75.0, 38.0, 0.16), low=0.9, comp=(-20.0, 4.0), drive=2.4),
    'sniper': dict(rms=-10.5, seconds=2.0, sub=(0.55, 70.0, 34.0, 0.20), low=0.7, comp=(-18.0, 4.0), drive=2.2),
}
SHOTS = [
    ('rifle_ar15', 'AR-15/D_32P.wav', 'rifle'),
    ('rifle_ak47', 'AK-47/C_28P.wav', 'rifle'),
    ('rifle_sks', 'SKS/U_14P.wav', 'rifle'),
    ('smg_m45', 'Carl Gustav M45/G_31P.wav', 'smg'),
    ('shotgun_nova', 'Model 12/K_22P.wav', 'shotgun'),
    ('pistol_1911', '1911/A_42P.wav', 'pistol'),
    ('sniper_tikka', '1917/B_24P.wav', 'sniper'),
]
RELOADS = [
    ('reload_pistol', 'gunreload1.wav'),
    ('reload_rifle', 'assaultriflereload1_0.wav'),
    ('reload_shotgun', 'shotguncock_0.wav'),
]
RELOAD_RMS = -26.0
CEILING = 0.97


def db(value):
    return 10.0 ** (value / 20.0)


def read_mono(path, max_seconds=6.0):
    w = wave.open(path)
    ch, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(min(frames, int(max_seconds * rate)))
    step = ch * width
    scale = 8388608.0 if width == 3 else 32768.0
    out = []
    for i in range(0, len(raw) - step + 1, step):
        total = 0.0
        for c in range(ch):
            total += int.from_bytes(raw[i + c * width:i + (c + 1) * width], 'little', signed=True) / scale
        out.append(total / ch)
    return out, rate


def write_24(path, samples, rate):
    w = wave.open(path, 'wb')
    w.setnchannels(1)
    w.setsampwidth(3)
    w.setframerate(rate)
    data = bytearray()
    for v in samples:
        data += max(-8388608, min(8388607, int(v * 8388607))).to_bytes(3, 'little', signed=True)
    w.writeframes(bytes(data))
    w.close()


def rms(samples):
    return math.sqrt(sum(v * v for v in samples) / max(1, len(samples)))


def lowpass(samples, rate, hz):
    a = math.exp(-2.0 * math.pi * hz / rate)
    out = []
    y = 0.0
    for v in samples:
        y = (1.0 - a) * v + a * y
        out.append(y)
    return out


def compress(samples, rate, threshold_db, ratio, attack=0.002, release=0.08):
    threshold = db(threshold_db)
    att = math.exp(-1.0 / (attack * rate))
    rel = math.exp(-1.0 / (release * rate))
    env = 0.0
    out = []
    for v in samples:
        level = abs(v)
        env = att * env + (1.0 - att) * level if level > env else rel * env + (1.0 - rel) * level
        gain = 1.0
        if env > threshold:
            gain = (threshold / env) ** (1.0 - 1.0 / ratio)
        out.append(v * gain)
    return out


def soft_limit(samples, drive):
    norm = math.tanh(drive)
    return [math.tanh(v * drive) / norm * CEILING for v in samples]


def fade_out(samples, part):
    start = int(len(samples) * (1.0 - part))
    for i in range(start, len(samples)):
        f = 1.0 - (i - start) / max(1, len(samples) - start)
        samples[i] *= f * f
    return samples


def shot(name, rel_path, cls):
    cfg = CLASSES[cls]
    samples, rate = read_mono(os.path.join(LIB, rel_path))
    peak = max(abs(v) for v in samples) or 1.0
    first = next(i for i, v in enumerate(samples) if abs(v) >= peak * 0.35)
    start = max(0, first - int(0.003 * rate))
    cut = [v / peak for v in samples[start:start + int(cfg['seconds'] * rate)]]
    # Podbicie niskich tonow z samego nagrania.
    if cfg['low'] > 0.0:
        low = lowpass(lowpass(cut, rate, 180.0), rate, 180.0)
        cut = [v + l * cfg['low'] * 2.0 for v, l in zip(cut, low)]
    # Warstwa "uderzenia": opadajacy sinus o niskiej czestotliwosci, jak cisnienie wystrzalu.
    amp, hz_from, hz_to, decay = cfg['sub']
    phase = 0.0
    for i in range(len(cut)):
        t = i / rate
        hz = hz_to + (hz_from - hz_to) * math.exp(-t / (decay * 0.6))
        phase += 2.0 * math.pi * hz / rate
        attack = min(1.0, t / 0.002)
        cut[i] += math.sin(phase) * amp * attack * math.exp(-t / decay)
    cut = compress(cut, rate, *cfg['comp'])
    # Glosnosc pierwszych 250 ms do celu klasy, potem limiter (ktory ja minimalnie zmienia).
    head = cut[:int(0.25 * rate)]
    cut = [v * db(cfg['rms']) / max(rms(head), 1e-9) for v in cut]
    cut = soft_limit(cut, cfg['drive'])
    head = cut[:int(0.25 * rate)]
    scale = min(db(cfg['rms']) / max(rms(head), 1e-9), CEILING / max(abs(x) for x in cut))
    cut = [v * scale for v in cut]
    cut = fade_out(cut, 0.5)
    write_24(os.path.join(OUT, name + '_raw.wav'), cut, rate)
    print('%-15s %-8s %.2fs rms %.1f dB peak %.1f dB' % (name, cls, len(cut) / rate, 20 * math.log10(rms(cut[:int(0.25 * rate)])), 20 * math.log10(max(abs(v) for v in cut))))


def reload(name, rel_path):
    samples, rate = read_mono(os.path.join(SRC, rel_path))
    peak = max(abs(v) for v in samples) or 1.0
    gate = peak * 0.02
    first = next(i for i, v in enumerate(samples) if abs(v) >= gate)
    last = len(samples) - next(i for i, v in enumerate(reversed(samples)) if abs(v) >= gate)
    cut = samples[max(0, first - int(0.01 * rate)):min(len(samples), last + int(0.05 * rate))]
    # Przeladowanie to kilka klikniec: liczymy RMS tylko z glosnych fragmentow, zeby cisza miedzy
    # nimi nie zawyzala wzmocnienia.
    loud = [v for v in cut if abs(v) >= peak * 0.05] or cut
    gain = db(RELOAD_RMS) / max(rms(loud), 1e-9)
    gain = min(gain, CEILING / peak)
    cut = [v * gain for v in cut]
    for i in range(int(0.03 * rate)):
        cut[-1 - i] *= i / (0.03 * rate)
    write_24(os.path.join(OUT, name + '_raw.wav'), cut, rate)
    print('%-15s reload   %.2fs rms(glosne) %.1f dB peak %.1f dB' % (name, len(cut) / rate, 20 * math.log10(rms([v for v in cut if abs(v) >= peak * gain * 0.05] or cut)), 20 * math.log10(max(abs(v) for v in cut))))


os.makedirs(OUT, exist_ok=True)
for job in SHOTS:
    shot(*job)
for job in RELOADS:
    reload(*job)
