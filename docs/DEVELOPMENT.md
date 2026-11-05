# Notatki deweloperskie

## Uruchamianie lokalnie

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_local.ps1 -Bots 2 -Shooters 1 -DebugItems
```

`-Bots` to biegające cele, `-Shooters` to boty strzelające do gracza, a `-DebugItems` daje każdemu dodatkowe bronie.

Serwer dedykowany: `godot --path . --headless -- --server --port=7777`, z otwartym portem 7777/UDP. Gotowy obraz buduje `Dockerfile`. Restart serwera rozłącza graczy i zeruje wyniki.

## Publikowanie wersji

Wydanie powstaje po wypchnięciu tagu `v*` z `main`, np. `git tag v0.6.0`, a potem `git push origin v0.6.0`. Workflow `.github/workflows/release.yml` buduje grę na Windows i macOS, uruchamia wersję na macOS na Macu z Apple Silicon i publikuje obie. Tag z myślnikiem, np. `v0.6.0-rc1`, tworzy wersję próbną.

Sam tag nie wdraża serwera, ale push na `main` zmieniający pliki gry już tak. Przed zmianą wersji Godota zaktualizuj w workflow `GODOT_VERSION` i `GODOT_SUMS_SHA512`.

Po zmianie sieci podnieś `PROTOCOL_VERSION` w `scripts/core/net.gd`.

## Struktura

| Ścieżka | Zawartość |
|---|---|
| `data/items/` | Definicje przedmiotów i parametry każdej klasy |
| `scripts/items/` | System przedmiotów: definicje, ekwipunek, zachowania |
| `scripts/player/` | Postać, broń w ręku, trafienia, animacje |
| `scripts/core/` | Sieć, stan gry, ustawienia, dźwięki |
| `scripts/ui/` | Menu, HUD i styl naklejek |
| `scripts/world/` | Teren, drzewa, ruiny i efekty |
| `scenes/world.tscn` | Mapa, edytowalna w Godocie |

`tools/generate_forest.py` nadpisuje `world.tscn`, więc po ręcznej edycji mapy nie uruchamiaj go ponownie. Wzór wysokości terenu jest w tym skrypcie i w `forest_terrain.gd`, a obie wersje muszą się zgadzać.

## Testy

Testy to skrypty w `tools/`, uruchamiane parametrem `-- --tool=res://tools/NAZWA.gd`: `items_test`, `hitscan_test` (bez okna), `inventory_test`, `pickup_test`, `map_test`, `character_test`, `aim_test`, `medkit_test`, `feel_test`, `flow_test`, `chest_test` z `--debug-chests`, `settings_test` z `--settings-path=user://test_settings.cfg` (w oknie). `tools/bot_test.sh`, `tools/hit_test.sh` i `tools/loot_test.sh` i `tools/chest_test.sh` sprawdzają sieć z botami, a `tools/lag_proxy.py` dodaje opóźnienie i utratę pakietów.

## Zasoby wizualne

- Ikony: `tools/render_icons.gd`, a potem `godot --headless --path . --import`.
- Ikona aplikacji: `tools/render_app_icon.gd` zapisuje `assets/app_icon.png` i `assets/app_icon.ico`.
- Zrzuty do README: `tools/readme_shots.gd` z `--dir=<ścieżka do docs/screenshots>`. Odśwież je po każdej zmianie wyglądu.

## Architektura

- **Serwer decyduje o wszystkim.** Klient wysyła klawisze, kąt patrzenia i przycisk strzału.
- **Ruch i broń w ręku** działają w pętli rollbacku netfox: klient przewiduje je od razu, a serwer ewentualnie koryguje.
- **Strzały** rozlicza serwer. Klient widzi innych graczy z opóźnieniem, więc serwer cofa ich do chwili widocznej na ekranie strzelca, najwyżej o 0,3 s.
- **Zdrowie, wyniki i zawartość slotów** nie są stanem rollbacku. Serwer rozsyła je niezawodnym RPC z `game_state.gd`.
- **Przedmioty na ziemi** są w `world_items.gd`. Klient tylko prosi o podniesienie lub wyrzucenie, a serwer sprawdza zasięg i egzemplarz. Wygląd jest w `pickup_field.gd` i `pickup_view.gd`.
- **Skrzynki** są w `chests.gd`. Klient trzyma klawisz i pokazuje pasek, a serwer sam odlicza czas i losuje z `data/loot/chest.tres`. Miejsca to węzły `Marker3D` w grupie `chest_spots` w `world.tscn`. Kolizja skrzynek powstaje też na serwerze, bo ruch jest przewidywany.
- **Postacie** są w liście `ROSTER` w `character_assets.gd`. Szkielety to sam model, więc biorą animacje z `Knight.glb`, bo ich kości mają te same nazwy.
- **Przedmioty:** `ItemDefinition` opisuje rodzaj, `ItemVisual` wygląd, `ItemStack` egzemplarz, a `ItemBehavior` działanie. Nowy rodzaj przedmiotu nie wymaga zmian w kodzie sieciowym: apteczka to własna definicja i zachowanie.
- **Animacje** nie idą przez sieć. Każdy klient wylicza je z ruchu gracza.
