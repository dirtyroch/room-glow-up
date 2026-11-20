#!/usr/bin/env bash
# Rebuild every mesh (two Blender processes), then hero stills.
# Usage: tools/meshes/run_all.sh [outdir] [ids...]
set -euo pipefail
cd "$(dirname "$0")/../.."
B=${BLENDER:-/workspace/tools/blender/blender}
OUT=${1:-/workspace/rgu-renders/mesh}; shift || true
IDS=${*:-$(python3 -c "import ast,re;print(' '.join(re.findall(r'^def (\w+)\(M\)', open('tools/meshes/items.py').read(), re.M)))")}
python3 tools/meshes/art.py
set -- $IDS
half=$(( ($# + 1) / 2 ))
A=$(echo $IDS | tr ' ' '\n' | head -n $half | tr '\n' ' ')
Z=$(echo $IDS | tr ' ' '\n' | tail -n +$((half + 1)) | tr '\n' ' ')
$B -b -P tools/meshes/build.py -- $A > /tmp/meshbuild-a.log 2>&1 &
$B -b -P tools/meshes/build.py -- $Z > /tmp/meshbuild-b.log 2>&1
wait
grep -h "^BUILT\|Error" /tmp/meshbuild-a.log /tmp/meshbuild-b.log
python3 tools/meshes/finishes.py
python3 tools/meshes/surfaces.py
python3 tools/meshes/manifest.py
mkdir -p "$OUT"
$B -b -P tools/meshes/hero.py -- "$OUT" $A > /tmp/meshhero-a.log 2>&1 &
$B -b -P tools/meshes/hero.py -- "$OUT" $Z > /tmp/meshhero-b.log 2>&1
wait
grep -h "^HERO\|Error" /tmp/meshhero-a.log /tmp/meshhero-b.log
