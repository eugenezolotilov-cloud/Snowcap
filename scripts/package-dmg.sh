#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

builder=${DMGBUILD:-dmgbuild}
if ! command -v "$builder" >/dev/null; then
    echo 'dmgbuild is required. Install it or set DMGBUILD to its executable path.' >&2
    exit 1
fi
app="$PWD/build/Snowcap.app"
if [[ ! -d "$app" ]]; then
    echo 'Run ./build.sh first.' >&2
    exit 1
fi
codesign --verify --deep --strict "$app"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
xcrun swift scripts/make-snowcap-dmg-background.swift "$scratch/background.png" 1
xcrun swift scripts/make-snowcap-dmg-background.swift "$scratch/background@2x.png" 2
tiffutil -cathidpicheck "$scratch/background.png" "$scratch/background@2x.png" -out "$scratch/background.tiff"
"$builder" -s scripts/snowcap-dmg-settings.py -D app="$app" -D background="$scratch/background.tiff" Snowcap "$scratch/Snowcap.dmg"
hdiutil verify "$scratch/Snowcap.dmg"
mkdir -p dist
mv -f "$scratch/Snowcap.dmg" dist/Snowcap.dmg
echo 'Built dist/Snowcap.dmg'
