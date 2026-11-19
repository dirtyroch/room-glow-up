#!/usr/bin/env bash
# Builds RoomGlowUp.rbxlx from the Rojo project. The place file is generated
# and is not published anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
rojo build default.project.json -o RoomGlowUp.rbxlx
echo "Built RoomGlowUp.rbxlx"
