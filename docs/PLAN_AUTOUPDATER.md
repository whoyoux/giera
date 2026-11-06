# Plan: autoupdater

Etap 1 jest zrobiony, a etap 2 czeka na próbne wydanie. Z etapu 0 została próba na prawdziwym Macu. Gracz uruchamia mały launcher, który sprawdza nową wersję na GitHub Releases, pobiera zwykle tylko dane gry (PCK), sprawdza je i startuje grę. Buildy zostają na GitHubie, a serwer ani VPS nie są do tego potrzebne.

## Pomiary

Stan na 2026-11-06, wydania v0.19.0 → v0.20.0, Windows.

| Sposób aktualizacji | Do pobrania | Wymaga |
|---|---|---|
| Cały ZIP, jak dziś | 47,9 MB | nic |
| Cały PCK | 10,5 MB | etapy 1–3 |
| Zmienione części, import od zera | 2,5–3,6 MB | etap 5 |
| Zmienione części, zachowany import | 0,3–0,6 MB | etap 5 i cache importu |

Skład ZIP-a po kompresji: silnik ok. 36 MB, biblioteki Steama 1,3 MB, PCK ok. 10,2 MB. Silnik różni się między wydaniami 2 bajtami w nagłówku pliku, więc wersję `runtime` trzeba porównywać po identyfikatorze, a nie po sumie exe.

Między tymi wydaniami zmieniło się 166 z 647 plików w PCK, a faktycznie tylko 7 skryptów i scena `world`. Pozostałe to zaimportowane modele, bez zmian w plikach źródłowych. Powód: Godot zapisuje przy każdym imporcie losowe `node_ids`, a CI importuje wszystko od zera.

Eksport lokalny tych tagów, bez GodotSteam:

| Test | Zmienione pliki | Rozmiar |
|---|---|---|
| Ten sam kod, dwa eksporty | 0 | 0 MB |
| v0.19.0 → v0.20.0, zachowany `.godot` | 8 | 0,12 MB |
| v0.19.0 → v0.20.0, import od zera | 166 | 8,47 MB |

Na Linuksie w CI wynik jest taki sam: 8 plików i 0,12 MB z zachowanym importem, 166 plików i 8,47 MB od zera. Nie zmierzono rozmiaru aktualizacji na macOS ani większych wydań. Zmiana modeli lub tekstur da większą aktualizację, a zmiana silnika oznacza ok. 37 MB.

## Ograniczenia silnika

- Oficjalne szablony Godota nie obsługują `--main-pack`, bo mają domyślnie `disable_path_overrides=True`.
- Silnik szuka PCK w samym exe, potem obok exe pod tą samą nazwą. Na macOS najpierw w `Contents/Resources`.
- `load_resource_pack` nie wczyta nowych ustawień z `project.godot`, a ten plik zmienił się w 2 z ostatnich 5 wydań.

## Architektura

Po rozpakowaniu ZIP-a, w folderze gracza:

```
Giera.exe    silnik
Giera.pck    launcher
biblioteki Steama
```

Po pierwszym uruchomieniu, w danych użytkownika:

```
game/GieraGame.exe    kopia silnika
game/GieraGame.pck    gra, ten plik się aktualizuje
game/*.dll            biblioteki Steama
game/installed.json   zainstalowana wersja i sumy
```

Start:

1. Launcher pobiera `manifest.json` z `releases/latest/download/`, z limitem czasu 5 s. Nie używa API GitHuba, które pozwala na 60 zapytań na godzinę z jednego IP.
2. Jeśli wersja jest inna, pobiera PCK do pliku `.tmp`.
3. Sprawdza SHA-256 i podmienia plik. Gra wtedy nie działa, więc nic go nie blokuje.
4. Uruchamia grę i się zamyka.
5. Bez internetu albo przy błędzie uruchamia zainstalowaną wersję. Launcher nie blokuje gry, jeśli jakaś wersja jest już na dysku.

Manifest:

```json
{
  "version": "0.21.0",
  "protocol": 20,
  "windows": {
    "pack":    { "file": "Giera-Windows.pck", "size": 12345678, "sha256": "..." },
    "runtime": { "file": "Giera-Windows-runtime.zip", "id": "godot-4.7.2+steam-4.23.2", "sha256": "..." }
  },
  "macos": { "...": "..." }
}
```

`runtime` pobiera się tylko po zmianie Godota albo GodotSteam. Pliki wydania launcher pobiera przez konkretny tag, np. `download/v0.21.0/...`, żeby manifest i PCK zawsze pochodziły z tego samego wydania.

Koszt tego układu to dwie kopie silnika na dysku, ok. 220 MB, i krótkie okno launchera przy starcie.

## Odrzucone opcje

| Opcja | Powód |
|---|---|
| `load_resource_pack` w działającej grze | Nie wczyta nowych ustawień, a autoloady bywają już załadowane |
| Natywne łatki Godota (`--export-patch`) | Wymagają dokładnie tych samych paczek bazowych, a łańcuch łatek wydłuża wczytywanie |
| Własna kompilacja silnika z `--main-pack` | Budowanie Godota w CI na dwa systemy przy każdej zmianie silnika |
| Gra podmienia się skryptem przy wyjściu | Wymaga zapisu w folderze gry, a na macOS aplikacja może działać z miejsca tylko do odczytu |
| Velopack | Dochodzi instalator i kolejne narzędzie, a nie sprawdzono działania bez podpisu. Pierwsza aktualizacja na macOS i tak jest pełna |
| Launcher w Go lub Rust | Nowy język i osobne buildy, a oszczędza tylko ok. 110 MB na dysku |

## Etapy

Każdy etap to osobny PR.

### Etap 0: próby

1. **Windows: działa.** Exe skopiowany jako `GieraGame.exe` z `GieraGame.pck` i bibliotekami obok startuje z innego folderu, także ze spacją i polskimi znakami w ścieżce, i łączy się ze Steamem.
2. **macOS: działa w CI bez okna, zostaje próba na prawdziwym Macu.** Sam plik binarny z PCK obok uruchamia serwer i przyjmuje klienta, więc to pierwszy wybór, bo nie narusza podpisu. Kopia `.app` z podmienionym PCK też startuje, przed i po ponownym podpisaniu `codesign -s -`, i zostaje wariantem zapasowym. `ditto` przenosi kwarantannę na kopię, a kopia bajtowa nie, więc launcher kopiuje bajty i sam ustawia prawo uruchamiania. CI nie pokazuje okna, Docka, fokusu ani zachowania Gatekeepera u gracza, a `spctl` odrzuca aplikację z podpisem ad hoc także bez kwarantanny.
3. **Pobieranie: działa.** `HTTPRequest` przechodzi przez przekierowania GitHuba i zachowuje nagłówek `Range`, także z `download_file`. Brak pliku daje kod 404, a brak sieci błąd bez kodu.
4. **Cache importu w CI: działa.** Wynik z Linuksa jest w sekcji Pomiary. `actions/cache` odpada, bo przebieg dla jednego tagu nie odczyta cache'u z innego tagu.

### Etap 1: wersja gry

- CI wpisuje wersję z tagu do `application/config/version`.
- Menu pokazuje numer wersji, a uruchomienie z edytora pokazuje `dev`.
- Zrzut menu w README jest odświeżony.

### Etap 2: wydania z manifestem

- `export_presets.cfg`: PCK osobno od exe, `embed_pck=false`.
- `tools/make_manifest.py` tworzy manifest, a `release.yml` publikuje PCK, `runtime` i `manifest.json` dla obu systemów.
- Test macOS uruchamia też grę w układzie aktualizacji: sam plik binarny i PCK obok.
- Zapis importu leży w wydaniu jako `ci-import-cache-godot-<wersja>.tar.gz`, ok. 10 MB. Zawiera `.godot/imported` i `.godot/exported`, bo sam `imported` daje 12 zmienionych plików zamiast 8. Kolejny build pobiera go z najnowszego wydania stabilnego.
- Bez zapisu build importuje od zera, więc aktualizacja jest większa, ale nic się nie psuje. Pierwsze wydanie po tym etapie nie ma jeszcze zapisu, a działanie zapisu w CI sprawdzi dopiero następne wydanie stabilne.
- Stare ZIP-y zostają do końca przejścia. ZIP na Windows zawiera teraz też `Giera.pck`.

### Etap 3: launcher

- Folder `launcher/` z własnym, minimalnym `project.godot`: renderer Compatibility, jedna scena.
- Główny projekt go pomija: `exclude_filter` i `.dockerignore`. W etapie 0 sprawdzić, czy edytor pomija go sam.
- Okno pokazuje wersję, pasek postępu, a przy błędzie przycisk **Graj mimo to**.
- Sprawdzanie rozmiaru i sumy, wolnego miejsca na dysku, zapis przez `.tmp`, poprzedni PCK zachowany do udanego startu nowego.
- Blokada przed podwójnym uruchomieniem.
- Parametry z linii poleceń przechodzą do gry, a `--no-update` pomija sprawdzanie.
- Launcher i gra używają tej samej ścieżki `user://`, żeby ustawienia graczy zostały.
- Przepisać test macOS w `release.yml` pod nowy układ.
- `OUTDATED_MESSAGE` przestaje mówić o ręcznym pobieraniu buildu.

### Etap 4: wygoda i bezpieczeństwo

- **Podpis manifestu.** RSA przez `Crypto.verify`, klucz prywatny w GitHub Secrets, publiczny w launcherze. Bez podpisu przejęcie konta lub tokenu GitHuba pozwala podmienić grę wszystkim graczom.
- **Sprawdzanie w grze.** Menu pokazuje informację o nowej wersji i przycisk restartu.
- **Aktualizacja launchera.** Niewielki, niezmienny starter montuje nową logikę launchera z danych użytkownika. Tu `load_resource_pack` wystarcza, bo launcher nie ma autoloadów.

### Etap 5: pobieranie tylko zmienionych części

- CI tnie PCK na kawałki o zmiennej długości, średnio 64 KB, bez czytania formatu PCK, i publikuje listę sum, ok. 7 KB.
- Launcher kopiuje znane kawałki ze starego PCK, a resztę pobiera przez `Range`. W zmierzonej parze wersji to 3 fragmenty.
- Na końcu sprawdza sumę całego pliku, a przy niezgodności pobiera go w całości.
- Stałe bloki odpadają, bo pliki przesuwają się w paczce: bloki 64 KB wymagały 8,2 MB.

## Ryzyka

| Ryzyko | Co z tym robimy |
|---|---|
| Serwer wdraża się po pushu na `main`, a klienci po tagu, więc zmiana protokołu blokuje graczy do czasu wydania | Tag zaraz po merge'u, a docelowo rozdzielenie tych kroków |
| Złe wydanie trafia do wszystkich automatycznie | Launcher instaluje każdą wersję inną niż obecna. Wycofanie: `gh release edit v0.20.0 --latest` |
| Antywirus lub SmartScreen przy exe bez podpisu | PCK to dane, a exe zmienia się rzadko. Ostrzeżenia dla launchera nie da się usunąć bez certyfikatu |
| Zapora Windows pyta o nowy exe przy hostowaniu | Jednorazowe pytanie, opisane w instrukcji |
| Przenosiny na Steam | Steam aktualizuje grę sam, więc wersja steamowa pomija launcher |
| Adres serwera | Manifest go nie zawiera, a launcher zna tylko adres repozytorium |

## Ustalenia

- Launcher instaluje aktualizację sam, bez pytania, bo gracz i tak potrzebuje tej samej wersji co serwer.
- macOS jest w planie od początku. Jeśli próba wypadnie źle, na Macu zostaje pobieranie całej aplikacji.
- Tagi z myślnikiem, np. `-rc1`, nie trafiają do graczy, bo `latest` je pomija.
- Gracze z v0.20.0 pobiorą ZIP ręcznie jeszcze raz, bo ta wersja nie ma launchera.
