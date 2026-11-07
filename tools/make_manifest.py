#!/usr/bin/env python3
"""Tworzy manifest.json wydania. Launcher czyta z niego, co ma pobrac.

Uzycie: python3 tools/make_manifest.py --version 0.21.0 --godot 4.7.2 --builds builds > manifest.json
        python3 tools/make_manifest.py --godot 4.7.2 --print-runtime-id

Identyfikator runtime zmienia sie tylko po zmianie Godota albo GodotSteam, wiec zwykle
gracz pobiera sam PCK. Sumy samego exe nie da sie do tego uzyc, bo eksport zmienia
w nim kilka bajtow naglowka przy kazdym buildzie.
"""

import argparse
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMA = 1


def find_value(path: pathlib.Path, pattern: str) -> str:
    match = re.search(pattern, path.read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        sys.exit("Nie znaleziono %s w %s" % (pattern, path))
    return match.group(1)


def describe(path: pathlib.Path) -> dict:
    if not path.is_file() or path.stat().st_size == 0:
        sys.exit("Brak pliku wydania: %s" % path)
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1 << 20), b""):
            digest.update(block)
    return {"file": path.name, "size": path.stat().st_size, "sha256": digest.hexdigest()}


def platform(builds: pathlib.Path, name: str, runtime_id: str) -> dict:
    runtime = describe(builds / ("Giera-%s-runtime.zip" % name))
    runtime["id"] = runtime_id
    # Launcher pobierze swoja nowa logike tylko wtedy, gdy ma ten sam silnik.
    launcher = describe(builds / ("Giera-%s-launcher.pck" % name))
    launcher["id"] = runtime_id
    return {"pack": describe(builds / ("Giera-%s.pck" % name)), "runtime": runtime, "launcher": launcher}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version")
    parser.add_argument("--godot", required=True)
    parser.add_argument("--builds", type=pathlib.Path)
    parser.add_argument("--print-runtime-id", action="store_true")
    args = parser.parse_args()

    steam = find_value(ROOT / "tools/fetch_godotsteam.sh", r'^VERSION="([^"]+)"$')
    runtime_id = "godot-%s+steam-%s" % (args.godot, steam)
    if args.print_runtime_id:
        print(runtime_id)
        return
    if args.version is None or args.builds is None:
        parser.error("podaj --version i --builds")

    protocol = find_value(ROOT / "scripts/core/net.gd", r"^const PROTOCOL_VERSION := (\d+)$")
    manifest = {
        "schema": SCHEMA,
        "version": args.version,
        "protocol": int(protocol),
        "windows": platform(args.builds, "Windows", runtime_id),
        "macos": platform(args.builds, "macOS", runtime_id),
    }
    json.dump(manifest, sys.stdout, indent=2)
    sys.stdout.write("\n")


main()
