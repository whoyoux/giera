# Zasady interfejsu

Styl gry jest taktyczny i nowoczesny: ciemne grafitowe panele z cienką krawędzią 1 px, małe zaokrąglenia (2–6 px), bez przechyleń i sprężynujących animacji, oraz font Archivo (zmienna szerokość i grubość). Kolor to sygnał, a nie ozdoba: większość interfejsu jest neutralna, a akcent dostaje tylko to, co ważne. Wszystko buduje `scripts/ui/ui_style.gd` (`UiStyle`), a nowe okna i karty korzystają z niego, zamiast ustawiać kolory i style od zera.

Czcionki z `UiStyle`:

- `label(..., bold)`: zwykły tekst (Archivo 470) i gruby, lekko zwężony (680).
- `display_label`: bardzo gruby, wąski krój (800, szerokość 72) do dużych liczb i tytułów: zegar, wynik, zdrowie, amunicja, tytuł okna.
- `eyebrow`: mały nadtytuł wielkimi literami, np. „KONIEC RUNDY”, „ADRES SERWERA”.

Każdą zmianę wyglądu sprawdzamy na zrzucie ekranu 1280×720, zanim uznamy ją za gotową.

## 1. Tekst: mało rozmiarów, wyraźna hierarchia

Używamy tylko tych rozmiarów fontu:

| Rola | Rozmiar | Grubość |
|---|---|---|
| Duży napis na środku ekranu (odliczanie, zwycięzca w BR) | 32–38 | gruby |
| Tytuł okna lub panelu | 22–26 | gruby |
| Tytuł karty, nazwa, ważna wartość | 17–19 | gruby |
| Zwykły tekst, wiersze list | 15–17 | zwykły albo gruby |
| Podpowiedź, licznik, opis drugiego planu | 13–14 | zwykły, kolor `INK` z przezroczystością 0.65 |

- Panel ma najwyżej trzy rozmiary tekstu. Jeden tytuł, reszta niżej w hierarchii.
- Tekst w małej karcie (np. karta mapy, slot przedmiotu) nie przekracza 18. Karta to nie plakat.
- Tekst nie wychodzi poza kartę: długie nazwy dostają `clip_text` i wielokropek (`TextServer.OVERRUN_TRIM_ELLIPSIS`).
- Ważność pokazujemy grubością i kolorem, a nie tylko rozmiarem.

## 2. Odstępy: stała skala i zawsze oddech od krawędzi

Odstępy biorą wartości ze skali **4, 8, 12, 16, 20, 24**.

- **Wnętrze panelu** (okno, karta wyników): margines 16–20 z każdej strony, po bokach może być 20–24.
- **Wnętrze małej karty** (np. karta mapy): margines co najmniej 12. Tekst nigdy nie stoi bliżej niż 12 px od krawędzi karty, licząc od wewnętrznej strony obwódki.
- **Obwódka nie jest odstępem.** `content_margin` w `StyleBoxFlat` liczy się od zewnętrznej krawędzi i obejmuje obwódkę. Krawędź panelu ma 1 px (`UiStyle.BORDER`). Starsze wywołania `UiStyle.sticker(kolor, promień, obwódka)` podają dawne liczby (np. `5 + 12`). `sticker` traktuje promień tylko jako wskazówkę (`UiStyle.corner`), a grubość obwódki pomija.
- Między elementami jednej grupy (tytuł i podtytuł, ikona i podpis): 4–8. Między grupami w panelu: 12–16. Między osobnymi kartami: 12–16.
- Obraz w karcie (miniaturka, ikona) ma ten sam margines od krawędzi co tekst, żeby wszystko stało w jednej linii.
- Zaokrąglenia zagnieżdżone: promień w środku = promień na zewnątrz − margines (np. karta 18 z marginesem 10 → obrazek 8). Inaczej rogi wyglądają krzywo.

## 3. Jeden moment, jeden panel

- To, co gracz ogląda w jednej chwili (np. wynik rundy i wybór następnej mapy), stoi w jednym panelu, podzielonym na sekcje cienką kreską. Nie stawiamy obok siebie dwóch osobnych okien różnej wielkości.
- Sekcje w panelu mają ten sam układ: czytamy je od lewej górnej krawędzi, ich nagłówki stoją na jednej wysokości, a tekst nie jest raz wyśrodkowany, a raz wyrównany do lewej.
- Kolejność ważności widać od razu: mały nadtytuł (co to za ekran), duży nagłówek (najważniejsza informacja), potem szczegóły i na końcu podpowiedzi.
- Każda sekcja z wyborem ma nagłówek mówiący, czego dotyczy, i jednozdaniową podpowiedź, jak wybrać.

## 4. Klikalne rzeczy wyglądają na klikalne

- Wszystko, co można kliknąć, ma trzy stany: zwykły, pod kursorem (jaśniejsze tło i cienka jasna krawędź, a karty żółtą krawędź `SUN`) i wybrany.
- Przyciski: jeden główny w oknie ma kolor akcentu (`CORAL`, np. „Dołącz do gry”), reszta to `UiStyle.secondary_button` (neutralne tło `NEUTRAL`). Nie kolorujemy przycisków tylko po to, żeby się różniły.
- Zakładki, filtry i wybór trybu działają jak przełącznik segmentowy: wybrany jest jasny (`INK`) z ciemnym tekstem (`DEEP`), pozostałe neutralne. Kolor zmienia `UiStyle.paint_button`.
- Pod kursorem pojawia się rączka (`CURSOR_POINTING_HAND`) i cichy dźwięk `HOVER`. Przycisk lekko rośnie (`ButtonFeel`), ale się nie przechyla, a kliknięcie gra `CONFIRM`.
- Jeśli coś działa też z klawiatury, pokazujemy klawisz w ciemnym znaczku (`UiStyle.key_chip` albo `ActionChip`), a jego nazwę bierzemy z `Keybinds.label_of`, nigdy na sztywno.
- Panel z wyborem ma krótki tytuł, co wybieramy, i jednozdaniową podpowiedź jak.
- Gdy gra czeka na kliknięcie, kursor jest widoczny. Po wyborze lub końcu etapu znika, a kliknięcie, które go schowało, nie strzela.

## 5. Kolory

- Tło okien: `PAPER` (ciemny grafit, nieprzezroczysty). Karta lub pole w oknie: `PANEL_2` (o ton jaśniejsza) albo `UiStyle.flat`. Elementy HUD w trakcie walki: `HUD_FILL` (półprzezroczysty, żeby nie zasłaniał gry).
- Tekst: `INK` (jasny), drugi plan `INK` z przezroczystością 0.55–0.65.
- `DEEP` (prawie czerń) to tło znaczków klawiszy (`UiStyle.chip_box`), przyciemnienie gry pod oknem i obrys napisów na obrazie gry. Nie używamy do tego `INK`, bo jest jasny.
- Na jasnym albo kolorowym tle (żółta seria, wybrany wycinek koła tańców, wybrana zakładka) tekst jest ciemny (`DEEP`).
- Główny przycisk i akcent marki: `CORAL`. Wybór i „to ty” w tabelach: `BLUE`. Najechanie, odliczanie i seria: `SUN`. Dobrze/gotowe/leczenie: `TEAL`. Pasek zdrowia jest jasny, a przy niskim zdrowiu `CORAL`.
- Tekst na obrazku dostaje własne tło (znaczek), nigdy nie leży gołym tekstem na zdjęciu.

## 6. Układ na ekranie

- Okna w trakcie gry nie zasłaniają środka ekranu ani tego, na co gracz ma patrzeć (np. postaci na podium).
- **Strefa walki** to prostokąt na środku ekranu: 40% szerokości i 50% wysokości (przy 1280×720: x 384–896, y 180–540). Wolno w niej być tylko celownikowi, lunecie, wskaźnikowi kierunku obrażeń, liczbom obrażeń, kołu tańców i oknom modalnym (pauza, tabela, wybór drużyny). Wyjątki to napisy, gdy gracz nie walczy: o śmierci i odliczanie na starcie rundy, gdy postać stoi w miejscu. Sprawdza to `hud_layout_test`, a `tools/hud_sizes_probe.gd` wypisuje linie `STREFA WALKI`.
- **Stałe elementy walki** (zegar, „Najlepsi”, liczniki drużyn, zdrowie, amunicja, pasek przedmiotów, podpowiedź o wyrzucaniu, mapka, pasek strefy) zajmują razem najwyżej **20% ekranu**.
- **Lista zabójstw**: najwyżej 4 wiersze, cała najwyżej **300 × 150 px**, co najmniej **16 px** od sąsiednich elementów przy najdłuższych nickach.
- **Napis pod zegarem** (baner, seria): naklejka najwyżej **340 px**.
- **Samouczek** stoi w lewej kolumnie i nie nachodzi na mapkę ani czat. Na swój czas zastępuje kartę „Najlepsi” i wykres sieci.
- **Karta wyników** w każdym trybie stoi przy dolnej krawędzi i ma najwyżej **33% wysokości ekranu**, żeby było widać postacie na podium i oglądanego zwycięzcę.
- **Tabela pod Tab** mieści się na 1280×720 przy **32 graczach** z marginesem co najmniej 16 px (powyżej 12 graczy dwie kolumny).
- Pod zegarem jest jedno miejsce na krótki napis: baner rundy, seria albo odliczanie. Nowy zastępuje poprzedni, a odliczanie i ostrzeżenie o strefie mają pierwszeństwo. Nad paskiem przedmiotów też jest jedno miejsce: podpowiedź, nazwa przedmiotu albo napis o śmierci.
- Przy celowaniu bez lunety elementy poboczne (lewa kolumna, lista zabójstw, zamknięty czat) bledną do 35%.
- Lewy dół to zdrowie i czat, prawy dół to amunicja i mapka, góra to zegar i strefa. Nowe elementy wchodzą tam, gdzie jest wolno.
- `hud_layout_test` sprawdza wszystkie te liczby w Deathmatchu, Team Deathmatchu i Battle Royale, przy oknach 1280×720, 1280×800 i 1720×720 i skali interfejsu 0,6 i 1,0. **Nowy element HUD-u trzeba dopisać do tego testu** (`_show_everything`), a jeśli dzieli miejsce z innym, do par `EXCLUSIVE`.
- Okna pojawiają się z `UiStyle.pop_in`, a okna modalne przyciemniają grę.

## 7. Przed oddaniem

- Zrzut 1280×720 i sprawdzenie: czy tekst ma oddech od krawędzi, czy rozmiary trzymają tabelę, czy widać, co można kliknąć.
- Po zmianie wyglądu odświeżamy zrzuty w `docs/screenshots`, które pokazuje README.
