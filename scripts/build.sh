#!/usr/bin/env bash
# Builds build/ChromaTurf.rbxlx (open it directly in Roblox Studio).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rojo build default.project.json -o build/ChromaTurf.rbxlx
echo "Built build/ChromaTurf.rbxlx"
