#!/bin/bash
# Varredura de sementes de placement (Starting Placer Cost Table de map e par).
# Uso, dentro de verilog/sd2snes_atari/ (gerado por make_atari_shell.py), com o ISE 14.7 no PATH:
#   SEEDS="13 11 9 7" ../../fpga/scripts/sweep_sementes.sh      (ou o caminho onde estiver este script)
# Para na primeira semente em que todas as restricoes fecham e a folga a 96 MHz e' >= 0,010 ns; entao
# gera main.bit e fpga_atari.bit (comprimido com utils/rle do sd2snes).  RLE = caminho do utils/rle
# (padrao: ../../utils/rle, como no common.mk).
[ -n "$XILINX" ] || { echo "rode antes: source <ISE 14.7>/settings64.sh"; exit 1; }
RLE=${RLE:-../../utils/rle}
mkdir -p sweep
win=""
for t in ${SEEDS:-13 11 9 7 17 10 6 8 12 14 15 16 18 19 20}; do
  sed -i -E "s/(Starting Placer Cost Table \(1-100\) (Map|Par)\" xil_pn:value=\")[0-9]+/\1$t/" *.xise
  rm -f main_map.ncd main.ncd
  make main.ncd IGNORE_TIMING=1 > sweep/build_t$t.log 2>&1; rc=$?
  if [ ! -f main.ncd ]; then
    echo "seed $t: BUILD FAILED rc=$rc"; grep -m4 -E '^ERROR|FATAL_ERROR' sweep/build_t$t.log
    if ! [ -f main.ngc ] || grep -q "^ERROR:\(HDLCompilers\|Xst\|NgdBuild\|ConstraintSystem\)" sweep/build_t$t.log; then break; fi
    continue
  fi
  mkdir -p sweep/t$t; cp -f main.par main_map.mrp sweep/t$t/
  res=$(awk -F'|' '/TS_(CLK21|snes_a26_clkin1) = PERIOD/ {gsub(/ /,"",$3); gsub(/ /,"",$5); print $3, $5; exit}' main.par)
  luts=$(grep -m1 "Total Number of 4 input LUTs" main_map.mrp | awk '{print $7}')
  met=$(grep -c "All constraints were met" main.par)
  echo "seed $t: 96MHz slack/errors = $res ; all met = $met ; LUTs $luts"
  ok=$(echo "$res" | awk '{s=$1; sub(/ns/,"",s); print (s+0 >= 0.010) ? 1 : 0}'); if [ "$met" = "1" ] && [ "$ok" = "1" ]; then win=$t; break; fi
done
if [ -n "$win" ]; then
  echo "winner: $win"
  make main.bit > sweep/build_bit.log 2>&1; echo "make main.bit exit: $?"
  "$RLE" main.bit fpga_atari.bit; echo "rle exit: $?"
  ls -l main.bit fpga_atari.bit; md5sum main.bit fpga_atari.bit
  sed -n '/Constraint  *|/,/All constraints/p' main.par
  grep -n "Number of Slice Flip Flops\|Number of occupied Slices\|Total Number of 4 input LUTs\|Number of RAMB16s" main_map.mrp
else
  echo "NO SEED CLOSED"
  exit 1
fi
