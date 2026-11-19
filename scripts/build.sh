#!/usr/bin/env bash
# Builds RoomGlowUp.rbxlx from the Rojo project. Does not publish anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
rojo build default.project.json -o RoomGlowUp.rbxlx
