# Plan: battle royale

Kroki 1–5 są zrobione. Battle Royale to osobny tryb obok Deathmatchu: każdy tryb ma własny serwer i port (`compose.yaml`), a gracz wybiera tryb w menu głównym.

## Zasady

Serwer prowadzi jeden mecz naraz, bez pokojów.

| Etap | Co się dzieje |
|---|---|
| Lobby | Gracze chodzą po mapie, bez obrażeń i skrzynek. Widać listę graczy i przycisk **Gotowe**. |
| Odliczanie | Gdy co najmniej 2 graczy jest gotowych i nikt nie czeka, rusza 5 s odliczania. Cofnięcie gotowości albo nowy gracz je przerywa. |
| Mecz | Wszyscy przenoszą się na osobne miejsca i po chwili ruszają. Bez odrodzeń, strefa się zacieśnia. |
| Koniec | Ostatni żywy wygrywa. Ekran wyników trwa ok. 10 s. |
| Powrót | Mapa i ekwipunek się resetują, a gracze wracają do lobby. |

## Kroki

Każdy krok to osobny PR. Pierwsze wydanie po kroku 3.

1. **Lobby i start meczu.** Autoload `Match` z etapami gry, czasy w tickach. Panel lobby z gotowością i odliczaniem. Przeniesienie graczy obecnym mechanizmem odrodzenia. Serwer przydziela różne punkty startu, bo dziś dwóch graczy może wylosować ten sam. Przed startem ruch jest zablokowany, a poza meczem nie ma obrażeń. Test: boty klikają Gotowe, także z opóźnieniem i przy cofnięciu gotowości.
2. **Eliminacja i widz.** Śmierć bez odrodzenia, cały ekwipunek wypada. Martwy ogląda żywych i przełącza ich klawiszem. Serwer sprawdza zwycięzcę po każdej śmierci i rozłączeniu, jednoczesna śmierć to remis. Dane w `GameState` zakładają dziś, że po śmierci zawsze jest odrodzenie. Test: śmierć, rozłączenie, jednoczesna śmierć od granatu.
3. **Koniec meczu i reset.** Ekran zwycięstwa i miejsca. Reset bez restartu serwera: przedmioty, granaty, skrzynki, zdrowie, ekwipunek, wyniki. Skrzynki otwierają się raz na mecz. Test: 3 mecze z rzędu.
4. **Strefa.** Klasa `Zone` liczy strefę z ziarna i ticku startu, serwer wysyła je raz. Obrażenia zadaje tylko serwer. Półprzezroczysta ściana, efekt na ekranie i dźwięk poza strefą.
5. **Interfejs.** Licznik żywych, czas do fazy, mapka ze strefą, lista zabójstw z liczbą pozostałych, tabela wyników meczu, dźwięki startu i zwycięstwa, zrzuty do README.
6. **Balans.** Gra ze znajomymi i dostrojenie strefy, skrzynek i łupu.

## Mapa

Battle Royale gra w **Dolinie** (`scenes/maps/valley.tscn`, generator `scripts/maps/valley_builder.gd`), o promieniu ok. 200 m. Ma sześć miejsc z nazwami: Stare ruiny w środku, Wioskę, Gospodarstwo, Kamieniołom, Jezioro z mostem i Obóz na wzgórzu, a między nimi las, polany i drogi. Teren ma kolizję z `HeightMapShape3D` i wygląd w kawałkach, a roślinność to `MultiMesh` z zasięgiem widoczności. Jest 24 punktów startu i ponad 60 skrzynek skupionych w miejscach. Leśna polana zostaje mapą tła menu i można ją wybrać flagą `--map=forest`.

## Strefa

Dolina, strefa od 192 m, razem ok. 8 min 15 s.

| Faza | Czekanie | Zawężanie | Promień | Obrażenia/s |
|---|---|---|---|---|
| 1 | 90 s | 60 s | 192 → 120 m | 2 |
| 2 | 70 s | 50 s | 120 → 70 m | 3 |
| 3 | 55 s | 40 s | 70 → 35 m | 5 |
| 4 | 40 s | 35 s | 35 → 14 m | 8 |
| 5 | 25 s | 30 s | 14 → 0 m | 12 |

Leśna polana ma dawne fazy: promień 50 m i 4 min 40 s.

## Ustawienia

- Start bez broni. Łup trzeba zdobyć w skrzynkach.
- Dołączenie w trakcie meczu: widz, a po końcu lobby.
- Limit 10 graczy w meczu, reszta ogląda.
- Start wymaga gotowości wszystkich w lobby. Później można dodać limit czasu dla osób poza klawiaturą.

## Ryzyka

- Krok 2: śmierć i odrodzenie są związane z rollbackiem, a błąd może wyjść dopiero przy opóźnieniu.
- Krok 3: każda przeoczona rzecz przejdzie do kolejnego meczu.
- Krok 6: duża mapa ma ponad 60 skrzynek, ale odległości są większe, więc trzeba sprawdzić, czy gracze nie biegają za długo bez spotkania.
