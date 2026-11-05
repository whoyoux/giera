# Giera

Low-poly, kreskówkowy FPS multiplayer w Godot 4.7. Gracze dołączają do jednego
wspólnego serwera, biegają po mapie i strzelają z blastera.

![Rozgrywka](docs/screenshots/gameplay.png)

| Menu | Wyniki | Obrażenia |
|---|---|---|
| ![Menu](docs/screenshots/menu.png) | ![Wyniki](docs/screenshots/scoreboard.png) | ![Obrażenia](docs/screenshots/damage.png) |

## Szybki start

Gotową wersję na Windows pobierzesz z zakładki **Releases**. Uruchom `Giera.exe`, wpisz
adres serwera podany przez hosta i kliknij **Dołącz**.

Żeby uruchomić projekt samodzielnie, otwórz folder w Godocie 4.7, naciśnij F5, a potem
wybierz **Hostuj grę na tym komputerze**.

Gra z botami na jednym komputerze:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_local.ps1 -Bots 2 -Shooters 1
```

`-Bots` to biegające cele, a `-Shooters` to boty, które strzelają do Ciebie. Dodaj
`-DebugItems`, żeby każdy gracz dostał też epicki i legendarny blaster.

Sterowanie: **WASD** ruch, **mysz** celowanie, **LPM** strzał, **R** przeładowanie,
**Shift** sprint, **spacja** skok, **1–4** lub **scroll** zmiana przedmiotu, **Tab** wyniki,
**Esc** pauza.

Ustawienia dźwięku, myszy i grafiki znajdziesz w menu głównym i w pauzie. Zapisują się
na komputerze w folderze danych gry, więc nowy build ich nie kasuje.

## Serwer dedykowany

```bash
godot --path . --headless -- --server --port=7777
```

Serwer potrzebuje otwartego portu **7777/UDP**. W menu gry wpisz adres serwera,
opcjonalnie z portem, np. `203.0.113.10:7777`.

Gotowy obraz serwera buduje `Dockerfile`. Restart serwera rozłącza graczy i zeruje wyniki.

## Build dla graczy

```bash
godot --headless --path . --export-release "Windows Desktop" builds/Giera.exe
```

Wymaga szablonów eksportu Godota 4.7.2. Po zmianach w kodzie sieciowym wszyscy gracze
potrzebują nowego pliku `Giera.exe`.

## Publikowanie nowej wersji

Wydanie powstaje automatycznie po wypchnięciu tagu `v*`. Najpierw scal zmiany do `main`,
a potem otaguj tę wersję:

```bash
git switch main
```

```bash
git pull
```

```bash
git tag v0.2.0
```

```bash
git push origin v0.2.0
```

Workflow `.github/workflows/release.yml` zbuduje `Giera.exe` i po kilku minutach opublikuje
go w zakładce **Releases**. Postęp widać w zakładce **Actions**.

Sam tag nie wdraża serwera, ale każdy push na `main` wdraża go i rozłącza graczy.
Tag z myślnikiem, np. `v0.2.0-rc1`, tworzy wersję próbną, która nie staje się najnowszą.

Przed zmianą wersji Godota zaktualizuj w workflow `GODOT_VERSION` i `GODOT_SUMS_SHA512`,
czyli sumę SHA-512 pliku `SHA512-SUMS.txt` z wydania Godota.

## Jak działają przedmioty

- **Definicja** w `data/items/*.tres` opisuje rodzaj przedmiotu, a broń ma osobne parametry, model, smugę i dźwięk dla każdej klasy.
- **Wygląd** to `ItemVisual` z modelem, ikoną oraz punktami rękojeści i lufy, więc każdy model może mieć inny kształt.
- **Egzemplarz** to `ItemStack`, a cztery sloty każdego gracza trzyma serwer w `GameState`.
- **Zachowanie** to `ItemBehavior`. Nowy rodzaj przedmiotu dostaje własną definicję i zachowanie, bez zmian w kodzie sieciowym.
- **Stan w ręku** (aktywny slot, naboje, przeładowanie) jest w `Equipment`. Klient przewiduje go od razu, a serwer koryguje.

Po zmianie modelu przedmiotu odśwież ikony przez `tools/render_icons.gd`.

## Jak działa multiplayer

- **Serwer decyduje o wszystkim.** Klient wysyła tylko klawisze, kąt patrzenia i przycisk strzału.
- **Ruch** działa w pętli rollbacku netfox: klient przewiduje go od razu, a serwer ewentualnie koryguje.
- **Strzały** są rozliczane na serwerze. Klient widzi innych graczy z opóźnieniem, więc serwer cofa ich do chwili widocznej na ekranie strzelca, najwyżej o 0,3 s.
- **Sprint** zużywa pasek przez 4 s, a pasek odnawia się w 5 s po 1 s przerwy. Stan paska liczy serwer.
- **Zdrowie i wyniki** nie są stanem rollbacku. Serwer rozsyła je niezawodnym RPC z `game_state.gd`.
- **Animacje** nie idą przez sieć. Każdy klient wylicza je z ruchu gracza.

## Gdzie co jest

| Ścieżka | Zawartość |
|---|---|
| `scenes/world.tscn` | Mapa, edytowalna w Godocie |
| `scenes/player.tscn` | Postać gracza i konfiguracja synchronizacji |
| `scripts/player/player.gd` | Ruch, skok, respawn |
| `data/items/` | Definicje przedmiotów i parametry każdej klasy |
| `scripts/items/` | System przedmiotów: definicje, ekwipunek, zachowania |
| `scripts/player/equipment.gd` | Przedmiot w ręku i jego stan w sieci |
| `scripts/player/hitscan.gd` | Sprawdzanie trafień i rozmiary hitboksów |
| `scripts/core/game_state.gd` | Lista graczy, zdrowie, wyniki |
| `scripts/core/net.gd` | Serwer, łączenie, parametry startowe |
| `scripts/player/character_rig.gd` | Model i animacje innych graczy |
| `scripts/player/view_model.gd` | Broń i rękawice w pierwszej osobie |
| `scripts/world/` | Klocki mapy, zabawki, efekty |
| `scripts/ui/` | Menu, HUD i styl naklejek |
| `assets/` | Modele, broń i czcionka |

Klocki mapy zmieniasz polami **Size** i **Color** w inspektorze. Uwaga:
`tools/generate_world.py` nadpisuje `world.tscn`, więc po ręcznej edycji mapy
nie uruchamiaj go ponownie.

## Testy

```bash
godot --headless --path . -- --tool=res://tools/hitscan_test.gd
```

```bash
bash tools/bot_test.sh 25
```

```bash
godot --path . --resolution 1280x720 -- --tool=res://tools/flow_test.gd
```

Pierwszy test sprawdza trafienia, zasłony, punkty odrodzenia i śmierć. Drugi uruchamia
serwer z dwoma botami bez okien. Trzeci otwiera okno i sprawdza sterowanie, pauzę
oraz ponowne hostowanie. `tools/lag_proxy.py` pozwala dodać opóźnienie i utratę pakietów.

## Licencje

Kod i pozostałe własne pliki projektu są udostępnione wyłącznie do wglądu, a wszelkie
prawa są zastrzeżone. Szczegóły są w pliku [LICENSE](LICENSE). Licencje składników
innych autorów:

Addon [netfox](https://github.com/foxssake/netfox) jest na licencji MIT, a jego
tekst znajduje się w `addons/netfox/LICENSE`. Postacie [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers)
i [Kenney Blaster Kit](https://kenney.nl/assets/blaster-kit) są na licencji CC0.
Czcionka Fredoka jest na licencji SIL OFL. Pliki licencji leżą przy zasobach w `assets/`.
