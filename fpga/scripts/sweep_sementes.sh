#!/bin/bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh > /dev/null
cd ~/pristine/verilog/sd2snes_atari || exit 1
[ -f fpga_atari_v11.bit ] || { cp -p fpga_atari.bit fpga_atari_v11.bit; cp -p main.bit main_v11.bit; }
mkdir -p sweep12b
win=""
for t in ${SEEDS:-9 10 11 12 13 14 15 16 17 18 19 20 2 3 4 5}; do
  sed -i -E "s/(Starting Placer Cost Table \(1-100\) (Map|Par)\" xil_pn:value=\")[0-9]+/\1$t/" *.xise
  rm -f main_map.ncd main.ncd
  make main.ncd IGNORE_TIMING=1 > sweep12b/build_t$t.log 2>&1; rc=$?
  if [ ! -f main.ncd ]; then
    echo "seed $t: BUILD FAILED rc=$rc"; grep -m4 -E '^ERROR|FATAL_ERROR' sweep12b/build_t$t.log
    if ! [ -f main.ngc ] || grep -q "^ERROR:\(HDLCompilers\|Xst\|NgdBuild\|ConstraintSystem\)" sweep12b/build_t$t.log; then break; fi
    continue
  fi
  mkdir -p sweep12b/t$t; cp -f main.par main_map.mrp sweep12b/t$t/
  res=$(awk -F'|' '/TS_(CLK21|snes_a26_clkin1) = PERIOD/ {gsub(/ /,"",$3); gsub(/ /,"",$5); print $3, $5; exit}' main.par)
  luts=$(grep -m1 "Total Number of 4 input LUTs" main_map.mrp | awk '{print $7}')
  met=$(grep -c "All constraints were met" main.par)
  echo "seed $t: 96MHz slack/errors = $res ; all met = $met ; LUTs $luts"
  ok=$(echo "$res" | awk '{s=$1; sub(/ns/,"",s); print (s+0 >= 0.010) ? 1 : 0}'); if [ "$met" = "1" ] && [ "$ok" = "1" ]; then win=$t; break; fi
done
if [ -n "$win" ]; then
  echo "winner: $win"
  make main.bit > sweep12b/build_bit.log 2>&1; echo "make main.bit exit: $?"
  ../../utils/rle main.bit fpga_atari.bit; echo "rle exit: $?"
  ls -l main.bit fpga_atari.bit; md5sum main.bit fpga_atari.bit
  sed -n '/Constraint  *|/,/All constraints/p' main.par
  grep -n "Number of Slice Flip Flops\|Number of occupied Slices\|Total Number of 4 input LUTs\|Number of RAMB16s" main_map.mrp
  grep -n "Cost Table" *.xise
else
  echo "NO SEED CLOSED"
fi
