#!/usr/bin/env python3
"""Sprawdza launcher od pierwszej instalacji po wycofanie zlej wersji, na lokalnym serwerze wydan.

Uzycie: python3 tools/launcher_test.py --launcher sciezka/do/Giera.exe --builds folder --runtime-id ID

Folder musi zawierac PCK i runtime gry dla tego systemu. Launcher ma miec wpisany ten sam
identyfikator runtime, co --runtime-id, bo pierwsza instalacja kopiuje wtedy jego silnik.
Test uruchamia gre jako serwer bez okna i nie dotyka prawdziwej instalacji gracza.
"""

import argparse
import functools
import hashlib
import http.server
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import threading
import time

WINDOWS = sys.platform == "win32"
PLATFORM = "windows" if WINDOWS else "macos"
PLATFORM_FILE = "Windows" if WINDOWS else "macOS"
GAME = "GieraGame.exe" if WINDOWS else "GieraGame"
GAME_PORT = "8767"
LAUNCHER_TIMEOUT = 240
START_SECONDS = 6.0

errors = 0


def check(label, passed):
    global errors
    print("[test] %s: %s" % ("OK " if passed else "BLAD", label), flush=True)
    if not passed:
        errors += 1


def describe(path):
    data = path.read_bytes()
    return {"file": path.name, "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *unused):
        pass


class Release:
    def __init__(self, site, builds):
        self.site = site
        self.builds = builds
        self.pack = builds / ("Giera-%s.pck" % PLATFORM_FILE)
        self.runtime = builds / ("Giera-%s-runtime.zip" % PLATFORM_FILE)
        self.latest = site / "latest" / "download"
        self.latest.mkdir(parents=True)

    def publish(self, version, runtime_id, pack=None, wrong_sha=False):
        folder = self.site / "download" / ("v" + version)
        folder.mkdir(parents=True)
        pack_file = folder / self.pack.name
        if pack is None:
            shutil.copyfile(self.pack, pack_file)
        else:
            pack_file.write_bytes(pack)
        shutil.copyfile(self.runtime, folder / self.runtime.name)
        pack_info = describe(pack_file)
        if wrong_sha:
            pack_info["sha256"] = "0" * 64
        runtime_info = describe(folder / self.runtime.name)
        runtime_info["id"] = runtime_id
        manifest = {"schema": 1, "version": version, PLATFORM: {"pack": pack_info, "runtime": runtime_info}}
        (self.latest / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


class Install:
    def __init__(self, launcher, game_dir, log):
        self.launcher = launcher
        self.dir = game_dir
        self.log = log

    def run(self, base):
        with self.log.open("a", encoding="utf-8") as output:
            # Gra dziedziczy wyjscie launchera, wiec czekamy na jego koniec, a nie na zamkniecie potoku.
            process = subprocess.run(
                [str(self.launcher), "--headless", "--", "--update-base=" + base, "--game-dir=" + str(self.dir), "--server", "--port=" + GAME_PORT],
                stdout=output, stderr=output, timeout=LAUNCHER_TIMEOUT)
        time.sleep(START_SECONDS)
        return process.returncode

    def state(self):
        path = self.dir / "installed.json"
        return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}

    def version(self):
        return self.state().get("version", "")

    def pack(self):
        return self.dir / "GieraGame.pck"

    def temp_files(self):
        return [path.name for path in self.dir.glob("*.tmp")]


def game_running():
    if WINDOWS:
        output = subprocess.run(["tasklist", "/FI", "IMAGENAME eq " + GAME], capture_output=True, text=True, errors="replace").stdout
        return GAME.lower() in output.lower()
    return subprocess.run(["pgrep", "-x", GAME], capture_output=True).returncode == 0


def stop_game():
    if WINDOWS:
        subprocess.run(["taskkill", "/F", "/IM", GAME], capture_output=True)
    else:
        subprocess.run(["pkill", "-x", GAME], capture_output=True)
    for _ in range(40):
        if not game_running():
            break
        time.sleep(0.25)
    time.sleep(0.5)


def scenarios(release, install, base, runtime_id):
    print("[test] pierwsza instalacja", flush=True)
    release.publish("1.0.0", runtime_id)
    install.run(base)
    check("wersja 1.0.0 zainstalowana", install.version() == "1.0.0")
    check("silnik skopiowany z launchera", install.state().get("runtime_id") == runtime_id and (install.dir / GAME).exists())
    if WINDOWS:
        check("biblioteki obok silnika", (install.dir / "steam_api64.dll").exists() or not (install.launcher.parent / "steam_api64.dll").exists())
    check("gra dziala", game_running())
    stop_game()

    print("[test] nowa wersja", flush=True)
    release.publish("1.1.0", runtime_id)
    install.run(base)
    check("wersja 1.1.0 zainstalowana", install.version() == "1.1.0")
    check("poprzedni PCK zachowany", (install.dir / "GieraGame.pck.prev").exists())
    check("gra zglosila start", (install.dir / "started.txt").exists())
    check("gra dziala po aktualizacji", game_running())
    stop_game()

    print("[test] ta sama wersja", flush=True)
    before = install.pack().stat().st_mtime_ns
    install.run(base)
    check("PCK nie jest pobierany ponownie", install.pack().stat().st_mtime_ns == before)
    stop_game()

    print("[test] zla suma", flush=True)
    release.publish("1.2.0", runtime_id, wrong_sha=True)
    install.run(base)
    check("zla suma nie zmienia wersji", install.version() == "1.1.0")
    check("zla suma nie zostawia plikow", install.temp_files() == [])
    check("gra dziala mimo bledu aktualizacji", game_running())
    stop_game()

    print("[test] zepsuty manifest", flush=True)
    (release.latest / "manifest.json").write_text("<html>blad</html>", encoding="utf-8")
    install.run(base)
    check("zepsuty manifest nie zmienia wersji", install.version() == "1.1.0")
    check("gra dziala mimo zepsutego manifestu", game_running())
    stop_game()

    print("[test] brak sieci", flush=True)
    install.run("http://127.0.0.1:9/")
    check("brak sieci nie zmienia wersji", install.version() == "1.1.0")
    check("gra dziala bez sieci", game_running())
    stop_game()

    print("[test] gra dziala podczas aktualizacji", flush=True)
    release.publish("1.3.0", runtime_id)
    install.run("http://127.0.0.1:9/")
    check("gra dziala przed aktualizacja", game_running())
    before = install.pack().stat().st_mtime_ns
    install.run(base)
    check("dzialajaca gra blokuje aktualizacje", install.version() == "1.1.0" and install.pack().stat().st_mtime_ns == before)
    check("dzialajaca gra nie jest zla wersja", "bad_version" not in install.state())
    stop_game()

    print("[test] nowy silnik", flush=True)
    release.publish("1.4.0", "nowy-silnik")
    install.run(base)
    check("silnik pobrany z wydania", install.state().get("runtime_id") == "nowy-silnik")
    check("wersja 1.4.0 zainstalowana", install.version() == "1.4.0")
    check("gra dziala na nowym silniku", game_running())
    stop_game()

    print("[test] wersja, ktora sie nie uruchamia", flush=True)
    release.publish("1.5.0", "nowy-silnik", pack=b"to nie jest PCK" * 100)
    install.run(base)
    check("powrot do poprzedniej wersji", install.version() == "1.4.0")
    check("zla wersja zapamietana", install.state().get("bad_version") == "1.5.0")
    check("gra dziala po wycofaniu", game_running())
    stop_game()
    before = install.pack().stat().st_mtime_ns
    install.run(base)
    check("zla wersja nie instaluje sie ponownie", install.pack().stat().st_mtime_ns == before and install.version() == "1.4.0")
    stop_game()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", required=True, type=pathlib.Path)
    parser.add_argument("--builds", required=True, type=pathlib.Path)
    parser.add_argument("--runtime-id", required=True)
    args = parser.parse_args()

    root = pathlib.Path(tempfile.mkdtemp(prefix="giera launcher "))
    site = root / "site"
    site.mkdir()
    handler = functools.partial(QuietHandler, directory=str(site))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d/" % server.server_port

    log = root / "launcher.log"
    # Spacja i polskie znaki w sciezce sprawdzaja uruchamianie gry z typowego folderu gracza.
    install = Install(args.launcher.resolve(), root / "gra ąć", log)
    try:
        print("[test] bez gry i bez sieci", flush=True)
        check("launcher konczy sie bledem", install.run("http://127.0.0.1:9/") == 1)
        scenarios(Release(site, args.builds.resolve()), install, base, args.runtime_id)
    finally:
        stop_game()
        server.shutdown()
    if errors > 0:
        print(log.read_text(encoding="utf-8", errors="replace")[-4000:])
    print("[test] %s" % ("BLEDY: %d" % errors if errors > 0 else "wszystko OK"), flush=True)
    shutil.rmtree(root, ignore_errors=True)
    sys.exit(1 if errors > 0 else 0)


main()
