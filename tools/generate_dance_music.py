#!/usr/bin/env python3
"""Sklada oryginalne, zapetlone utwory do tancow i zapisuje je w assets/music/dances.

Uzycie: python tools/generate_dance_music.py, a potem godot --headless --path . --import
Kazdy utwor ma 16 uderzen. Tempo musi sie zgadzac z DANCES w scripts/player/dance_catalog.gd.
Wybrzmiewajace nuty zawijaja sie na poczatek bufora, wiec petla nie ma slyszalnego szwu.
"""
import array
import math
import os
import random
import wave

RATE = 32000
BEATS = 16
PEAK = 0.84
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music", "dances")

C_MAJOR = [0, 2, 4, 5, 7, 9, 11]
A_MINOR = [9, 11, 12, 14, 16, 17, 19]


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


class Track:
    def __init__(self, bpm):
        self.beat = 60.0 / bpm
        self.size = round(BEATS * self.beat * RATE)
        self.mix = [0.0] * self.size
        self.noise = random.Random(int(bpm))

    def _add(self, at_beat, seconds, sample):
        start = round(at_beat * self.beat * RATE)
        for n in range(round(seconds * RATE)):
            self.mix[(start + n) % self.size] += sample(n / RATE)

    def marimba(self, at, midi, gain=0.4, decay=7.0):
        f = hz(midi)
        self._add(at, 0.7, lambda t: gain * math.exp(-t * decay) * (math.sin(math.tau * f * t) + 0.3 * math.exp(-t * 24.0) * math.sin(math.tau * f * 3.93 * t)))

    def bell(self, at, midi, gain=0.3):
        f = hz(midi)
        self._add(at, 1.3, lambda t: gain * math.exp(-t * 3.6) * (math.sin(math.tau * f * t) + 0.45 * math.exp(-t * 7.0) * math.sin(math.tau * f * 2.76 * t)))

    def square(self, at, midi, length, gain=0.16):
        f = hz(midi)
        seconds = length * self.beat

        def sample(t):
            envelope = min(t / 0.004, 1.0) * min((seconds - t) / 0.02, 1.0)
            return gain * envelope * (1.0 if (f * t) % 1.0 < 0.5 else -1.0)

        self._add(at, seconds, sample)

    def reed(self, at, midi, length, gain=0.15):
        # Nieco rozstrojone dwa glosy, jak miech akordeonu.
        f = hz(midi)
        seconds = length * self.beat

        def sample(t):
            envelope = min(t / 0.012, 1.0) * min((seconds - t) / 0.03, 1.0)
            saw = 2.0 * ((f * t) % 1.0) - 1.0
            saw2 = 2.0 * ((f * 1.006 * t) % 1.0) - 1.0
            return gain * envelope * (saw + saw2) * 0.5

        self._add(at, seconds, sample)

    def pluck(self, at, midi, gain=0.26):
        f = hz(midi)

        def sample(t):
            return gain * min(t / 0.003, 1.0) * math.exp(-t * 11.0) * (2.0 * ((f * t) % 1.0) - 1.0)

        self._add(at, 0.45, sample)

    def bass(self, at, midi, length, gain=0.5):
        f = hz(midi)
        seconds = length * self.beat

        def sample(t):
            envelope = min(t / 0.006, 1.0) * min((seconds - t) / 0.03, 1.0) * math.exp(-t * 1.6)
            return gain * envelope * (math.sin(math.tau * f * t) + 0.25 * math.sin(math.tau * f * 2.0 * t))

        self._add(at, seconds, sample)

    def kick(self, at, gain=0.75):
        self._add(at, 0.2, lambda t: gain * math.exp(-t * 20.0) * math.sin(math.tau * (48.0 * t + 2.6 * (1.0 - math.exp(-t * 34.0)))))

    def snare(self, at, gain=0.3):
        noise = self.noise
        self._add(at, 0.16, lambda t: gain * math.exp(-t * 24.0) * (noise.uniform(-1.0, 1.0) + 0.5 * math.sin(math.tau * 190.0 * t)))

    def snap(self, at, gain=0.3):
        noise = self.noise
        self._add(at, 0.07, lambda t: gain * math.exp(-t * 70.0) * noise.uniform(-1.0, 1.0))

    def hat(self, at, gain=0.09):
        noise = self.noise
        last = [0.0]

        def sample(t):
            value = noise.uniform(-1.0, 1.0)
            high = value - last[0]
            last[0] = value
            return gain * math.exp(-t * 60.0) * high

        self._add(at, 0.06, sample)

    def samples(self):
        # Lagodne nasycenie, a potem ten sam szczyt w kazdym utworze.
        shaped = [math.tanh(value * 1.25) for value in self.mix]
        scale = PEAK / max(abs(value) for value in shaped)
        return [value * scale for value in shaped]


def note(scale, degree, base=60):
    return base + scale[degree % 7] + 12 * (degree // 7)


def melody(track, play, scale, line, base=72, step=0.5, start=0.0):
    """line: stopnie skali co pol uderzenia. None to pauza."""
    for index, degree in enumerate(line):
        if degree is not None:
            play(start + index * step, note(scale, degree, base))


def bujanka():
    t = Track(100.0)
    chords = [[53, 57, 60], [55, 59, 62], [52, 55, 59], [57, 60, 64]]
    for bar, chord in enumerate(chords):
        at = bar * 4.0
        t.bass(at, chord[0] - 12, 1.4)
        t.bass(at + 1.5, chord[0] - 12, 0.4)
        t.bass(at + 2.5, chord[2] - 12, 1.0)
        for off in [0.5, 1.5, 2.5, 3.5]:
            for midi in chord:
                t.marimba(at + off, midi + 12, 0.15, 9.0)
        t.snap(at + 1.0)
        t.snap(at + 3.0)
        t.kick(at, 0.5)
        t.kick(at + 2.5, 0.4)
    line = [4, None, 5, 4, 2, None, 0, None, 1, None, 2, 4, 3, None, 1, None,
            2, None, 4, 2, 1, None, 6 - 7, None, 0, 2, 4, None, 5, 4, 2, None]
    melody(t, lambda at, m: t.marimba(at, m, 0.42), C_MAJOR, line, 72)
    return t


def robot():
    t = Track(112.0)
    roots = [45, 41, 43, 40]
    for bar, root in enumerate(roots):
        at = bar * 4.0
        for beat in range(4):
            t.kick(at + beat, 0.7)
            t.hat(at + beat + 0.5, 0.12)
            t.bass(at + beat, root, 0.4, 0.42)
            t.bass(at + beat + 0.5, root + 12, 0.3, 0.3)
        t.snare(at + 1.0, 0.22)
        t.snare(at + 3.0, 0.22)
        for index, shift in enumerate([12, 19, 24, 19, 15, 24, 19, 15]):
            t.square(at + index * 0.5, root + shift + 12, 0.22, 0.05)
    line = [0, None, 0, 2, None, 4, None, 2, 3, None, 3, 5, None, 7, None, 5,
            4, None, 4, 6, None, 4, 2, None, 1, 2, 4, None, 2, None, 0, None]
    melody(t, lambda at, m: t.square(at, m, 0.4, 0.11), A_MINOR, line, 60)
    return t


def wiatrak():
    t = Track(126.0)
    chords = [[48, 52, 55], [48, 52, 55], [43, 47, 50], [48, 52, 55]]
    for bar, chord in enumerate(chords):
        at = bar * 4.0
        for beat in range(4):
            low = chord[0] if beat % 2 == 0 else chord[2] - 12
            t.bass(at + beat, low, 0.45, 0.5)
            for midi in chord:
                t.reed(at + beat + 0.5, midi + 12, 0.4, 0.07)
            t.hat(at + beat + 0.5, 0.1)
        t.snare(at + 1.0, 0.13)
        t.snare(at + 3.0, 0.13)
    line = [0, 2, 4, 2, 0, 2, 4, 7, 5, 4, 2, 4, 5, None, 3, None,
            1, 3, 5, 3, 1, 3, 5, 8, 7, 6, 5, 4, 2, None, 0, None]
    melody(t, lambda at, m: t.reed(at, m, 0.42, 0.13), C_MAJOR, line, 72)
    return t


def podskoki():
    t = Track(132.0)
    chords = [[50, 54, 57], [55, 59, 62], [52, 55, 59], [57, 61, 64]]
    for bar, chord in enumerate(chords):
        at = bar * 4.0
        for beat in range(4):
            t.kick(at + beat, 0.8)
            t.hat(at + beat + 0.5, 0.13)
            t.bass(at + beat + 0.5, chord[0] - 12, 0.4, 0.45)
            for midi in chord:
                t.pluck(at + beat + 0.5, midi + 12, 0.08)
        t.snare(at + 1.0, 0.25)
        t.snare(at + 3.0, 0.25)
    d_major = [2, 4, 6, 7, 9, 11, 13]
    line = [0, 2, 4, None, 4, 5, 4, None, 3, 5, 7, None, 7, 8, 7, None,
            2, 4, 6, None, 6, 7, 6, None, 4, 6, 8, 7, 6, None, 4, None]
    melody(t, lambda at, m: t.pluck(at, m, 0.3), d_major, line, 72)
    return t


def skretas():
    t = Track(120.0)
    roots = [45, 45, 50, 52]
    for bar, root in enumerate(roots):
        at = bar * 4.0
        # Bas rock and rollowy: te same cztery nuty, ale w gore i w dol.
        for index, shift in enumerate([0, 4, 7, 9, 10, 9, 7, 4]):
            t.bass(at + index * 0.5, root + shift, 0.45, 0.42)
        for beat in range(4):
            t.hat(at + beat, 0.1)
            t.hat(at + beat + 0.5, 0.07)
        t.kick(at, 0.65)
        t.kick(at + 2.0, 0.65)
        t.snare(at + 1.0, 0.3)
        t.snare(at + 3.0, 0.3)
        for off in [0.5, 2.5, 3.5]:
            for shift in [12, 16, 19]:
                t.pluck(at + off, root + shift, 0.09)
    blues = [0, 3, 5, 6, 7, 10, 12]
    line = [0, None, 1, 2, 3, 2, 1, None, 0, None, 4, 5, 6, 5, 4, None,
            4, None, 5, 4, 2, 1, 0, None, 1, 2, 4, None, 2, None, 0, None]
    melody(t, lambda at, m: t.square(at, m, 0.34, 0.08), blues, line, 69)
    return t


def piruet():
    t = Track(92.0)
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    for bar, chord in enumerate(chords):
        at = bar * 4.0
        t.bass(at, chord[0] - 24, 1.8, 0.34)
        t.bass(at + 2.0, chord[0] - 24, 1.8, 0.28)
        for index, midi in enumerate(chord + [chord[0] + 12, chord[2] + 12, chord[0] + 12] + chord[1:]):
            t.marimba(at + index * 0.5, midi + 12, 0.2, 5.0)
        t.snap(at + 2.0, 0.08)
    line = [4, None, None, 2, 7, None, None, 6, 5, None, 4, None, 2, None, None, None,
            3, None, None, 5, 8, None, None, 7, 6, None, 5, 4, 1, None, None, None]
    melody(t, lambda at, m: t.bell(at, m), C_MAJOR, line, 72)
    return t


SONGS = {"bujanka": bujanka, "robot": robot, "wiatrak": wiatrak, "podskoki": podskoki, "skretas": skretas, "piruet": piruet}


def save(name, track):
    samples = track.samples()
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    seam = abs(samples[0] - samples[-1])
    pcm = array.array("h", (round(value * 32767.0) for value in samples))
    if array.array("h", [1]).tobytes()[0] != 1:
        pcm.byteswap()
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    print("%s: %.2f s, rms %.3f, szew %.3f, %d kB" % (name, len(samples) / RATE, rms, seam, os.path.getsize(path) // 1024))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in SONGS.items():
        save(name, build())


if __name__ == "__main__":
    main()
