# Giera

Kolorowa strzelanka FPS multiplayer, w której gracze walczą jako małe figurki w pokoju pełnym wielkich zabawek.

![Rozgrywka](docs/screenshots/gameplay.png)

| Skrzynka | Bronie na ziemi | Celowanie | Granat |
|---|---|---|---|
| ![Otwieranie skrzynki](docs/screenshots/chest_open.png) | ![Bronie na ziemi](docs/screenshots/loot.png) | ![Celowanie](docs/screenshots/aim.png) | ![Wybuch granatu](docs/screenshots/grenade.png) |

| Koło tańców | Taniec |
|---|---|
| ![Koło tańców](docs/screenshots/dance_wheel.png) | ![Taniec](docs/screenshots/dance.png) |

| Strzelba | Nóż | Menu | Wyniki | Obrażenia |
|---|---|---|---|---|
| ![Strzał ze strzelby](docs/screenshots/shotgun.png) | ![Cięcie nożem](docs/screenshots/knife.png) | ![Menu](docs/screenshots/menu.png) | ![Wyniki](docs/screenshots/scoreboard.png) | ![Obrażenia](docs/screenshots/damage.png) |

## Co jest w grze

- **Multiplayer na żywo:** serwer dedykowany albo hostowanie z menu. Ruch reaguje od razu, a strzały liczą się tam, gdzie gracz widział cel na ekranie.
- **Trzy klasy broni:** zwykła, epicka i legendarna, każda z własnym modelem, parametrami, smugą i dźwiękiem.
- **Rozrzut:** najcelniej strzela się w miejscu i pierwszym pociskiem. Rośnie w ruchu, w skoku i w długiej serii, ale tylko do limitu, a lepsza broń ma go mniej. Celownik pokazuje go na żywo, a celowanie go zmniejsza.
- **Strzelba:** kilka śrucin naraz, ogromne obrażenia z bliska i słabe z daleka.
- **Nóż:** dwa ciosy zabijają, nie ma naboi, a z nożem w ręku biegniesz szybciej.
- **Ekwipunek na 4 sloty:** szybka zmiana broni klawiszami lub scrollem, osobna amunicja w każdej broni.
- **Skrzynki z łupem:** rozsiane po mapie, otwierane przez przytrzymanie klawisza. Każda daje jeden przedmiot: blaster, strzelbę, nóż, apteczkę albo granat, a po minucie wraca. Wśród broni z klasami 55% to zwykłe, 35% epickie i 10% legendarne.
- **Tańce:** przytrzymanie klawisza otwiera koło z 6 tańcami, każdy z własnym ruchem i muzyką, którą słyszą też gracze obok. Kamera odjeżdża wtedy za postać, a każdy ruch przerywa taniec.
- **Podnoszenie i wyrzucanie:** bronie leżą na ziemi, a po śmierci wypadają dla innych.
- **Apteczki:** przytrzymanie strzału przez 2,5 s leczy o 50 punktów.
- **Granaty:** przytrzymanie odbezpiecza, a puszczenie rzuca, więc można skrócić czas do wybuchu. Im bliżej wybuchu, tym większe obrażenia, a tuż obok giniesz od razu.
- **Celowanie:** prawy przycisk przybliża widok i zmniejsza odrzut, ale spowalnia ruch. Lepsza broń ma mocniejsze przybliżenie.
- **Konto Steam:** gra na Windows sama pobiera nazwę i zdjęcie profilowe z konta Steam. Zdjęcia widać w menu, w tabeli wyników, na liście zabójstw i nad graczami. Bez Steama wystarczy wpisać nick.
- **Wybór postaci:** 9 modeli do wyboru strzałkami w menu, w tym rycerze i szkielety. Gra zapamiętuje wybór.
- **Sprint z limitem:** pasek zużywa się w biegu i odnawia po chwili odpoczynku.
- **Leśna polana:** ruiny z wieżą na środku, wzgórze, strumień i gęsty las dookoła, szum wiatru, śpiew ptaków i kroki zależne od podłoża, animowane postacie i żywy interfejs w stylu naklejek, który reaguje ruchem i dźwiękiem, z osobną głośnością.
- **Czytelna walka:** kierunek trafienia, znaczniki trafień, lista zabójstw i tabela wyników z pingiem.

## Jak zagrać

Pobierz najnowszą wersję z zakładki [Releases](../../releases/latest):

- **Windows:** rozpakuj `Giera-Windows.zip` do jednego folderu i uruchom `Giera.exe`. Jeśli pojawi się SmartScreen, wybierz **Więcej informacji**, a potem **Uruchom mimo to**.
- **macOS:** rozpakuj `Giera-macOS.zip` i uruchom `Giera.app`. Aplikacja nie ma podpisu Apple, więc przy pierwszym uruchomieniu wybierz **Otwórz mimo to** w **Ustawienia systemowe → Prywatność i ochrona**.

Jeśli Steam jest włączony, gra zaloguje Cię sama. W innym wypadku wpisz nick. Potem podaj adres serwera i kliknij **Dołącz** albo wybierz **Hostuj na tym komputerze**. Hostowanie wymaga otwartego portu 7777/UDP.

## Sterowanie

| Klawisz | Akcja |
|---|---|
| **WASD** | Ruch |
| **Mysz** | Celowanie |
| **LPM** | Strzał lub cios nożem. Przytrzymanie używa apteczki albo odbezpiecza granat, a puszczenie go rzuca |
| **PPM** | Celowanie (przytrzymaj) |
| **R** | Przeładowanie |
| **Shift** | Sprint |
| **Spacja** | Skok |
| **1–4 / scroll** | Zmiana broni |
| **E** | Podniesienie przedmiotu, przytrzymanie otwiera skrzynkę |
| **G** | Wyrzucenie przedmiotu |
| **B** | Przytrzymanie otwiera koło tańców. Puszczenie albo LPM wybiera taniec, a ruch go przerywa |
| **Tab** | Wyniki |
| **Esc** | Pauza i ustawienia |

## Technologia

Godot 4.7, GDScript i [netfox](https://github.com/foxssake/netfox). Serwer decyduje o przebiegu gry, klient przewiduje ruch i strzały, a strzelanie korzysta z cofania czasu, żeby rekompensować opóźnienie sieci.

## Licencja

Kod i własne pliki projektu są udostępnione wyłącznie do wglądu, a wszelkie prawa są zastrzeżone. Szczegóły są w pliku [LICENSE](LICENSE).

Składniki innych autorów zachowują swoje licencje: [netfox](https://github.com/foxssake/netfox) (MIT), [GodotSteam](https://codeberg.org/godotsteam/godotsteam) (MIT), biblioteki Steamworks SDK (umowa Valve), postacie [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) (CC0), [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons) (CC0), [Kenney Blaster Kit](https://kenney.nl/assets/blaster-kit) (CC0), [KayKit Forest Nature Pack](https://kaylousberg.itch.io/kaykit-forest) (CC0) i czcionka Fredoka (SIL OFL). Pliki licencji leżą przy zasobach.
