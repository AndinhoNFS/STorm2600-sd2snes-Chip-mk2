#!/bin/sh
# Emulator vs core, frames 120 300 600 of each game.  Results in $OUT (default out/).
#   GAMES="pacman" NS="60 200" OUT=out/x TB_ARGS="+yofs=-2" ./run_all.sh
cd "$(dirname "$0")" || exit 1
NS="${NS:-120 300 600}"
OUT="${OUT:-out}"
mkdir -p "$OUT"
for g in ${GAMES:-riverraid pacman enduro pitfall boxing frostbite}; do
  PYTHONPATH=pylib python3 tools/emu_frame.py "roms/$g.a26" "$OUT/$g" $NS 2>/dev/null | grep '^emulator'
  pre=$(awk '$1=="pre"{print $2}' "$OUT/$g""_emu.meta")
  PYTHONPATH=pylib python3 tools/core_frame.py "roms/$g.a26" "$OUT/$g" "$pre" $NS
  PYTHONPATH=pylib python3 tools/compare.py "$OUT/$g" $NS
done
