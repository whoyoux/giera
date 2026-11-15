"""Przemalowuje tekstury-palety postaci KayKit na glebokie, dorosle barwy.

Uzycie: python3 tools/tactical_textures.py [--check]
Czyta oryginaly z assets/characters/original/ (kopiuje je tam przy pierwszym uruchomieniu)
i zapisuje przemalowane tekstury pod nazwami, ktorych uzywaja modele.

Zasady dla kazdego piksela:
- skora (cieply odcien, jasna, srednio nasycona) i szarosci (metal, kosci) zostaja,
- czysta biel i czern lekko przygaszone,
- nasycone kolory ubran zostaja w swojej rodzinie, ale glebsze i mniej "cukierkowe":
  czerwien to bordo, pomarancz to rdza, zolc to musztarda, zielen to oliwka, turkus to morski,
  niebieski to granat, a fiolet to sliwka. Dzieki temu postacie dalej sie roznia.
Gradient w polu palety zostaje, bo nowy kolor dostaje jasnosc oryginalu.
"""
import colorsys
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'characters')
ORIGINALS = os.path.join(ROOT, 'original')

# Barwy docelowe (r, g, b) w zakresie 0-1, w srodku zakresu jasnosci: (gorny kat odcienia, barwa).
BANDS = [
    (20.0, (0.56, 0.17, 0.17)),   # czerwien -> bordo
    (45.0, (0.64, 0.33, 0.15)),   # pomarancz -> rdza
    (72.0, (0.70, 0.55, 0.20)),   # zolc -> musztarda
    (160.0, (0.35, 0.45, 0.24)),  # zielen -> oliwka
    (200.0, (0.15, 0.42, 0.42)),  # turkus -> morski
    (255.0, (0.19, 0.29, 0.50)),  # niebieski -> granat
    (330.0, (0.42, 0.23, 0.44)),  # fiolet -> sliwka
    (360.0, (0.56, 0.17, 0.17)),  # czerwien -> bordo
]
# Ile koloru oryginalu zostaje (reszta to barwa docelowa).
KEEP_HUE = 0.3


def is_skin(h, s, v):
    hue = h * 360.0
    return 8.0 <= hue <= 42.0 and 0.15 <= s <= 0.62 and v >= 0.62


def target_for(h, _v):
    hue = h * 360.0
    for limit, color in BANDS:
        if hue < limit:
            return color
    return BANDS[-1][1]


def recolor(pixel):
    r, g, b, a = [c / 255.0 for c in pixel]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.18:
        # Szarosci zostaja. Czysta biel (plotno) i glebia czerni troche przygaszone.
        scale = 0.86 if v > 0.9 else 1.0
        return tuple(int(min(1.0, c * scale) * 255) for c in (r, g, b)) + (pixel[3],)
    if is_skin(h, s, v):
        return pixel
    # Brazy skory i drewna (ciemne, cieple) tylko lekko przygaszone.
    hue = h * 360.0
    if 8.0 <= hue <= 42.0 and s <= 0.7 and v < 0.62:
        gray = 0.2126 * r + 0.7152 * g + 0.0722 * b
        mix = 0.35
        return tuple(int((c + (gray - c) * mix) * 255) for c in (r, g, b)) + (pixel[3],)
    tr, tg, tb = target_for(h, v)
    # Jasnosc oryginalu przenosi gradient na nowa barwe.
    shade = 0.55 + v * 0.75
    out = []
    for c, t in zip((r, g, b), (tr, tg, tb)):
        value = t * shade * (1.0 - KEEP_HUE) + c * KEEP_HUE
        out.append(int(max(0.0, min(1.0, value)) * 255))
    return tuple(out) + (pixel[3],)


def main():
    os.makedirs(ORIGINALS, exist_ok=True)
    names = sorted(f for f in os.listdir(ROOT) if f.endswith('_texture.png'))
    for name in names:
        original = os.path.join(ORIGINALS, name)
        if not os.path.exists(original):
            shutil.copy2(os.path.join(ROOT, name), original)
        image = Image.open(original).convert('RGBA')
        image.putdata([recolor(p) for p in image.getdata()])
        image.save(os.path.join(ROOT, name))
        print('przemalowano', name)


if __name__ == '__main__':
    main()
