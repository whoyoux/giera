# Notatki deweloperskie

## Uruchamianie lokalnie

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_local.ps1 -Bots 2 -Shooters 1 -DebugItems
```

`-Bots` to biegające cele, `-Shooters` to boty strzelające do gracza, `-DebugItems` daje każdemu dodatkowe bronie, a `-DebugWeapons` strzelby i nóż.

Serwer dedykowany: `godot --path . --headless -- --server --port=7777`, z otwartym portem 7777/UDP. Gotowy obraz buduje `Dockerfile`. Restart serwera rozłącza graczy i zeruje wyniki.

## Konto Steam

`bash tools/fetch_godotsteam.sh` pobiera wtyczkę do `addons/godotsteam/`. Nie ma jej w repo, bo zawiera biblioteki Steama. Bez niej gra działa z wpisanym nickiem. Po pierwszym pobraniu uruchom `godot --headless --path . --import`.

Gra używa testowej aplikacji Spacewar (`APP_ID` w `steam_account.gd`). Do testów służą `--fake-steam=Nazwa:ID` i `--no-steam`. Konta Steam nie ma też w trybie bez okna, z `--server`, `--bot` i `--name`.

SteamID podaje klient i nikt go nie weryfikuje, więc służy tylko do pokazania awatara. Nie opieraj na nim banów ani statystyk. Biblioteka Steama wypisuje SteamID do logu klienta, więc nie publikuj logów z prawdziwego konta.

## Publikowanie wersji

Wydanie powstaje po wypchnięciu tagu `v*` z `main`, np. `git tag v0.6.0`, a potem `git push origin v0.6.0`. Workflow `.github/workflows/release.yml` buduje grę na Windows i macOS, uruchamia wersję na macOS na Macu z Apple Silicon i publikuje obie. Tag z myślnikiem, np. `v0.6.0-rc1`, tworzy wersję próbną. Workflow wpisuje numer z tagu do `config/version`, a menu go pokazuje. W repo to pole zostaje ustawione na `dev`.

Gracz pobiera ZIP z launcherem z folderu `launcher/`, a launcher instaluje grę w `user://game`. Wydanie zawiera dla niego PCK, `runtime` i `manifest.json`, który tworzy `tools/make_manifest.py`. Launcher pobiera manifest z najnowszego wydania stabilnego. Manifest podpisuje klucz RSA z sekretu `UPDATE_SIGNING_KEY`, a klucz publiczny jest w `launcher/scripts/update_key.gd`. Launcher sam pobiera też nową wersję swojej logiki, o ile ma ten sam silnik. `launcher.tscn` i `bootstrap.gd` są w exe na stałe, więc ich zmiana wymaga nowego ZIP-a. Wersję próbną testujesz przez `Giera.exe -- --update-tag=v0.22.0-rc1`, a wydanie wycofujesz przez `gh release edit <starszy tag> --latest`. Zapis `ci-import-cache-godot-*.tar.gz` przenosi import modeli do następnego builda, bo import od zera zmieniałby wszystkie modele w PCK.

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

`bash tools/all_tests.sh [plik_wyniku] [filtr]` uruchamia po kolei wszystkie testy i zapisuje tabelę wyników, np. `bash tools/all_tests.sh tools/logs/wynik.txt 'crouch'`. Każdy test dostaje osobny, świeży plik ustawień.

Launcher: `godot --headless --path launcher --script res://tests/update_plan_test.gd` sprawdza decyzje, a `tools/launcher_test.py` cały przebieg na lokalnym serwerze wydań, z wyeksportowanym launcherem.

Testy to skrypty w `tools/`, uruchamiane parametrem `-- --tool=res://tools/NAZWA.gd`: `items_test`, `hitscan_test` (bez okna), `inventory_test`, `pickup_test`, `grenade_test`, `ambience_test`, `map_test`, `character_test`, `aim_test`, `medkit_test`, `weapons_test`, `feel_test`, `flow_test`, `chat_test`, `ui_feel_test`, `dance_test`, `chest_test` z `--debug-chests`, `settings_test` z `--settings-path=user://test_settings.cfg` (w oknie), `net_graph_test` z połączeniem do serwera (opis w pliku), `steam_account_test` z `--fake-steam=Kapitan:76561197960265729` albo `--no-steam`, `keybinds_test`, `crouch_test`. Podgląd pozy kucania robi `tools/crouch_preview.gd` z `--shot=<plik.png>`. `tools/bot_test.sh`, `tools/hit_test.sh` i `tools/loot_test.sh` i `tools/chest_test.sh`, `tools/grenade_net_test.sh`, `tools/steam_net_test.sh`, `tools/weapons_net_test.sh`, `tools/dance_net_test.sh`, `tools/chat_net_test.sh`, `tools/prediction_net_test.sh`, `tools/crouch_net_test.sh` sprawdzają sieć z botami, a `tools/lag_proxy.py` dodaje opóźnienie i utratę pakietów.

## Zasoby wizualne

- Ikony: `tools/render_icons.gd`, a potem `godot --headless --path . --import`.
- Ikona aplikacji: `tools/render_app_icon.gd` zapisuje `assets/app_icon.png` i `assets/app_icon.ico`.
- Ikony tańców: `tools/render_dance_icons.gd`, a potem `godot --headless --path . --import`.
- Muzyka tańców: `python tools/generate_dance_music.py`, a potem `godot --headless --path . --import`.
- Podgląd tańców na siatce: `tools/dance_preview.gd` z `--shot=<plik.png>` i opcjonalnie `--character=Skeleton_Minion`.
- Zrzuty do README: `tools/readme_shots.gd` z `--dir=<ścieżka do docs/screenshots>` i `--fake-steam=Kapitan:76561197960265729`. Odśwież je po każdej zmianie wyglądu.

## Architektura

- **Serwer decyduje o wszystkim.** Klient wysyła klawisze, kąt patrzenia i przycisk strzału.
- **Ruch i broń w ręku** działają w pętli rollbacku netfox: klient przewiduje je od razu, a serwer ewentualnie koryguje. Kontakt z ziemią jest stanem rollbacku (`Player.on_ground`), bo `CharacterBody3D` pamięta go tylko z ostatniej symulacji, a nie z ticku, do którego wracamy.
- **Strzały i ciosy** rozlicza serwer. Klient widzi innych graczy z opóźnieniem, więc serwer cofa ich do chwili widocznej na ekranie atakującego, najwyżej o 0,3 s.
- **Strzelba** to zwykła `WeaponDefinition` z `pellets` i `spread_degrees` w `WeaponStats`. Układ śrucin liczy `Hitscan.pellet_directions`. Śruciny jednego strzału dają jedno trafienie z sumą obrażeń.
- **Rozrzut** ustawiają pola z grupy „Rozrzut” w `WeaponStats`. Narost z serii (`spread_bloom`) i rozrzut ostatniego strzału (`shot_spread`) są stanem rollbacku w `Equipment`, a kierunek pocisku wynika z numeru ticku, więc serwer i klienci liczą to samo.
- **Nóż** to `MeleeDefinition` i `MeleeBehavior`. `Hitscan.melee` szuka celu w zasięgu i w stożku przed graczem, a `speed_scale` przyspiesza bieg.
- **Zdrowie, wyniki i zawartość slotów** nie są stanem rollbacku. Serwer rozsyła je niezawodnym RPC z `game_state.gd`.
- **Przedmioty na ziemi** są w `world_items.gd`. Klient tylko prosi o podniesienie lub wyrzucenie, a serwer sprawdza zasięg i egzemplarz. Wygląd jest w `pickup_field.gd` i `pickup_view.gd`.
- **Skrzynki** są w `chests.gd`. Klient trzyma klawisz i pokazuje pasek, a serwer sam odlicza czas i losuje z `data/loot/chest.tres`. Miejsca to węzły `Marker3D` w grupie `chest_spots` w `world.tscn`. Kolizja skrzynek powstaje też na serwerze, bo ruch jest przewidywany.
- **Postacie** są w liście `ROSTER` w `character_assets.gd`. Szkielety to sam model, więc biorą animacje z `Knight.glb`, bo ich kości mają te same nazwy.
- **Awatary:** `steam_account.gd` pobiera każdy raz i trzyma w pamięci. W interfejsie pokazuje je `avatar_view.gd`, a nad graczami `avatar_tag.gd`.
- **Przedmioty:** `ItemDefinition` opisuje rodzaj, `ItemVisual` wygląd, `ItemStack` egzemplarz, a `ItemBehavior` działanie. Nowy rodzaj przedmiotu nie wymaga zmian w kodzie sieciowym: apteczka to własna definicja i zachowanie. Efekty użycia, np. smugi, są w `ItemBehavior.show_fired`.
- **Tańce:** spis jest w `dance_catalog.gd`, a numer tańca idzie jako `Input:dance` i stan `Player:dance_id`. Serwer przerywa taniec, gdy widzi ruch, skok, strzał, celowanie, przeładowanie albo śmierć. Pozy są w `dance_clips.gd` jako funkcje uderzenia muzyki, a nogi liczy odwrotna kinematyka, więc stopy trzymają się ziemi. Muzyka jest w `dance_music.gd`, kamera w `dance_camera.gd`, a koło w `dance_wheel.gd`. Nowy taniec to wpis w `DANCES`, funkcja w `dance_clips.gd`, utwór w `generate_dance_music.py` i ikona.
- **Czat:** `chat.gd` tylko przekazuje wiadomości przez serwer, który czyści tekst i pilnuje limitu. Historia jest w `chat_panel.gd`, wyłącznie w pamięci klienta do końca sesji. Treści nie wolno wypisywać do logu. Podczas pisania kursor jest wolny, a to samo w sobie wyłącza sterowanie.
- **Klawisze:** lista akcji z nazwami jest w `Keybinds.ACTIONS` (`scripts/core/keybinds.gd`), a domyślne klawisze w `project.godot`. Zmiany trafiają do sekcji `bindings` w `settings.cfg` jako `key:<kod fizyczny>` albo `mouse:<przycisk>`. Nową akcję wystarczy dodać w obu miejscach. Podpowiedzi w HUD biorą nazwę z `Keybinds.label_of`, a `ActionChip` odświeża się sam po zmianie.
- **Kucanie:** `Input:crouch` i stany `Player:crouching` oraz `Player:crouch_amount` są w rollbacku. Kapsuła ma dwa kształty, `Standing` i `Crouched`, przełączane na początku ticku, a wstanie sprawdza wąska kapsuła nad głową. Serwer pamięta kucanie z ostatnich ticków (`crouch_at`), więc hitbox przy cofaniu czasu jest tak niski jak wtedy. Pozę liczy `CrouchModifier` po animacji biegu. W testach na serwerze postać przenosi `Player.teleport`, bo zwykłe ustawienie pozycji cofnąłby rollback.
- **Animacje** nie idą przez sieć. Każdy klient wylicza je z ruchu gracza.
