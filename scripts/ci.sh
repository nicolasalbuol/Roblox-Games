#!/usr/bin/env bash
# Full local pipeline: syntax, lint, format check, tests, build, place verification.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== syntax";  lune run scripts/check.luau
echo "== lint";    selene src
echo "== format";  stylua --check src tests scripts
echo "== tests";   lune run tests/run.luau
echo "== build";   mkdir -p release && rojo build default.project.json -o release/ChromaTurf.rbxlx
echo "== verify";  lune run scripts/verify-place.luau release/ChromaTurf.rbxlx
echo "ALL CHECKS PASSED"
