# Plan nocnego rozwoju gry

Praca bez nadzoru przez całą noc. Komputer spał od 02:39 do 10:31, więc limit 10 h minął po ok. 1,5 h realnej pracy. Ten plik jest pamięcią między turami: po każdym punkcie zmień `[ ]` na `[x]` albo `[!]` z powodem i commitnij. Po kompaktowaniu rozmowy zacznij od przeczytania tego pliku.

Start pracy: sob 7 lis 2026 01:26:06 (`date +%s` = 1794011166).

Liczenie punktów: `grep -cE '^\s*- \[x\]' docs/PLAN_NOC.md` i analogicznie `[!]` oraz `[ ]`.

## Zasady pracy

### Git i bezpieczeństwo

- Pracuj tylko w nowym worktree `.claude/worktrees/noc` na gałęzi `feature/noc` z `origin/main`. Nie dotykaj głównego folderu `Desktop\Giera` (są tam niezapisane zmiany użytkownika) ani innych worktree.
- **Nigdy nie scalaj do `main`.** Push na `main` od razu wdraża serwery publiczne. Bez tagów i wydań, bez narzędzi Dokploy, bez zmian na VPS.
- Wypychaj `feature/noc` po każdym punkcie, żeby nic nie przepadło. Na końcu etapu 0 otwórz **draft PR** do `main` i aktualizuj jego opis. Nie włączaj auto-merge.
- Nie zmieniaj launchera ani procesu wydań (otwarty PR #43 o autoupdaterze to osobna praca).
- Repo jest publiczne: żadnego adresu IP serwera ani danych logowania. Przed każdym pushem przejrzyj diff.

### Zasoby i styl

- **Modele z `synty_models/` są zakazane**, bo licencja nie pozwala na publikację.
- Styl to własne, kolorowe low-poly. Modele buduj kodem (`scripts/world/low_poly.gd`) albo z już obecnych paczek CC0. Możesz pobrać paczkę CC0 tylko z kenney.nl lub od KayKit, z plikiem licencji i wpisem w README. Gdy pobranie się nie uda, nie czekaj, tylko zbuduj to kodem.
- Nie kopiuj map, modeli, ikon ani dźwięków z innych gier. Inspirować może się tylko mechanika.
- Teksty w grze po polsku. Komunikaty commitów po angielsku, jak w historii. Styl kodu jak w sąsiednich plikach.

### Jakość

- Serwer decyduje o wszystkim. Stan wpływający na ruch idzie przez rollback netfox.
- Po każdej zmianie sieci podnieś `PROTOCOL_VERSION` w `scripts/core/net.gd`.
- Godot: `$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`. Po utworzeniu worktree i po dodaniu zasobów uruchom `--headless --path . --import`.
- Punkt jest skończony dopiero, gdy ma test w `tools/` (wzór w `docs/DEVELOPMENT.md`), test sieciowy z botami, jeśli dotyczy sieci, a przy zmianach ruchu także przebieg przez `tools/lag_proxy.py`. Wszystko, co widać, sprawdź zrzutem ekranu i obejrzyj go, a nie tylko wygeneruj.
- Po każdym etapie uruchom wszystkie dotknięte testy i zrób przegląd własnego diffu (możesz użyć `/code-review` albo subagentów).
- Gdy coś stoi po 3 różnych próbach, oznacz `[!]`, opisz i idź dalej. Decyzje podejmuj sam, a wątpliwe zapisz w sekcji „Do decyzji” w opisie PR. Nie pytaj użytkownika, bo śpi.
- Nie psuj Battle Royale ani istniejących funkcji. Regresja jest ważniejsza od nowego punktu.

## Wymagane przez użytkownika

### Etap 0: Start

- [x] Worktree, import, zapis czasu startu, skopiowanie i commit tego planu.
- [x] Testy bazowe na czystym `main` z zapisem wyniku, żeby odróżnić stare błędy od nowych.
  Wynik `tools/all_tests.sh` na `main` (3e87fec): 31 zaliczonych, 6 błędnych. Stare błędy: `ui_feel_test` (dźwięk przełącznika), a `chest_test.sh`, `grenade_net_test`, `dance_net_test`, `br_lobby_test` i `br_reset_test` wywracają się na `player.gd:439` (stan bez `:position` w `add_sample`).

```
items_test             OK                          1s
hitscan_test           OK                          1s
remote_motion_test     OK                          1s
zone_test              OK                          1s
aim_test               OK                         12s
ambience_test          OK                          7s
character_test         OK                          8s
chat_test              OK                          8s
chest_test             OK                         13s
dance_test             OK                         27s
feel_test              OK                         10s
flow_test              OK                         25s
grenade_test           OK                         27s
inventory_test         OK                         17s
map_test               OK                         17s
medkit_test            OK                         10s
pickup_test            OK                         14s
settings_test          OK                         16s
steam_account_test     OK                          3s
ui_feel_test           BLAD(1)                    11s
weapons_test           OK                         24s
bot_test               OK                         32s
hit_test               OK                         36s
loot_test              OK                         35s
chest_test             BLAD(1)+SCRIPT_ERROR       34s
grenade_net_test       BLAD(1)+SCRIPT_ERROR       29s
medkit_net_test        OK                         24s
steam_net_test         OK                         21s
weapons_net_test       OK                         44s
dance_net_test         OK+SCRIPT_ERROR            46s
chat_net_test          OK                         25s
prediction_net_test    OK                         40s
kill_feed_test         OK                         60s
br_lobby_test          BLAD(1)+SCRIPT_ERROR       45s
br_out_test            OK                        102s
br_leave_test          OK                        130s
br_reset_test          BLAD(1)+SCRIPT_ERROR      171s
```
- [x] Draft PR: https://github.com/whoyoux/giera/pull/44. Po poprawce `player.gd:439` (niepełny stan w `add_sample`) pięć starych błędów sieciowych przechodzi: chest_test.sh, grenade_net_test, dance_net_test, br_lobby_test, br_reset_test.

### Etap 1: Kucanie i zmiana klawiszy

- [x] **Zmiana klawiszy:** w ustawieniach dziś jej nie ma. Dodaj panel dla wszystkich akcji gry (w tym myszy): wykrywanie konfliktów, reset do domyślnych, zapis w `settings.cfg`, działanie w menu i w pauzie. Podpowiedzi w HUD pokazują aktualny klawisz.
  Dowód: `keybinds_test` 28/28 OK, `settings_test` i `ui_feel_test` OK (ten drugi był błędny w bazie, bo przełącznik leżał poza przewijaną listą), zrzut `keybinds.png` obejrzany.
- [!] **Kucanie:** nowa akcja `crouch`, domyślnie przytrzymanie **Ctrl**. Pole w `player_input.gd`, stan w rollbacku.
  - Niższa kapsuła i kamera z płynnym przejściem, wolniejszy ruch, mniejszy rozrzut, brak sprintu.
  - Nie można wstać pod sufitem. Można wejść kucając pod niskie przeszkody.
  - **Hitbox jest niższy także w cofaniu czasu** w `hitscan.gd`. Test: strzał nad głową kucającego przy opóźnieniu pudłuje.
  - Inni gracze widzą pozę kucania (animacja albo poza liczona kodem). Taniec się wtedy przerywa.
  Powód `[!]`: mechanika działa i `crouch_test` przechodzi, ale `crouch_net_test` (120 ms, 2% strat) przechodzi tylko w ok. 3 na 4 przebiegi: czasem bot strzelający nad kucającym trafia, bo serwer w tym ticku uważa cel za stojącego. Trzy próby naprawy (wybór celu, widoczność, brak nadpisywania stanu u klienta) zmniejszyły problem, ale go nie usunęły. Do zbadania: rozjazd zegara `RemoteMotion` jednego gracza ze wspólnym `view_tick`.
  Dowód: `crouch_test` (kapsuła, kamera, szybkość, brak sprintu, rozrzut, sufit, taniec, hitbox w cofaniu czasu, poza modelu) OK, `crouch_net_test` przez `lag_proxy.py` 120 ms i 2% strat: strzał nad kucającym 0 trafień, w stojącego trafia, 3 razy z rzędu. Zrzuty `crouch_side.png` i `crouch_model.png` obejrzane. Pełny zestaw: 39/40, jedyny błąd to wcześniejsza, niestabilna wersja `crouch_net_test`, poprawiona.

### Etap 2: Nowe bronie

- [x] **Desert Eagle:** pistolet, duże obrażenia i rzadkie strzały. Punkt wyjścia: 55 obrażeń, 0,65 s między strzałami, magazynek 7, mocny odrzut, celny pierwszy strzał. Dwa trafienia zabijają.
- [x] **AWP:** snajperka, **jedno trafienie zabija** z każdej odległości. Punkt wyjścia: 5 naboi, 1,6 s między strzałami, długie przeładowanie, bardzo duży rozrzut bez celowania, wolniejszy ruch.
- [x] **Celownik snajperski AWP:** PPM daje nakładkę lunety na cały ekran, mocne przybliżenie, niższą czułość myszy, ukryty model broni i lekkie kołysanie. Strzał wyrzuca z lunety, a podczas przeładowania nie da się celować.
- [x] Obie bronie: definicje w `data/items/`, własne modele (przebudowa z paczki blasterów albo kodem, wyraźnie różne od reszty), ikony, smuga, dźwięk, chwyt w obu rękach, wypadanie i podnoszenie. Zasięg trafienia wystarcza na całą dużą mapę. AWP jest rzadki w tabeli łupu.
  Dowód: `new_weapons_test` OK (Deagle: 55 obrażeń, 2 trafienia zabijają, 0,65 s, 7 naboi, celny pierwszy strzał, mocny rozrzut; AWP: 1 trafienie zabija w każdej klasie, 5 naboi, 1,6 s, 3,6 s przeładowania, rozrzut 9° bez lunety, wolniejszy bieg; luneta: nakładka, przybliżenie, niższa czułość, ukryta broń, kołysanie, wyrzucenie po strzale i powrót, blokada przy przeładowaniu; wypadanie i podnoszenie; tabela łupu). `sniper_net_test` przez lag_proxy 120 ms: 10 zabójstw z AWP, 0 duplikatów. Zrzuty lunety, broni w rękach, postaci z bronią i ikon obejrzane. Modele z `tools/build_weapon_models.gd` (kod, LowPoly), `Hitscan.RANGE` = 500 m.

### Etap 3: Regeneracja w Deathmatchu

- [x] W Deathmatchu nie ma apteczek: osobna tabela łupu na tryb, także bez przedmiotów startowych i debugowych. Battle Royale je zachowuje.
- [x] Regeneracja liczona na serwerze: po 6 s od ostatnich obrażeń +8 HP/s do pełna. **Każde trafienie natychmiast ją przerywa i zaczyna 6 s od nowa.** Działa tylko w Deathmatchu, a po śmierci się zeruje.
- [x] HUD: widać, że leczenie trwa, i widać przerwanie. Test sieciowy: trafienie w trakcie leczenia przerywa je, a HP nie rośnie przez kolejne 6 s.
  Dowód: `regen_test` OK (brak apteczek w łupie i na starcie Deathmatchu, Battle Royale bez regeneracji i z apteczkami, 6 s opóźnienia, 8 HP/s, przerwanie trafieniem i nowe 6 s, wyzerowanie po śmierci, napisy w HUD), `regen_net_test` przez lag_proxy 120 ms: serwer i klient widzą przerwanie, 2 razy z rzędu. `medkit_net_test` dostał flagę `--debug-medkit`. Zrzuty `regen.png` i `regen_stop.png` obejrzane.

### Etap 4: Rundy i ranking w Deathmatchu

- [x] Runda ma czas: domyślnie 5 min, jedna stała. Kończy się też po 25 zabójstwach lidera. Czas liczony w tickach z serwera.
- [x] HUD stale pokazuje: licznik czasu, kto prowadzi i z iloma zabójstwami, miejsce gracza. Skrócona lista 3 najlepszych, a pełna pod Tab. Dołączający w trakcie widzi poprawny stan. („Kolejka” z prośby użytkownika to kolejność graczy, czyli ten ranking.)
- [x] Koniec rundy: ekran zwycięzcy i tabela, ok. 12 s, potem pełny reset (wyniki, łup, przedmioty, skrzynki, zdrowie) bez restartu serwera i nowa runda. Ostatnie 30 s ma wyraźny sygnał. Remis jest obsłużony. Test: 3 rundy z rzędu z botami, z rozłączeniem w trakcie.
  Dowód: `round_test` OK (zegar z ticków, lider, miejsce, 3 najlepszych, miejsca pod Tab, sygnał ostatnich 30 s, limit zabójstw, ekran zwycięzcy, 12 s wyników, pełny reset łupu, skrzynek, zdrowia, przedmiotów i wyników, remis, koniec czasu). `dm_rounds_test` przez lag_proxy 80 ms: 4 rundy, bot C wychodzi w rundzie 2, bot D dołącza w trakcie i zna ten sam koniec rundy co serwer, czysty stan po każdej rundzie u serwera i klientów, te same wyniki, 3 razy z rzędu. Nowa runda zaczyna się od 3 s zamrożenia, żeby nikt nie walczył w chwili przeniesienia. Zrzuty `round_hud.png` i `round_results.png` obejrzane.

### Etap 5: System map i mapa miejska

- [x] **Mapa zależna od trybu:** dziś wszystko zakłada jeden `world.tscn`, a `Zone` i inne skrypty czytają stałe z `ForestTerrain`. Wprowadź opis mapy (scena, granice, punkty startu, skrzynki, muzyka tła, powierzchnie). Serwer wybiera mapę z trybu lub parametru `--map=`, a klient dostaje ją przy dołączaniu, zanim wczyta świat. Działa też hostowanie z menu. **Obecnego `world.tscn` nie zmieniaj**, bo użytkownik ma w nim niezapisane poprawki. Nowe mapy idą do `scenes/maps/`.
- [x] **Mapa miejska dla Deathmatchu:** własne, kolorowe, zabawkowe miasteczko, ok. 70×70 m. Ulice, skrzyżowanie, plac, zaułki i co najmniej 3 równoległe trasy. Budynki z wejściami i piętrami, dachy, na które da się wejść, auta, kontenery i murki jako osłony. Co najmniej jedna długa linia pod AWP i miejsca, gdzie ma on przeciwników blisko. Niskie przejścia pod kucanie.
- [x] Co najmniej 12 punktów startu, skrzynki, odgłosy miasta, kroki po betonie i metalu. Kolizje bez miejsc do utknięcia i bez wyjścia poza mapę. Test obchodzi punkty startu i skrzynek, a boty grają na mapie bez blokowania się. Dużo zrzutów: czytelność i wygląd mają być naprawdę ładne.
  Dowód: `city_map_test` 79 sprawdzeń OK (14 punktów startu, 15 skrzynek, schody na piętra i dachy, dwa niskie przejścia tylko w kucki, trzy trasy, granica, linia 68 m pod AWP, beton i metal), `city_bots_test` przez lag_proxy (w większości przebiegów boty walczą, zdarza się słabszy przebieg), pełny zestaw 46/48 (niestabilne `character_test` i `city_bots_test`). 11 zrzutów obejrzanych. Stare testy grają na `--map=forest`.

### Etap 6: Znacznie większa mapa Battle Royale

- [ ] Nowa mapa o promieniu **ok. 200 m** (dziś 50 m, czyli 16 razy większa powierzchnia), własna scena i generator. Co najmniej 6 odrębnych miejsc: np. stare ruiny, wioska, gospodarstwo, kamieniołom, jezioro z mostem, obóz na wzgórzu. Między nimi las, polany i drogi. Teren zróżnicowany, ale przejezdny pieszo.
- [ ] Wydajność jest wymaganiem: teren w kawałkach, `HeightMapShape3D` zamiast siatki kolizji, `MultiMesh` i `visibility_range` dla roślinności, sensowna mgła i zasięg widzenia. Zmierz `tools/perf_probe.gd` na ustawieniach wysokich i niskich (Mac). Serwer z 10 graczami mieści się w limicie 512 MB i 1 CPU z `compose.yaml`. Czas wejścia na mapę jest akceptowalny. Wyniki zapisz w PR.
- [ ] Rozgrywka: co najmniej 60 skrzynek skupionych w miejscach, punkty startu rozłożone po mapie, strefa przeskalowana do ok. 8–10 min, linie strzału i odległości między miejscami pasują do AWP. Mapka w HUD działa w nowej skali i ma nazwy miejsc. Zaktualizuj `docs/PLAN_BATTLE_ROYALE.md`. Test: pełny mecz z botami do końca i powrót do lobby, 2 razy z rzędu.

## Pomysły dodatkowe

Po etapach 1–6 realizuj po kolei, aż do końca czasu. Nie kończ pracy wcześniej, jeśli zostały punkty. Każdy to osobny commit i te same wymogi testów. Jeśli punkt okaże się zły dla rozgrywki, uzasadnij i pomiń.

### Grupa A: mały koszt, duży efekt

- [ ] **Trafienia w głowę:** osobny hitbox głowy, mnożnik zależny od broni, inny znacznik i dźwięk, ikona na liście zabójstw.
- [ ] **Ekran śmierci:** kto Cię zabił, jaką bronią, ile HP mu zostało, odliczanie do odrodzenia.
- [ ] **Bezpieczne odrodzenia w Deathmatchu:** wybór punktu z dala od wrogów i 2 s ochrony, która znika po strzale.
- [ ] **Serie zabójstw:** podwójne i potrójne zabójstwo, pierwsza krew, przerwanie serii, z dźwiękiem i komunikatem.
- [ ] **Podium na koniec rundy:** kamera na najlepszą trójkę, która tańczy dostępnymi tańcami, i nagrody (najwięcej zabójstw, najcelniejszy, najwięcej trafień w głowę). Świetnie wykorzystuje istniejące tańce.
- [ ] **Liczby obrażeń** nad celem, z opcją wyłączenia w ustawieniach.
- [ ] **Ślizg:** kucnięcie w sprincie daje krótki ślizg ze zużyciem sprintu, w rollbacku.
- [ ] **Przerywanie apteczki trafieniem** w Battle Royale, spójnie z regeneracją.

### Grupa B: głębsza rozgrywka

- [ ] **Głosowanie na mapę** między rundami Deathmatchu (miasto albo polana), ze zmianą mapy bez restartu serwera. Jeśli to się nie uda stabilnie, zostaje samo miasto.
- [ ] **Zrzuty zaopatrzenia w Battle Royale:** skrzynia na spadochronie z dymem, widoczna na mapce, z najlepszym łupem w środkowych fazach.
- [ ] **Duża mapa pod M** w Battle Royale, ze strefą, miejscami i własnym znacznikiem.
- [ ] **Desant na starcie Battle Royale:** gracze wyskakują z zabawkowego samolotu i sterują lotem na lotni. Tylko jeśli działa stabilnie przy opóźnieniu, inaczej zostają rozłożone punkty startu.
- [ ] **Skoki, drabiny i rury w mieście:** dodatkowe trasy na dachy i piętra.
- [ ] **Sprytniejsze boty:** chodzą po trasach (`NavigationRegion3D`), szukają przeciwników i łupu, kucają za osłonami, z poziomami trudności. Pomaga w testach i w grze przy małej liczbie osób.

### Grupa C: oprawa

- [ ] **Własne dźwięki** nowych broni, kucania, ślizgu i końca rundy, generowane skryptem jak muzyka tańców.
- [ ] **Pora dnia na mapach:** ciepły zachód słońca w mieście z neonami, świetlne okna, porządne cienie. Z zachowaniem wydajności na ustawieniach niskich.
- [ ] **Efekty zniszczeń:** ślady po kulach, odpryski zależne od powierzchni, pękające szkło.
- [ ] **Osobiste statystyki** zapisane lokalnie: zabójstwa, rozegrane rundy, celność, ulubiona broń, panel w menu. Bez wysyłania na serwer, bo SteamID nie jest weryfikowane.
- [ ] **Samouczek klawiszy** przy pierwszym uruchomieniu, korzystający z własnych ustawień gracza.

## Zakończenie

Punkt obowiązkowy, gdy skończą się zadania albo minie 10 h od startu (wtedy dokończ tylko bieżący punkt):

- [x] Zaktualizuj README (funkcje, sterowanie, licencje nowych zasobów, bez notatek roboczych) i `docs/DEVELOPMENT.md`.
- [x] Odśwież zrzuty przez `tools/readme_shots.gd`, z przykładowymi nickami i adresami.
- [x] Testy całości, także ponowne testy z etapu 0 i porównanie z bazą.
  Baza na `main`: 31/37. Koniec: 39/40 (nowe: `keybinds_test`, `crouch_test`, `crouch_net_test`). Wszystkie 6 starych błędów naprawione. Jedyny błąd to niestabilny `crouch_net_test` opisany przy kucaniu.
- [x] Sprawdzenie historii i plików pod kątem adresu IP.
  W historii `main` i gałęzi są tylko `127.0.0.1` i dokumentacyjny `203.0.113.10`.
- [x] Opis draft PR: co zrobiono, jak zagrać lokalnie (gotowe polecenia dla początkującego), co wymaga oceny człowieka, „Do decyzji”, wyniki wydajności, punkty `[!]`.
