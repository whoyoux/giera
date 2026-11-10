# Plan: mniejszy lag i HUD, który nie zasłania gry

Audyt z 10.11.2026. Dokument ma dwie części: **wyniki** (co zmierzono i co jest nie tak) oraz **prompty** dla agentów. Każdy prompt jest samodzielny: wklejasz agentowi sekcję „Wspólny kontekst” i jeden pakiet.

## Jak tego użyć

| Pakiet | Co daje | Wielkość | Zależy od |
|---|---|---|---|
| SIEĆ-1 | Mniej danych przy trafieniach, mniejszy upload gracza, celniejsze trafienia | mały | – |
| SIEĆ-2 | Serwer udźwignie 16+ graczy, 4–5 razy mniej ruchu | duży | SIEĆ-1 |
| SIEĆ-3 | Jeden gracz z lagiem nie opóźnia obrazu wszystkim | średni | SIEĆ-2 |
| UI-1 | Wolny środek ekranu w walce | średni | – |
| UI-2 | Ekrany wyników i tabela nie zasłaniają podium | średni | – |
| UI-3 | Test, który pilnuje tego na przyszłość, i nowe zrzuty | mały | UI-1, UI-2 |

- Pakiety SIEĆ idą **po kolei** (ruszają te same pliki). UI-1 i UI-2 mogą iść **równolegle** ze sobą i z siecią. UI-3 na końcu.
- Najwięcej za najmniej: **SIEĆ-1** i **UI-1**. Najwięcej w ogóle: **SIEĆ-2**.
- Każdy pakiet to osobna gałąź i osobny PR.

## Wspólny kontekst (wklej każdemu agentowi)

```text
Pracujesz nad grą „Giera”: FPS multiplayer w Godot 4.7.2 (GDScript), sieć na dodatku netfox 1.35.3
(rollback, tickrate 30 Hz), transport ENet. Serwer dedykowany decyduje o wszystkim.

Przed pracą przeczytaj: docs/DEVELOPMENT.md (architektura i testy), docs/PLAN_SIEC_UI.md (diagnoza
i liczby wyjściowe), a przy pakietach UI także docs/UI.md.

Zasady pracy:
- Pracuj w osobnym worktree w .claude/worktrees/ na własnej gałęzi. Po utworzeniu worktree uruchom
  `godot --headless --path . --import`. Nie przełączaj gałęzi we wspólnym folderze projektu,
  bo pracują tam inne sesje.
- Godot: $LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe
- Najpierw napisz cały pakiet, testy uruchom raz na końcu. Po każdym kroku wystarczy sprawdzić,
  że gra się importuje i serwer startuje. Nie dopracowuj botów ani testów botów.
- Komentarze w kodzie po polsku bez znaków diakrytycznych, tak jak w reszcie projektu. Stałe zamiast
  liczb w kodzie. Nie zmieniaj plików w addons/netfox.
- Po każdej zmianie tego, co idzie przez sieć, podnieś PROTOCOL_VERSION w scripts/core/net.gd.
- Nie wpisuj adresu serwera do repo. Nie wypisuj treści czatu do logów.
- Styl interfejsu (naklejki, kolory, font) zostaje. Zmieniamy rozmiar i miejsce, nie wygląd.
- Okna testów otwieraj poza ekranem: `--position 20000,20000`.
- Na końcu: opisz w PR liczby przed i po (tym samym narzędziem, na tym samym komputerze),
  dopisz zmianę do docs/DEVELOPMENT.md i zrób commit. Nie wdrażaj na serwer.
```

---

# Część 1. Wyniki

## Sieć: pomiary wyjściowe

Narzędzie: `bash tools/net_load_test.sh <boty> <sekundy>` (serwer i boty na jednym komputerze, bez opóźnienia). Liczby z jednego komputera, na którym działało naraz do 17 procesów gry, więc czasy są zawyżone, ale proporcje są wiarygodne.

| Graczy | Serwer wysyła | Pakiety serwera | Pętla ticków serwera | Klient odbiera | Klient wysyła | Pętla ticków klienta |
|---|---|---|---|---|---|---|
| 4 | 73 KB/s | 520/s | 72 ms/s | 16 KB/s | 13,4 KB/s | 27 ms/s |
| 8 | 262 KB/s | 2 060/s | 190 ms/s | 33 KB/s | 13,5 KB/s | 45 ms/s |
| 16 | 1 150 KB/s | 8 000/s | 680 ms/s, najgorsza 93 ms | 70 KB/s | 13,7 KB/s | 125 ms/s |
| 16, bez stanów różnicowych (`--no-diff`) | 2 600 KB/s | 8 800/s | 350 ms/s | 163 KB/s | 21 KB/s | 135 ms/s |

Co z tego wynika:

- **Koszt rośnie z kwadratem liczby graczy.** Z 8 do 16 graczy ruch rośnie 4,4 raza, a czas serwera 3,6 raza. Serwer w `compose.yaml` ma limit 1 rdzenia. Przy 16 graczach pętla ticków zajmuje około 68% rdzenia, a pojedyncze klatki serwera trwają 50–90 ms (tick ma 33 ms). To jest lag dla wszystkich naraz. `MAX_CLIENTS` to 32, a przy 32 graczach serwer by nie nadążył.
- **Każdy stan gracza to osobny pakiet UDP.** Klient przy 16 graczach dostaje około 500 pakietów na sekundę, średnio 127 bajtów. Na każdy pakiet dochodzi 28 bajtów nagłówka IP/UDP, których licznik ENet nie widzi.
- **Połowa czasu serwera to kodowanie różnic w netfox.** Serwer koduje stan każdego gracza osobno dla każdego odbiorcy (16 × 16 × 30 razy na sekundę). Wyłączenie różnic zmniejsza czas z 680 do 350 ms/s, ale podwaja ruch, więc to nie jest rozwiązanie.
- **Upload gracza to stałe 13,5 KB/s** (291 bajtów na pakiet wejścia, 30 razy na sekundę). Sześć przycisków idzie jako sześć osobnych wartości po 8 bajtów, razy trzy kopie.

## Sieć: diagnoza

**S1. Stan innych graczy idzie przez netfox, osobno dla każdej pary gracz–odbiorca.** `scenes/player.tscn` ma 32 właściwości stanu w `RollbackSynchronizer`, a `scripts/core/players.gd:41` pokazuje każdy węzeł wszystkim graczom. Klient nie symuluje innych graczy (rysuje ich z `RemoteMotion`), więc potrzebuje od nich tylko pozycji, kierunku patrzenia i kilku liczb do efektów. Dostaje wszystko, razem ze staminą i amunicją, i przepuszcza to przez pętlę rollbacku (125 ms/s u klienta przy 16 graczach). To źródło kwadratowego kosztu. → SIEĆ-2

**S2. Jeden gracz z lagiem opóźnia obraz wszystkim.** Serwer wysyła stan gracza dopiero, gdy dostanie jego wejście (`rollback-history-transmitter.gd:119`). `RemoteMotion.advance_clock` (`scripts/player/remote_motion.gd:44`) ustawia wspólne opóźnienie widoku według **najwolniejszego** gracza. Gdy ktoś ma 150 ms w jedną stronę, wszyscy oglądają wszystkich o tyle później, plus stały zapas 3 ticków (100 ms). Skutki: więcej śmierci „za rogiem”, a powyżej 0,4 s (`Equipment.MAX_REWIND_SECONDS`) strzały przestają trafiać. → SIEĆ-3

**S3. Każde trafienie rozsyła cały opis gracza.** `GameState._broadcast` (`scripts/core/game_state.gd:567`) wysyła niezawodnym RPC cały słownik gracza (około 30 pól z nazwami, sloty, statystyki) do wszystkich przy każdej zmianie zdrowia. Regeneracja robi to 4 razy na sekundę na każdego leczącego się gracza. Niezawodne pakiety czekają w kolejce jeden za drugim, więc przy utracie pakietu duże wiadomości opóźniają znacznik trafienia. Odbiorca (`_store`) już umie przyjąć sam fragment. → SIEĆ-1

**S4. Wejście gracza jest duże.** 12 właściwości w `input_properties`, każdy przycisk osobno. Redundancja 3 kopii znosi utratę 2 pakietów z rzędu, a krótkie przerwy Wi-Fi bywają dłuższe. Gdy wejście nie dotrze, serwer zatrzymuje postać, a potem klient dostaje korektę (szarpnięcie). → SIEĆ-1

**S5. Cofanie czasu zaokrągla do całego ticku.** `RemoteMotion.view_tick()` zwraca `roundi(shown_tick)`, a `Player.position_at` bierze pozycję z całego ticku. Błąd to do pół ticku, czyli 16,7 ms: 16 cm przy sprincie (9,75 m/s) i 18 cm w ślizgu. Promień głowy to 34 cm, więc strzały w głowę biegnącego potrafią nie wejść. → SIEĆ-1

**S6. Tickrate 30 Hz** (domyślny w netfox, brak sekcji `netfox` w `project.godot`). Do rozważenia dopiero po SIEĆ-2, gdy serwer będzie miał zapas. Dziś 60 Hz podwoiłoby koszt, którego serwer już nie mieści.

Co działa dobrze i zostaje: przewidywanie własnego ruchu i broni, cofanie czasu przy strzale, rozrzut liczony z numeru ticku (bez przesyłania losowania), stan przez zawodne pakiety, wyłączone rozsyłanie wejścia do innych graczy, znaczniki trafień tylko od serwera.

## UI: pomiary wyjściowe

Narzędzie: `tools/hud_sizes_probe.gd` (opis w pliku). Włącza wszystko naraz i mierzy przy kilku rozmiarach okna. Ekran logiczny ma co najmniej 1280×720: na ekranach 4:3 i 5:4 rośnie wysokość, a na ultraszerokich szerokość. Współrzędne poniżej dotyczą 1280×720.

| Element | Miejsce (x, y) | Rozmiar | Uwaga |
|---|---|---|---|
| Podpowiedź „Przytrzymaj, aby otworzyć skrzynkę” | 425–854, 450–520 | 430×70 | 90 px pod celownikiem |
| „Ochrona po odrodzeniu” | 537–743, 420–446 | 206×26 | 60 px pod celownikiem |
| Napis o śmierci | 401–878, 292–428 | 477×136 | sam środek ekranu |
| Napis o serii | 453–827, 210–269 | 374×59 | |
| Baner („Twoja drużyna przegrywa”) | 466–814, 132–196 | 348×64 | |
| Lista zabójstw (5 wierszy) | 868–1256, 22–276 | 388×254 | styka się z licznikiem drużyny |
| Samouczek | 889–1256, 290–537 | 367×247 | zasłania mapkę na 170×123 px, 14 s |
| Mapka | 1082–1252, 414–584 | 170×170 | |
| Zegar rundy | 535–744, 18–124 | 209×106 | trzy linie, powtarza ranking |
| „Najlepsi” | 24–234, 72–186 | 210×114 | |
| Zdrowie | 26–346, 563–695 | 320×132 | |
| Pasek przedmiotów | 438–842, 596–688 | 404×92 | |

Gdy wszystko jest widoczne naraz, HUD zajmuje **46% ekranu i 34% jego środka** (środek to prostokąt 50% × 50%). Na ekranie ultraszerokim 34% i 20%.

## UI: diagnoza

**U1. Środkowa kolumna jest zajęta od góry do dołu.** Baner (132), seria (210), śmierć (292), ochrona (420), podpowiedź (450), nazwa przedmiotu (529), pasek (596). Podpowiedź skrzynki i „Ochrona po odrodzeniu” leżą w miejscu, w które gracz celuje. → UI-1

**U2. Lista zabójstw jest wysoka i szeroka.** Pięć wierszy po 46 px z awatarami zajmuje ćwierć prawej górnej części ekranu i przy długich nickach dochodzi do licznika drużyny (odstęp 0 px). → UI-1

**U3. Samouczek zasłania mapkę i prawą stronę ekranu przez 14 s pierwszej walki.** Test układu tego nie widzi, bo działa na mapie bez mapki. → UI-1

**U4. Plakietka z nickiem rośnie bez limitu.** `Label3D` ma stały `pixel_size`, więc z bliska nick jest większy niż głowa postaci (na `docs/screenshots/br_results.png` „Basia” zajmuje 200×70 px). → UI-1

**U5. Karta wyników Team Deathmatchu zasłania podium.** Ma 1108×378 px, czyli 52% wysokości ekranu, a z postaci na podium widać tylko nicki (`docs/screenshots/tdm_results.png`). Karta Deathmatchu ma 762×256 i jest w porządku. `docs/UI.md` w punkcie 6 tego zabrania, ale test sprawdza tylko Deathmatch. → UI-2

**U6. Karta wyników Battle Royale stoi na środku** i zasłania oglądanego zwycięzcę (`docs/screenshots/br_results.png`). → UI-2

**U7. Na ekranie wyników zostają lista zabójstw i mapka.** → UI-2

**U8. Tabela pod Tab nie zmieści wielu graczy.** Wiersz ma około 42 px (font 21, awatar 34, odstęp 8). Przy 16 graczach to ponad 700 px na ekranie 720, a serwer wpuszcza 32. To wyliczenie z kodu (`hud.gd:796`), nie ze zrzutu. → UI-2

**U9. Test układu ma luki.** `tools/hud_layout_test.gd` sprawdza tylko Deathmatch na leśnej mapie i tylko 1280×720. Nie zna liczników drużyn, mapki, elementów Battle Royale, wyników TDM ani zasady wolnego środka. → UI-3

Co jest w porządku: skalowanie na 4:3, 16:10 i ultraszerokich (nic nie wychodzi poza ekran), menu pauzy, wybór drużyny, koło tańców, luneta chowająca resztę HUD-u, suwak wielkości interfejsu.

---

# Część 2. Prompty

## SIEĆ-1: tanie poprawki

```text
Zadanie: cztery niezależne poprawki sieci. Diagnoza: docs/PLAN_SIEC_UI.md, punkty S3, S4, S5.
Najpierw zmierz stan wyjściowy: `bash tools/net_load_test.sh 8 30` i zapisz wynik.

A. Różnicowe rozsyłanie stanu gracza (scripts/core/game_state.gd)
   Dziś `_broadcast(id)` wysyła cały słownik `players[id]` przy każdej zmianie.
   - Serwer trzyma kopię tego, co ostatnio rozesłał: `_sent[id]` (głęboka kopia, bo `slots` to
     tablica słowników).
   - `_broadcast(id)` porównuje pola, wysyła przez `_sync_player` tylko zmienione i aktualizuje kopię.
     Gdy nic się nie zmieniło, nie wysyła nic. Sygnał `player_changed` na serwerze zostaje.
   - Pierwsze rozesłanie nowego gracza jest pełne (brak wpisu w `_sent`). `_sync_roster` dla
     dołączającego zostaje pełne. Wpis w `_sent` znika w `_on_peer_disconnected` i w `reset()`.
   - `_store` u klienta już łączy fragment z całością (`merge`), więc klient nie wymaga zmian.
     Sprawdź tylko, że żaden odbiorca sygnału `player_changed` nie zakłada kompletu pól.
   - Kolejność z `server_damage` zostaje: najpierw stan ofiary, potem `_announce_kill`.

B. Mniejsze wejście gracza (scripts/player/player_input.gd, scenes/player.tscn)
   - Przyciski `jump, use_primary, aim, sprint, reload, crouch` oraz `slot` (2 bity) i `dance`
     (4 bity) zapisz w jednej liczbie `buttons`. W `input_properties` zostają: `Input:move`,
     `Input:buttons`, `Input:yaw`, `Input:pitch` i tick widoku z punktu C.
   - Dotychczasowe nazwy zostają jako właściwości z getterem i setterem czytającymi bity z `buttons`,
     żeby `player.gd`, `equipment.gd`, zachowania przedmiotów i boty działały bez zmian.
     Netfox zapisuje i odtwarza tylko `buttons`.
   - Po zmianie zmierz upload klienta. Cel: najwyżej 7 KB/s (dziś 13,5). Jeśli się mieści, ustaw
     w project.godot `netfox/rollback/input_redundancy=5` (sekcja [netfox]) i zmierz jeszcze raz.
     Cel po zwiększeniu: najwyżej 10 KB/s.

C. Cofanie czasu z ułamkiem ticku
   (scripts/player/remote_motion.gd, player_input.gd, equipment.gd, player.gd, hitscan.gd)
   - `RemoteMotion.view_tick()` zwraca dziś `roundi(shown_tick)`. Wyślij wartość z ułamkiem
     (float, -1.0 gdy nie ma innych graczy).
   - `Equipment.rewind_tick` zwraca float i dalej ogranicza do MAX_REWIND_SECONDS.
   - `Player.position_at(tick: float)` i `crouch_at(tick: float)` interpolują liniowo między
     sąsiednimi tickami z historii. Gdy brakuje jednego z nich, zachowanie jak dziś.
   - `Hitscan.trace` i `Hitscan.melee` przyjmują float. Sprawdź wszystkie wywołania (granaty,
     zachowania broni, boty).

D. Porządek po zmianach
   - Podnieś PROTOCOL_VERSION.
   - Dopisz w docs/DEVELOPMENT.md (sekcja Architektura) po jednym zdaniu o A, B i C oraz opis
     `tools/net_load_test.sh` w sekcji Testy.

Poza zakresem: zmiana tego, co netfox wysyła o stanie graczy (to SIEĆ-2), tickrate, boty.

Gotowe, gdy:
- `tools/net_load_test.sh 8 30`: upload klienta spełnia cele z B, upload serwera nie wzrósł.
- Jedna runda na końcu: `bash tools/all_tests.sh tools/logs/siec1.txt 'hitscan|inventory|crouch|medkit|regen|round|weapons|features'`
  oraz `tools/hit_test.sh`, `tools/prediction_net_test.sh 60 2`, `tools/crouch_net_test.sh`,
  `tools/sniper_net_test.sh`, `tools/tdm_net_test.sh`. Wynik wklej do PR.
- W PR: tabela przed i po oraz opis, które pola `_sync_player` wysyła teraz przy trafieniu.
```

## SIEĆ-2: jedna migawka innych graczy na tick

```text
Zadanie: przestać wysyłać stan innych graczy przez netfox. Zamiast tego serwer wysyła każdemu
klientowi jeden mały pakiet na tick z upakowanym stanem wszystkich pozostałych graczy.
Diagnoza i liczby: docs/PLAN_SIEC_UI.md, sekcja „Sieć: pomiary wyjściowe” i punkt S1.
Wymaga scalonego SIEĆ-1. Najpierw zmierz stan wyjściowy: `bash tools/net_load_test.sh 8 30`
i `bash tools/net_load_test.sh 16 30`.

Dlaczego to bezpieczne: klient nie symuluje innych graczy. Rysuje ich z bufora RemoteMotion
(scripts/player/remote_motion.gd), a próbki bierze dziś z historii netfox w
`Player._show_remote_motion`. Rollback jest potrzebny tylko własnej postaci.

Projekt:
1. Widoczność netfox (scripts/core/players.gd, `_spawn`)
   Filtr `RollbackSynchronizer.visibility_filter` przepuszcza tylko właściciela postaci:
   stan gracza X przez netfox dostaje wyłącznie X. Przewidywanie i korekta własnej postaci
   zostają bez zmian.

2. Nowy autoload `PlayerSnapshots` (scripts/core/player_snapshots.gd, wpis w project.godot)
   Serwer, raz po pętli ticków (`NetworkTime.after_tick_loop`), buduje dla każdego klienta jeden
   `PackedByteArray` i wysyła go RPC w trybie `unreliable_ordered`:
   - nagłówek: tick serwera (u32), liczba rekordów (u8),
   - rekord na każdego innego gracza w grze, stałej długości, kodowany raz na tick i wklejany
     do pakietów wszystkich odbiorców (bez kodowania osobno dla każdej pary):
     numer gracza, o ile ticków stan jest starszy niż nagłówek (u8), pozycja (3 × i16, 1 cm),
     yaw (u16), pitch (i8 lub i16), crouch_amount (u8), flagi w jednym bajcie (sprinting, aiming,
     on_ground, ślizg), active_slot i dance_id w jednym bajcie, a do efektów: last_fire,
     last_throw, prime_tick, action_end (po u16, młodsze bity ticku) i shot_spread (u8).
   - Sprawdź zakresy: największa mapa (Dolina) musi mieścić się w i16 przy 1 cm. Jeśli nie,
     użyj 2 cm albo i32 dla x i z.
   - Numer gracza: krótki numer nadany przez serwer i zapisany w `players[id]` jest lepszy niż
     4-bajtowy peer_id. Jeśli to komplikuje, zostaw u32 i zanotuj to w PR.
   - Stan, a nie zdarzenia: wysyłamy „ostatni strzał był w ticku N”, a nie „strzelił”. Zgubiony
     pakiet naprawia następny. Odbiorca odtwarza pełny tick z młodszych bitów względem nagłówka.
   - Tick rekordu to ostatni tick, który serwer zasymulował dla tego gracza. Serwer symuluje
     gracza dopiero po dostaniu jego wejścia, więc różni gracze mają różne ticki. Ustal, skąd
     wziąć tę wartość (`sync.get_last_known_state()` albo własny licznik w `Player._rollback_tick`),
     i sprawdź to logiem na graczu z opóźnieniem (`tools/lag_proxy.py`).
   - Pakiet dla 32 graczy ma się mieścić w 1200 bajtach.

3. Odbiór u klienta (player_snapshots.gd, player.gd, equipment.gd)
   - Dla każdego rekordu znajdź węzeł gracza i wywołaj nową metodę, np.
     `Player.apply_remote_snapshot(tick, pola)`. Dodaje próbkę do `remote_motion` (dotychczasowe
     `add_sample`) i wpisuje pola do postaci i jej `Equipment` (sprinting, aiming, dance_id,
     on_ground, active_slot, last_fire, shot_spread, last_throw, prime_tick, action_end).
   - `_show_remote_motion` przestaje czytać `sync._states`.
   - `Equipment._after_tick_loop` dalej wykrywa zmianę `last_fire` i reszty, więc smugi, dźwięki,
     animacje przeładowania i rzutu działają jak dotąd. Sprawdź `active_stack()` dla cudzej
     postaci: porównuje uid slotu ze stanem rollbacku, którego klient już nie dostaje. Dla
     cudzych postaci bierz przedmiot wprost z `info.slots[active_slot]`.
   - Znajdź wszystko, co u klienta czyta stan rollbacku cudzej postaci (velocity do kroków
     i skoku, `is_sliding`, `stamina`, `equipment.charges`, kamera widza w spectator_camera.gd)
     i przełącz na dane z migawki albo wylicz z ruchu między próbkami.
   - Cudze węzły graczy u klienta nie powinny już przechodzić przez pętlę rollbacku. Sprawdź
     w narzędziu pomiarowym, czy czas pętli ticków klienta spadł. Jeśli netfox dalej odtwarza
     ich stan co tick, wyłącz to dla cudzych postaci bez zmian w addons/netfox.

4. Serwer i host z graczem
   Host (serwer z własną postacią) nie wysyła sobie migawki i widzi innych jak dotąd. Sprawdź
   oba tryby: serwer dedykowany i host.

5. Dołączanie i wychodzenie
   Rekord gracza, którego węzeł jeszcze nie istnieje u klienta, jest pomijany. Po wyjściu gracza
   rekord znika. Widz (in_match == false) nie potrzebuje rekordu.

6. Podnieś PROTOCOL_VERSION. Opisz migawkę w docs/DEVELOPMENT.md (sekcja Architektura).

Poza zakresem: zmiana opóźnienia widoku (SIEĆ-3), wysyłanie dalekich graczy rzadziej, tickrate,
zmiany w addons/netfox, zmiany w cofaniu czasu na serwerze.

Gotowe, gdy (ten sam komputer, pomiar przed i po w jednej sesji):
- 16 botów: upload serwera spada co najmniej 3 razy (dziś około 1150 KB/s), pakiety serwera co
  najmniej 4 razy (dziś około 8000/s), pętla ticków serwera co najmniej o 40% (dziś około
  680 ms/s), klient odbiera najwyżej 30 KB/s (dziś 70), pętla ticków klienta spada o połowę.
- Ręcznie, dwa okna i bot (`tools/run_local.ps1 -Bots 2 -Shooters 1 -DebugItems`): inni gracze
  ruszają się płynnie, widać ich strzały, przeładowanie, kucanie, ślizg, taniec, rzut granatem,
  zmianę broni, śmierć i odrodzenie. Kamera widza w Battle Royale działa.
- Jedna runda na końcu: `tools/hit_test.sh`, `tools/prediction_net_test.sh 60 2`,
  `tools/crouch_net_test.sh`, `tools/dance_net_test.sh`, `tools/grenade_net_test.sh`,
  `tools/weapons_net_test.sh`, `tools/sniper_net_test.sh`, `tools/tdm_net_test.sh`,
  `tools/br_valley_test.sh`, `tools/remote_motion_test` (przez all_tests.sh z filtrem).
- W PR: tabela przed i po dla 8 i 16 botów, rozmiar rekordu w bajtach, lista pól.

Jeśli w trakcie okaże się, że netfox nie pozwala ograniczyć stanu do właściciela bez zmian
w addons/netfox, zatrzymaj się i opisz przeszkodę w PR zamiast obchodzić ją łatką w dodatku.
```

## SIEĆ-3: opóźnienie widoku innych graczy

```text
Zadanie: jeden gracz ze słabym łączem nie może opóźniać obrazu wszystkim, a stały zapas ma być
mniejszy. Diagnoza: docs/PLAN_SIEC_UI.md, punkt S2. Wymaga scalonego SIEĆ-2.
Pliki: scripts/player/remote_motion.gd, scripts/ui/net_graph.gd, tools/remote_motion_test.gd.

Stan dziś: `RemoteMotion.advance_clock` liczy wspólne opóźnienie jako najkrótszą drogę stanu
NAJWOLNIEJSZEGO gracza plus BUFFER_TICKS = 3 (100 ms). Wspólny zegar musi zostać jeden, bo strzał
podaje serwerowi jeden tick widoku.

1. Pomiar najpierw
   Dodaj do wykresu sieci (net_graph.gd) trzecią linię tekstu: „Widok innych: X ms” (opóźnienie
   wspólnego zegara względem teraz). Zmierz na 4 botach, z których jeden łączy się przez
   `tools/lag_proxy.py` z opóźnieniem 150 ms w jedną stronę. Zapisz wartość dla gracza bez lagu.

2. Ograniczenie wpływu najwolniejszego
   Wspólne opóźnienie = min(najwolniejszy, mediana graczy + LAG_SPREAD_TICKS) + zapas.
   LAG_SPREAD_TICKS zacznij od 3. Gracz wolniejszy niż zegar jest pokazywany na swoim najnowszym
   stanie (`advance` już przycina `_tick` do `newest_tick`), więc porusza się skokami tylko on.
   Koszt, który trzeba opisać w PR: do takiego gracza serwer cofa czas mniej, niż widział
   strzelający, więc w biegnącego gracza z lagiem trzeba celować lekko z wyprzedzeniem.
   Cierpi jakość celu z lagiem, a nie wszystkich.

3. Zapas zależny od nierówności
   Zamiast stałych 3 ticków: zapas = odchylenie wieku próbek z okna AGE_WINDOW (różnica między
   95. centylem a minimum), ograniczone do zakresu 1,5–3 ticki. Na równym łączu daje to około
   50 ms mniej opóźnienia. Zmiana zapasu idzie przez istniejące LAG_ADAPT_SPEED, żeby obraz
   nie skakał.

4. Bezpieczniki
   - Nigdy nie pokazuj gracza przed jego najnowszą próbką (bez ekstrapolacji).
   - SNAP_TICKS i reszta stałych zostają, chyba że pomiar pokaże inaczej.

Poza zakresem: osobny tick widoku dla każdego celu, przewidywanie ruchu graczy na serwerze
(`enable_prediction`), tickrate.

Gotowe, gdy:
- W scenariuszu z punktu 1 opóźnienie widoku u gracza bez lagu spada do wartości bliskiej
  scenariuszowi bez wolnego gracza (różnica najwyżej 2 ticki). Liczby przed i po w PR.
- Na równym łączu (bez proxy) opóźnienie widoku jest mniejsze niż przed zmianą.
- Przy `lag_proxy` 40 ms i 3% strat inni gracze nie zacinają się częściej niż przed zmianą
  (ocena na oko w oknie gry plus `remote_motion_test`).
- Jedna runda na końcu: `tools/hit_test.sh`, `tools/sniper_net_test.sh`, `tools/crouch_net_test.sh`.

Po tym pakiecie zapisz w PR rekomendację co do tickrate 60 Hz: zmierz
`tools/net_load_test.sh 16 30` z `netfox/time/tickrate=60` ustawionym lokalnie (bez commita)
i podaj czas pętli ticków serwera. Decyzję podejmie właściciel projektu.
```

## UI-1: wolny środek ekranu w walce

```text
Zadanie: HUD w trakcie walki nie zasłania miejsca, w które gracz patrzy i celuje. Styl naklejek
zostaje, zmieniamy rozmiar i położenie. Diagnoza i współrzędne: docs/PLAN_SIEC_UI.md, tabela
„UI: pomiary wyjściowe” oraz punkty U1–U4. Przeczytaj docs/UI.md.
Pliki: scripts/ui/hud.gd, round_panel.gd, tutorial_panel.gd, match_panel.gd (tylko odliczanie
i kolumna boczna), scripts/player/player.gd (tylko funkcje plakietki z nickiem).
Nie ruszaj części match_panel.gd odpowiedzialnej za wyniki (robi to UI-2) ani
tools/hud_layout_test.gd (robi to UI-3).

Stan wyjściowy zmierz narzędziem `tools/hud_sizes_probe.gd` (użycie w nagłówku pliku) w trybach
deathmatch i team_deathmatch, ze zrzutami. Zrób to samo po zmianach.

Zasada: „strefa walki” to prostokąt na środku ekranu, 40% szerokości i 50% wysokości
(przy 1280×720: x 384–896, y 180–540). W strefie walki mogą być tylko: celownik, luneta,
wskaźnik kierunku obrażeń, liczby obrażeń, koło tańców i okna modalne (pauza, tabela, wybór
drużyny). Dodaj tę zasadę do docs/UI.md w punkcie 6.

1. Podpowiedź podnoszenia i skrzynki (`_build_prompt`, `_update_prompt`, `_show_chest_prompt`)
   Dziś 430×70 na y 450–520. Ma stać tuż nad paskiem przedmiotów, w miejscu nazwy przedmiotu
   (y około 529–570), mieć najwyżej 320 px szerokości i font 17. Tekst krótszy:
   „[E] Otwórz skrzynkę” z cienkim paskiem postępu, „[E] Podnieś <nazwa>”, „[E] Zamień na <nazwa>”.
   Nazwa przedmiotu po zmianie slotu nie pokazuje się, gdy widać podpowiedź. To samo miejsce
   i limit szerokości dla panelu użycia (`_build_use_panel`).

2. „Ochrona po odrodzeniu” (`_protection_label`)
   Znika ze środka. Pokaż ją jako linię w naklejce zdrowia, tak jak napis o leczeniu
   (`_regen_label`), w kolorze TEAL.

3. Jeden napis u góry naraz (round_panel.gd `_banner`, hud.gd `_streak_panel`,
   match_panel.gd `_big_panel`)
   Baner, seria i odliczanie dzielą jedno miejsce pod zegarem (y = 132). Nowy napis zastępuje
   poprzedni, a odliczanie ma pierwszeństwo. Baner i seria: font 19–22, szerokość najwyżej
   340 px, czas 2 s. Odliczanie zostaje przy 32 (docs/UI.md, punkt 1). Stała STREAK_TOP znika.

4. Napis o śmierci (`_death_panel`)
   Znika ze środka. Stoi w dolnej części ekranu nad paskiem przedmiotów (środek w poziomie,
   dolna krawędź około 560), font 19–22, dwie linie:
   „Zabija Cię <nick> w głowę · <broń> · zostało mu 45 HP” i „Wracasz za 3”.
   Pierwsza linia ma `clip_text` i limit szerokości 520 px. Nie może nachodzić na podpowiedź
   z punktu 1 (martwy gracz i tak jej nie widzi, sprawdź to).

5. Lista zabójstw (`_on_kill`, `_add_feed_row`, stałe FEED_*)
   Najwyżej 4 wiersze, awatar 20, font 15, nick do 12 znaków, margines wiersza 5, czas 4 s.
   Cel: cała lista najwyżej 300×150 px i co najmniej 16 px odstępu od licznika drużyny przy
   najdłuższych nickach.

6. Samouczek (tutorial_panel.gd, `Hud.show_tutorial`)
   Nie stoi już w prawej kolumnie nad mapką. Przenieś go do lewej kolumny pod „Najlepsi”
   (`_top_left`), jedna kolumna, najwyżej 7 najważniejszych wierszy, font 13–14, tak żeby
   kończył się nad czatem (y < 350). Znika po 14 s, po Enter albo gdy gracz pierwszy raz zada
   lub dostanie obrażenia (`GameState.hit_details`, `GameState.damaged`).

7. Zegar i ranking (round_panel.gd)
   - W Team Deathmatchu karta „Najlepsi” jest ukryta: wynik pokazują liczniki drużyn.
   - W Deathmatchu zegar ma dwie linie: czas oraz „Twoje miejsce: 1 z 4 · do 25”. Linia
     „Prowadzi X · 7” znika, bo to samo pokazuje „Najlepsi”.

8. Wyciszenie HUD-u przy celowaniu (hud.gd, `_process`)
   Gdy gracz celuje (`_player.aiming`, bez lunety, która i tak chowa wszystko), elementy poboczne
   płynnie (0,15 s) przechodzą do przezroczystości 0,35: „Najlepsi”, licznik FPS, wykres sieci,
   lista zabójstw, czat (gdy nie jest otwarty), samouczek. Zdrowie, amunicja, pasek przedmiotów,
   zegar i mapka zostają. Uwaga: `_update_clutter` ustawia `modulate.a` wszystkim dzieciom HUD-u,
   więc połącz to w jednym miejscu, żeby jedno nie nadpisywało drugiego.

9. Plakietki z nickami (player.gd: `name_label`, `_tag_root`, `_update_crouch_view`,
   `set_name_tag_visible`)
   Plakietka nie rośnie w nieskończoność z bliska: poniżej 10 m od kamery jej rozmiar na ekranie
   przestaje rosnąć (skaluj węzeł proporcjonalnie do odległości), a między 3 m a 1,5 m płynnie
   znika. Dotyczy nicku i awatara. Kamerę bierz z `get_viewport().get_camera_3d()`, żeby działało
   też u widza. W Team Deathmatchu plakietka sojusznika widoczna przez ściany zostaje.

Poza zakresem: ekrany wyników i tabela Tab (UI-2), test układu i zrzuty README (UI-3), wygląd
naklejek, menu główne, ustawienia.

Gotowe, gdy:
- `tools/hud_sizes_probe.gd` w obu trybach: żaden element poza dozwolonymi nie wchodzi w strefę
  walki, brak komunikatów NAKLADANIE poza parami, które nie mogą wystąpić naraz, pokrycie
  środka ekranu spada z 34% poniżej 8%, a całego ekranu z 46% poniżej 30%.
  Dopisz do narzędzia sprawdzenie strefy walki, jeśli ułatwi to pomiar.
- Zrzuty 1280×720 przed i po w PR: walka w Deathmatchu, Team Deathmatch z banerem, otwieranie
  skrzynki, ekran śmierci, pierwsze wejście z samouczkiem, gracz z bliska (plakietka).
- Rozmiary tekstu zgodne z tabelą w docs/UI.md, punkt 1.
```

## UI-2: wyniki i tabela nie zasłaniają podium

```text
Zadanie: ekrany końca rundy i tabela wyników mieszczą się na ekranie i nie zasłaniają tego, na co
gracz ma patrzeć. Diagnoza: docs/PLAN_SIEC_UI.md, punkty U5–U8. Przeczytaj docs/UI.md.
Pliki: scripts/ui/match_panel.gd (wyniki), scripts/ui/podium_view.gd, scripts/ui/hud.gd
(tylko `_update_clutter`, `_refresh_scoreboard` i funkcje tabeli).
Nie ruszaj reszty hud.gd (robi to UI-1) ani tools/hud_layout_test.gd (robi to UI-3).

Zrzuty wyjściowe: `tools/tdm_shots.gd --dir=<folder>` (z `--dm` dla Deathmatchu) i zrzuty
Battle Royale z `tools/br_shots.gd`. Zrób to samo po zmianach.

1. Karta wyników Team Deathmatchu (`_fill_team_results`, `_fill_round_stats`, `_place_results`)
   Dziś 1108×378 px (52% wysokości ekranu) i zasłania postacie na podium. Wymaganie: karta ma
   najwyżej 33% wysokości ekranu, a postacie na podium widać w całości przy 1280×720 i 1280×800.
   Proponowany sposób:
   - sekcja „Twoja runda” przestaje być osobnym rzędem na dole. Zostaje jedna linia w lewej części
     („2 zabójstwa · 1 śmierć · 29% celności · 223 obrażeń”), a pełne liczby ze strzałkami
     przechodzą pod Tab, na dół tabeli wyników,
   - listy drużyn w karcie: najwyżej 3 graczy na drużynę (TEAM_ROWS), reszta pod Tab,
   - jeśli po tym karta wciąż dotyka postaci, podnieś kadr podium w podium_view.gd tak, żeby
     postacie stały w górnych 60% ekranu.
   To samo ograniczenie wysokości ma karta Deathmatchu (dziś je spełnia, nie może się pogorszyć).

2. Karta wyników Battle Royale (`_place_results`, `_refresh_results`)
   Dziś stoi na środku i zasłania oglądanego zwycięzcę. Ma stać przy dolnej krawędzi, tak jak
   karta podium Deathmatchu (ten sam układ: mały nadtytuł, zwycięzca, lista miejsc, licznik
   powrotu do lobby). Podpowiedź „Oglądasz: X” (`_watch_panel`) na czas wyników znika albo
   stoi nad kartą, bez nakładania.

3. Mniej elementów na ekranie wyników (hud.gd `_update_clutter`)
   W fazie RESULTS znikają także: lista zabójstw, mapka, „Najlepsi”, zegar rundy i samouczek.
   Zostaje karta wyników, licznik FPS (jeśli włączony) i czat.

4. Tabela pod Tab (hud.gd: `_refresh_scoreboard`, `_score_row`, `_refresh_team_scoreboard`)
   Serwer wpuszcza 32 graczy, a wiersz ma około 42 px, więc tabela wychodzi poza ekran już
   w okolicach 16 graczy. Wymaganie: tabela mieści się na 1280×720 przy 32 graczach.
   - font wierszy 17 zamiast 21, awatar 26, odstęp 4,
   - powyżej 12 graczy dwie kolumny obok siebie (miejsca 1–16 i 17–32), własny wiersz zawsze
     wyróżniony,
   - w Team Deathmatchu każda drużyna ma do 16 graczy w kolumnie, więc ten sam mniejszy wiersz,
   - na dole tabeli sekcja „Twoja runda” przeniesiona z karty wyników (punkt 1), widoczna tylko
     w fazie RESULTS.
   Sprawdź sztucznie dodanymi graczami (`GameState.server_add_player` w narzędziu, tak jak robi
   to tools/hud_layout_test.gd), bo 32 botów nie trzeba uruchamiać.

Poza zakresem: HUD w trakcie walki (UI-1), test układu i zrzuty README (UI-3), głosowanie na mapę
(zostaje, jak jest), zasady rundy.

Gotowe, gdy:
- Zrzuty 1280×720 przed i po w PR: wyniki TDM, wyniki DM, wyniki BR, tabela Tab z 8, 16
  i 32 graczami, tabela TDM z 16 graczami.
- Karta wyników w każdym trybie: wysokość najwyżej 33% ekranu, dolna krawędź na ekranie,
  postacie podium (TDM, DM) i oglądany zwycięzca (BR) widoczni.
- Tabela Tab z 32 graczami mieści się w 1280×720 z marginesem co najmniej 16 px.
```

## UI-3: test układu, zasady i zrzuty

```text
Zadanie: test, który pilnuje ustaleń z UI-1 i UI-2, dopisane zasady i świeże zrzuty.
Wymaga scalonych UI-1 i UI-2. Diagnoza: docs/PLAN_SIEC_UI.md, punkt U9.
Pliki: tools/hud_layout_test.gd, tools/hud_sizes_probe.gd, docs/UI.md, docs/DEVELOPMENT.md,
docs/screenshots, README.md (tylko jeśli zmieniają się nazwy zrzutów).

1. Rozszerz tools/hud_layout_test.gd
   - Tryby: Deathmatch, Team Deathmatch (liczniki drużyn, baner, mapka) i Battle Royale
     (pasek żywych i strefy, „Jesteś poza strefą”, mapka, lista gotowych w lobby, podpowiedź
     widza). Tryb podaje flaga, a all_tests.sh uruchamia test trzy razy. Logikę wymuszania
     widoczności możesz przenieść z tools/hud_sizes_probe.gd.
   - Rozmiary okna: 1280×720, 1280×800, 1720×720, każdy przy skali interfejsu 0,6 i 1,0.
   - Nowe sprawdzenia:
     a) strefa walki (środek 40% × 50% ekranu) jest wolna od wszystkiego poza listą dozwolonych
        elementów z docs/UI.md,
     b) elementy stale widoczne w walce zajmują razem najwyżej 20% ekranu,
     c) lista zabójstw przy najdłuższych nickach ma co najmniej 16 px odstępu od sąsiadów,
     d) samouczek nie nachodzi na mapkę ani czat,
     e) karta wyników w każdym trybie ma najwyżej 33% wysokości ekranu,
     f) tabela Tab z 32 sztucznymi graczami mieści się na ekranie.
   - Lista par EXCLUSIVE ma zawierać tylko pary, które naprawdę nie występują naraz. Usuń pary,
     które po UI-1 dzielą jedno miejsce z kolejką (baner, seria, odliczanie), i sprawdź kolejkę
     osobno: po wywołaniu dwóch napisów widać jeden.

2. docs/UI.md, punkt 6
   Dopisz liczby: definicję strefy walki i listę dozwolonych w niej elementów, limit 20%
   pokrycia w walce, limit 33% wysokości karty wyników, limity listy zabójstw, wymóg 32 graczy
   w tabeli oraz to, że nowy element HUD-u wymaga dopisania do testu.

3. Zrzuty do README
   Odśwież docs/screenshots (`tools/readme_shots.gd`, `tools/tdm_shots.gd`, zrzuty BR)
   i sprawdź, że README pokazuje aktualny wygląd. README to wizytówka: bez notatek roboczych.

4. Jedna runda wszystkich testów na końcu: `HIDE_WINDOWS=1 bash tools/all_tests.sh
   tools/logs/ui3.txt`. Testy, które padły z powodu przeniesionych elementów HUD-u
   (np. flow_test, round_test, features_test), popraw. Wynik wklej do PR.

Poza zakresem: dalsze zmiany wyglądu. Jeśli test wykryje naruszenie zasad, popraw je tylko wtedy,
gdy to drobna zmiana położenia. Większe opisz w PR.
```

## Po wszystkim

- Po SIEĆ-2 i SIEĆ-3 warto wrócić do tickrate 60 Hz (S6). SIEĆ-3 kończy się pomiarem, który pozwoli zdecydować.
- Dalsze oszczędności, jeśli będą potrzebne: rzadsze wysyłanie graczy dalej niż 60 m, osobny kanał ENet dla czatu i przedmiotów.
- `MAX_CLIENTS = 32` zostaje bez zmian, dopóki pomiar po SIEĆ-2 nie pokaże, ile graczy serwer naprawdę mieści na 1 rdzeniu.
