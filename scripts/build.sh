#!/usr/bin/env bash
# Builds release/ChromaTurf.rbxlx (open it directly in Roblox Studio).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p release
rojo build default.project.json -o release/ChromaTurf.rbxlx
rojo build default.project.json -o release/ChromaTurf.rbxl
echo "Built release/ChromaTurf.rbxl and release/ChromaTurf.rbxlx"
