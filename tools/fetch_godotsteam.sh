#!/usr/bin/env bash
# Pobiera GodotSteam do addons/godotsteam. Biblioteki Steama nie trafiaja do repo.
# Instaluje tylko pliki potrzebne na Windows, bez wtyczki edytora, ktora sama aktualizuje dodatek.
# Bez tego kroku gra tez dziala, tylko bez konta Steam.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="4.23.2"
SHA512="da3dbde4c4fc0435ec40374f8c7a9ce4c75cec667737942031acfbd82e13b561e05e1fac09f2ead938784478988b28904f7326d36980ec439d52d2eb1ae90bc9"
NAME="godotsteam-${VERSION}-gdextension-plugin-4.4.zip"
URL="https://codeberg.org/godotsteam/godotsteam/releases/download/v${VERSION}-gde/${NAME}"
INSIDE="godotsteam/addons/godotsteam"

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

curl -fsSL --retry 3 -o "$temp/$NAME" "$URL"
(cd "$temp" && echo "$SHA512  $NAME" | sha512sum -c - > /dev/null)
unzip -q "$temp/$NAME" "$INSIDE/godotsteam.gdextension" "$INSIDE/license.md" "$INSIDE/win64/*" -d "$temp/unpacked"

rm -rf addons/godotsteam
mkdir -p addons
mv "$temp/unpacked/$INSIDE" addons/godotsteam
echo "GodotSteam $VERSION w addons/godotsteam"
