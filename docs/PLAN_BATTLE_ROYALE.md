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

## Strefa

Mapa o promieniu 39 m, razem 4 min 40 s.

| Faza | Czekanie | Zawężanie | Promień | Obrażenia/s |
|---|---|---|---|---|
| 1 | 60 s | 40 s | 39 → 26 m | 2 |
| 2 | 45 s | 30 s | 26 → 15 m | 4 |
| 3 | 35 s | 25 s | 15 → 7 m | 7 |
| 4 | 20 s | 25 s | 7 → 0 m | 12 |

## Ustawienia

- Start bez broni. Łup trzeba zdobyć w skrzynkach.
- Dołączenie w trakcie meczu: widz, a po końcu lobby.
- Limit 10 graczy w meczu, reszta ogląda.
- Start wymaga gotowości wszystkich w lobby. Później można dodać limit czasu dla osób poza klawiaturą.

## Ryzyka

- Krok 2: śmierć i odrodzenie są związane z rollbackiem, a błąd może wyjść dopiero przy opóźnieniu.
- Krok 3: każda przeoczona rzecz przejdzie do kolejnego meczu.
- Krok 6: mapa ma 11 skrzynek i każda otwiera się raz na mecz, a start jest bez broni, więc przy 10 graczach łupu może być za mało.
