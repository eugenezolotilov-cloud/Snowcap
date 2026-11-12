#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
sources=(Sources/Snowhush/*.swift)
sources=( ${sources:#*/main.swift} )
sources=( ${sources:#*/AppDelegate.swift} )
xcrun swiftc -O -whole-module-optimization "${sources[@]}" tests/SnowballChecks.swift -o "$scratch/check-snowballs"
"$scratch/check-snowballs"
