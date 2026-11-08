# Plan nocy 2

Kopia zadania z PROMPT_NOC_2.md. Pamięć między turami: po każdym punkcie `[x]` albo `[!]` z powodem, commit i push. Po kompaktowaniu zacznij od tego pliku.

Start: Sun 08 Nov 2026 01:59 (`date +%s` = 1794099588). Gałąź `feature/noc-2` w worktree `noc-2-30b822`. Testy bazowe idą w osobnej kopii `origin/main` w scratchpadzie, żeby edycje nie mieszały wyniku.

## Status startu

- [x] Keep-awake: wywołanie odrzucone przez klasyfikator uprawnień, użytkownik sam wyłączył usypianie.
- [x] Lektura dokumentów i kodu, gałąź `feature/noc-2`, import Godota.
- [ ] Testy bazowe (wynik poniżej).
- [ ] Draft PR.

## 1. Zasady, których nie wolno złamać

- **Nigdy nie scalaj do `main` i nie pushuj na `main`.** Push na `main` od razu wdraża serwery publiczne. Bez tagów, wydań, narzędzi Dokploy i zmian na VPS. Bez auto-merge.
- Repo jest publiczne: żadnego adresu IP serwera ani danych logowania w kodzie, commitach, opisie PR i zrzutach. Przed każdym pushem przejrzyj diff.
- Nie zmieniaj launchera ani procesu wydań (`.github/workflows`, `launcher/`).
- **Bez zrzutu z samolotu, desantu ani lotni w Battle Royale.** Użytkownik wprost tego nie chce.
- **Nie odtwarzaj istniejących gier.** Mapa pustynna ma być własnym projektem, a nie kopią znanych map pustynnych z innych strzelanek (układ, nazwy miejsc, charakterystyczne budynki). Inspirować może tylko klimat i mechanika.
- Modele z `synty_models/` są zakazane (licencja). Styl to własne, kolorowe low-poly: modele kodem (`scripts/world/low_poly.gd`, wzór w `scripts/maps/city_builder.gd` i `valley_builder.gd`) albo z paczek CC0 już w repo. Nową paczkę CC0 możesz pobrać tylko z kenney.nl lub od KayKit, z plikiem licencji i wpisem w README. Gdy pobranie się nie uda, nie czekaj, tylko zbuduj to kodem.
- Teksty w grze po polsku. Commity po angielsku, w stylu historii. Kod w stylu sąsiednich plików.
- Serwer decyduje o wszystkim. Stan wpływający na ruch idzie przez rollback netfox. Po każdej zmianie sieci podnieś `PROTOCOL_VERSION` w `scripts/core/net.gd`.
- UI zgodne z `docs/UI.md` (tabela fontów, skala odstępów 4–24, co najmniej 12 px od krawędzi karty, stany hover/zaznaczenia). Każdy nowy ekran sprawdź zrzutem 1280×720 i **obejrzyj** go narzędziem Read, a nie tylko wygeneruj.
- Nie psuj Deathmatchu ani Battle Royale. Regresja jest ważniejsza od nowej funkcji.

## 2. Sposób pracy

- **Najpierw funkcje, testy na końcu.** Po każdym punkcie tylko szybkie sprawdzenie: import bez błędów, start serwera bez okna, jeden zrzut, jeśli zmiana jest widoczna. Pełna runda testów jest raz, w sekcji 5. Nie pisz testów po każdym kroku.
- **Nie dopracowuj botów.** Użytkownik z nich nie korzysta. Boty mają tylko dostać drużynę, żeby dało się przetestować TDM.
- Gdy coś stoi po 3 różnych próbach, oznacz `[!]`, opisz w planie i idź dalej.
- Długie polecenia (testy, eksport) uruchamiaj w tle.
- Godot: `$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe` (sprawdź, czy wersja się nie zmieniła).
- Kolejność etapów poniżej jest celowa: mapa pustynna potrzebuje punktów startu drużyn, więc TDM idzie pierwszy.

## 3. Wymagane przez użytkownika

### Etap 1: Team Deathmatch

- [x] **Nowy tryb** `TEAM_DEATHMATCH` w `GameMode` („Team Deathmatch”, podpowiedź po polsku), własny port **7779** i wpis `team-deathmatch` w `compose.yaml` (jeden serwer na tryb, jak pozostałe). Karta trybu w menu głównym obok Deathmatchu i Battle Royale. W opisie PR zapisz, że na VPS trzeba otworzyć port 7779/UDP i przebudować compose. Nie rób tego sam.
- [x] **Lobby wyboru drużyny:** po wejściu do trybu gracz trafia do ekranu z dwiema drużynami obok siebie (nazwa, kolor, lista graczy z awatarami, liczba miejsc). Klik w kartę dołącza do drużyny, przycisk „Losowo” wybiera mniejszą. Serwer pilnuje równowagi: najwyżej 1 osoba różnicy, pełna drużyna jest nieklikalna z podpowiedzią dlaczego. Zmiana drużyny w lobby jest dozwolona. Spóźniony gracz w trakcie rundy też widzi ten ekran. Drużyna to stan serwera rozsyłany niezawodnym RPC, jak zdrowie i wyniki.
- [x] **Drużyny:** dwie, z własną nazwą i wyraźnie różnym kolorem, czytelnym także dla daltonistów (np. pomarańczowa i niebieska). Wymyśl własne nazwy pasujące do kreskówkowego stylu.
- [x] **Rozróżnianie graczy:** kolor drużyny na modelu postaci (np. opaska, chusta albo naramiennik zbudowany kodem i dopięty do kości, plus delikatny odcień), kolor drużyny na plakietce z nickiem, sojusznicy mają plakietkę widoczną przez ściany, wrogowie tylko w polu widzenia jak dziś. Celownik nie podświetla sojusznika jak wroga. Sprawdź zrzutem z bliska i z 30 m, że różnicę widać od razu.
- [x] **Zasady rundy:** jak w zwykłym Deathmatchu (czas, reset, regeneracja, bezpieczne odrodzenia), ale liczy się wynik drużyny. Limit zabójstw drużyny dobierz sam (punkt wyjścia: 50) i zapisz w „Do decyzji”. **Bez ognia przyjacielskiego**: trafienie sojusznika nie zadaje obrażeń ani nie pokazuje znacznika trafienia, granat też go nie rani. Punkty startu po stronie własnej drużyny, z bezpiecznym wyborem z dala od wrogów.
- [x] **HUD TDM:** u góry pasek wyniku obu drużyn z kolorami i czasem rundy (zamiast „kto prowadzi”). Tabela pod Tab podzielona na dwie kolumny drużyn. Lista zabójstw z nickami w kolorach drużyn. Ekran śmierci pokazuje kolor drużyny zabójcy.
- [x] **Koniec rundy:** wspólny panel (zasada „jeden moment, jeden panel”) z wygraną drużyną, wynikiem, tabelą obu drużyn, MVP każdej drużyny i głosowaniem na mapę. Podium pokazuje najlepszą trójkę zwycięskiej drużyny. Remis obsłuż jawnie.
- [x] **Dodatki z umiarem:** czat drużynowy (osobny klawisz albo przełącznik w polu czatu, prefiks [DRUŻYNA]), znaczniki sojuszników na mapce i radarze, krótki komunikat „Twoja drużyna prowadzi / przegrywa” przy zmianie lidera. Nic więcej bez potrzeby.
- [x] **Boty w TDM:** tylko przydział do mniejszej drużyny i nie strzelają do sojuszników. Nic więcej.

Notatki etapu 1: drużyny „Kaktusy” (pomarańczowe) i „Żuczki” (niebieskie), limit 50 zabójstw drużyny. Znak na postaci to chusta na szyi, opaski na ramionach i odcień 12%; z 30 m drużynę rozpoznaje się głównie po kolorze plakietki z nickiem. Klawisze: N wybór drużyny, Y czat drużyny. `tools/tdm_net_test.sh` przechodzi.

### Etap 2: Mapa pustynna do DM i TDM

- [x] **Własna, duża mapa** `desert` (ok. 130×130 m, dwa razy większa od miasta), scena w `scenes/maps/`, generator kodem w `scripts/maps/` jak miasto i dolina, opis mapy (`MapInfo`) i miniaturka w `assets/maps/` do kart głosowania. Dostępna w głosowaniu DM i TDM.
- [x] **Układ pod oba tryby:** dwie bazy drużyn na przeciwnych końcach i środek z kilkoma trasami (co najmniej 3 równoległe linie przejścia), żeby TDM nie zamieniał się w jeden korytarz. W DM punkty startu rozłożone po całej mapie (co najmniej 16), w TDM co najmniej 8 na drużynę.
- [x] **Klimat:** co najmniej 5 odrębnych miejsc z polskimi nazwami, np. targ z płóciennymi daszkami, oaza z palmami i wodą, ruiny glinianej twierdzy, kanion z mostem linowym, stacja kolejki z wagonami, wydmy z wrakiem ciężarówki. Ciepłe, złote światło nisko nad horyzontem, długie cienie, lekka mgiełka w oddali, przelatujący piasek i krzaki-kulki (cząsteczki), odgłosy wiatru, kroki po piasku. Kolory kreskówkowe, nie brudne.
- [x] **Rozgrywka:** dachy i piętra dostępne schodami lub drabinami, osłony na otwartych przestrzeniach, długie i krótkie linie strzału dla AWP i strzelby. Kolizje bez miejsc do utknięcia i bez wyjścia poza mapę (niewidzialne ściany przy krawędzi, które wyglądają naturalnie, np. skały kanionu).
- [x] **Wydajność:** `MultiMesh` i `visibility_range` dla drobnicy, kolizje uproszczone, cel jak na mieście. Zmierz `tools/perf_probe.gd` i zapisz wynik obok miasta.
- [x] Zrzuty mapy przez `tools/map_shots.gd` (dodaj obsługę `--map=desert`) i obejrzyj je.

Notatki etapu 2: miejsca Stacja, Twierdza, Targ, Kanion, Oaza, Wydmy. 20 punktów drużyn (10 na drużynę) i 12 tylko dla Deathmatchu. `tools/desert_map_test.gd` przechodzi (137 sprawdzeń). Wydajność, 1920×1080, RTX 5070 Ti, wysoka jakość: miasto GPU 0,85–0,88 ms, klatka 1,3–1,6 ms; pustynia GPU 0,83–0,88 ms, klatka 1,5–2,0 ms.

### Etap 3: Lepszy model Desert Eagle

- [x] Nowy, dokładniejszy model Desert Eagle: charakterystyczny masywny zamek z wycięciem, trójkątna lufa, kurek, osłona spustu, okładziny chwytu, muszka i szczerbinka, kilka kolorów materiału (metal, ciemny chwyt, jasny akcent). Nadal low-poly w stylu gry, ale wyraźnie lepszy od obecnego. Zamek jako osobny węzeł, żeby mógł się cofać przy strzale (etap 4).
- [x] Model w ręku, na ziemi, w Zbrojowni i na ikonie (przerenderuj `tools/render_icons.gd`). Porównaj zrzut przed i po w opisie PR.

Notatki etapu 3: model w `tools/build_weapon_models.gd` (`--only=deagle`), węzły `slide`, `hammer` i `magazine`. Porównanie: `docs/screenshots/noc2/deagle_przed.png` i `deagle_po.png`. Podgląd: `tools/weapon_preview.gd`, zrzuty w ręku i w Zbrojowni: `tools/hand_shot.gd`.

### Etap 4: Animacja odrzutu broni

Dziś `view_model.gd` ma prosty `kick()`. Rozbuduj go.

- [x] **Profil odrzutu na broń:** pola wizualne w `WeaponStats` (grupa „Odrzut wizualny”): cofnięcie, podbicie lufy, obrót w bok, szybkość powrotu, sprężystość. Desert Eagle mocno podbija lufę, AWP ciężko cofa się w ramię, strzelba szarpie, blaster lekko drży w serii. Powrót na sprężynie (lekkie przestrzelenie i powrót), a nie liniowy.
- [x] **Ruchome części:** zamek pistoletu cofa się i wraca, u AWP po strzale widoczny ruch zamka (przeładowanie czółenkowe), u strzelby przesuw pompki.
- [x] **Kamera:** krótkie, małe uderzenie kamery zależne od broni, tylko wizualne. **Kierunek pocisku i rozrzut się nie zmieniają**, bo liczy je rollback. Opcja w ustawieniach „Siła odrzutu kamery” (0–100%).
- [x] **Widok z trzeciej osoby:** inni gracze widzą szarpnięcie rąk przy strzale.
- [x] Przy okazji: płynniejsza animacja przeładowania i wyjmowania broni, jeśli obecna jest sztywna.

Notatki etapu 4: pola `kick_*` i `cycle_*` w `WeaponStats` mnożone przez `recoil` (klasa broni), sprężyna w `ViewModel._update_kick_spring`. Węzły modeli: `slide`/`hammer` (Desert Eagle), `bolt` (AWP), pompkę strzelby cofa lewa ręka, bo model z paczki Kenney nie ma osobnej części. Suwak „Siła odrzutu kamery” (`recoil_camera`). Wyjmowanie broni wjeżdża z łagodnym wygaszeniem i obrotem.

### Etap 5: Więcej życia na mapie Battle Royale (dolina)

- [ ] Przejdź mapę doliny zrzutami z góry i z poziomu gracza, wypisz puste miejsca i dopiero wtedy dodawaj.
- [ ] **Każde z nazwanych miejsc** dostaje więcej zabudowy i rekwizytów: dodatkowe budynki do wejścia, płoty, stogi, wozy, beczki, skrzynie, studnie, wieże obserwacyjne, namioty, pomosty, ogniska.
- [ ] **Między miejscami:** drogi i ścieżki z rekwizytami (słupy, drogowskazy, porzucone wozy, mostki), małe obozowiska, pojedyncze chaty, ruiny, skałki i kępy drzew jako osłony, żeby przejście przez otwarte pole nie było puste. Kilka małych, nowych punktów z 1–2 skrzynkami.
- [ ] Gęstsza roślinność i drobnica (kwiaty, krzaki, kamienie) przez `MultiMesh` z `visibility_range`.
- [ ] **Wydajność:** zmierz `tools/perf_probe.gd` przed i po. Spadek o więcej niż 10% trzeba naprawić (LOD, zasięg widoczności, łączenie siatek).

## 4. Dodatki zatwierdzone przez użytkownika (po etapach 1–5)

Tylko te dwa. Innych dodatków nie dokładaj.

- [ ] **Różne dźwięki trafienia:** osobny dźwięk zwykłego trafienia, trafienia w głowę, zabójstwa i zabójstwa w głowę, krótki „ding” przy zabiciu z AWP. Dźwięki generowane skryptem jak pozostałe (bez kopiowania z innych gier), znacznik trafienia w kolorze zgodnym z dźwiękiem. Działa w DM, TDM i BR.
- [ ] **Statystyki gracza po rundzie:** sekcja „Twoja runda” w panelu końca rundy (zgodnie z zasadą „jeden moment, jeden panel”): zabójstwa, śmierci, celność, trafienia w głowę, zadane obrażenia, najdłuższe zabójstwo w metrach, ulubiona broń rundy i strzałki porównania z poprzednią rundą. Liczone lokalnie u klienta i dopisywane do istniejących statystyk osobistych. Sprawdź zrzutem 1280×720 w DM i TDM.

## 5. Zakończenie (zawsze, nawet gdy część punktów ma `[!]`)

- [ ] Pełne testy `bash tools/all_tests.sh tools/logs/koniec.txt` i porównanie z bazą. Nowe błędy napraw.
- [ ] Nowe testy: `tdm_test` (przydział i równowaga drużyn, brak ognia przyjacielskiego, wynik drużyny, koniec rundy), `tools/tdm_net_test.sh` z botami w dwóch drużynach, `desert_map_test.gd` (punkty startu, brak utknięć, wyjście poza mapę), krótki test profilu odrzutu. Wzór w istniejących testach i `docs/DEVELOPMENT.md`.
- [ ] Przegląd własnego diffu (`/code-review` albo subagent) i poprawki.
- [ ] README: nowe funkcje, sterowanie, licencje nowych zasobów, **bez notatek roboczych** (te idą do `docs/DEVELOPMENT.md`). Odśwież zrzuty `tools/readme_shots.gd` z `--fake-steam=Kapitan:76561197960265729`, dodaj zrzuty lobby TDM, HUD TDM, pustyni, Desert Eagle i doliny. Przykładowe nicki i adresy, bez prawdziwego IP.
- [ ] `docs/DEVELOPMENT.md`: architektura drużyn, mapa pustynna, profil odrzutu, nowe testy.
- [ ] Sprawdzenie całej historii gałęzi i plików pod kątem adresu IP i danych logowania.
- [ ] Opis draft PR: co zrobiono (z zrzutami), jak zagrać lokalnie w TDM (gotowe polecenia dla początkującego, np. `tools\run_local.ps1` z odpowiednim trybem), co wymaga oceny człowieka, „Do decyzji”, wyniki testów i wydajności, czynności na VPS (port 7779). PR zostaje szkicem.
- [ ] Ostatni commit i push planu z wszystkimi znacznikami. Dopiero teraz możesz zakończyć turę.
