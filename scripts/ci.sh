#!/usr/bin/env bash
# Full local pipeline: syntax, lint, format check, tests, build, place verification.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== syntax";  lune run scripts/check.luau
echo "== lint";    selene src
echo "== format";  stylua --check src tests scripts
echo "== tests";   lune run tests/run.luau
echo "== build";   mkdir -p build && rojo build default.project.json -o build/ChromaTurf.rbxlx
echo "== verify";  lune run scripts/verify-place.luau build/ChromaTurf.rbxlx
echo "ALL CHECKS PASSED"
