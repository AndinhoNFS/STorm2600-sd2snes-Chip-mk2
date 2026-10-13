atari_compare -- emulator (ALE / Stella core) versus our core in simulation

  ./run_all.sh                         three games, frames 120 300 600 -> out/
  NS="60 200" GAMES="pacman" ./run_all.sh

  tools/emu_frame.py  ROM OUT N...     frame N from the ALE, headless  -> OUT_N_emu.png (160 x 210)
  tools/core_frame.py ROM OUT PRE N... frame N from a26_core + a26_vidwr (Verilator) -> OUT_N_core.png
  tools/compare.py    OUT N...         report + OUT_N_side.png (emulator | core | differences in red)

  roms/      copies of the three .a26 files (from the SD card, read only)
  pylib/     ale-py, numpy, pillow (pip --target, nothing installed system-wide)
  sim/       tb_frames.v; build/ = Verilator output.  Sources are read from ../fpga (atari_core in the working tree).
  out/report.txt   the last comparison

Notes
  * Stella itself and xvfb are not installed in this WSL; the ALE is Stella's core without a window.
  * The ALE powers on, idles 60 frames, holds RESET for 8 frames and plays the game's start
    actions; frame N counts from there.  The simulation holds the RESET switch on the same frames.
  * The simulation runs one colour clock every 4 clk with a ROM that answers at once, so it is
    the core's video logic that is compared, not the 96 MHz shell (a26_mem, a26_top, the player).
  * palette_ntsc.inc of the SNES player was not found: colours seen in the emulator use the
    emulator's RGB, the rest an approximation.  All comparisons are made on colour indices.

Colour sampling study (step 16)
  PYTHONPATH=pylib python3 tools/color_study.py     six games -> out/colors/report.txt and
                                                    out/colors/<game>_<frame>_rules.png
                                                    (emulator | per-pixel core | pixel 1 | pixel 159 | first drawn)
  sim/tb_trace.v            tb_frames plus a per-pixel trace, joystick input and a histogram of
                            the colour-register writes (build/obj_trace)
  out/colors/a26_vidwr_px16.diff    proposed change to a26_vidwr.v (NOT applied to atari_core)

Player size study (step 18)
  PYTHONPATH=pylib python3 tools/nusiz_study.py build/obj_trace/tb_trace <label>
                            offset of the players against the emulator, by NUSIZ size
  out/nusiz/report.txt      before / after the stretched-player fix;  out/nusiz/tia_nusiz.diff

Stretched buffers, fixed window (step 20)
  ./run_all.sh              now six games; OUT=out/v9 keeps the results apart (out/v9_report.txt)
  TB_ARGS="+yofs=-3" ...    passes extra arguments to tb_frames (+yofs = signed window offset)
  tools/a26lib.py           read_fb reads the new layout (32 stretched tiles per row, tables at
                            word $2000.., window at $2800) and returns the picture both 256 wide
                            (meta["C256"]) and un-stretched to 160; stretch() applies the core's
                            5 -> 8 pattern to an emulator frame
  tools/compare.py          first line of each report: emulator frame stretched 5 -> 8 against the
                            256-wide core picture, row for row, and the top difference in lines
  tools/check_hdma.py       tiles, colour tables and window against the per-pixel trace
  sim/tb_frames.v           +vsdbg=<frame> prints where VSYNC / VBLANK change; the header of a
                            .fb file has scan_lines and cc_frame (colour clocks) from VSYNC to VSYNC
  bak_v8/                   the tool as it was for the 20-tile layout
  Pac-Man: the ALE applies a per-ROM "YStart" (33 instead of 34) to the known md5; with one
  unused byte changed (default properties) its picture moves up one row and equals the core.

Tile dictionary (step 21b)
  tools/a26lib.py           read_fb rebuilds the picture from header + map + tile list and counts
                            map / numbering / duplicate errors in format_errors; meta["ntiles"]
  tools/tile_count.py       besides the count, compares every dumped frame as the dictionary
                            wrote it against the writer's direct tiles (the step-20 picture)
  sim/tb_full.v             the whole a26_top with slot_model at the real clock ratio;
                            -GSLOT_LAT=90 = PSRAM slot six times slower (build/obj_full90)
  out/v10_report.txt, out/tiles/report.txt, out/hdma/report_v10.txt   results of this step
  bak_v9/                   the tool as it was for the step-20 layout

Width 1:1 (step 22)
  tools/a26lib.py           read_fb: the picture is columns 48..207 of the 256 (tiles 6..25), no
                            stretching; tiles outside must be zero and the window 48 (56 with the
                            HMOVE bar) .. 207, else format_errors; place() puts a 160-wide frame there
  sim/tb_tiles.v            also dumps the colour source of every captured pixel, taken from the
                            pixel stream itself, and the window table
  tools/tile_count.py       third table: picture rebuilt from map + list against that pixel stream
                            (JOBS=6 runs in parallel)
  out/tiles/report.txt, out/v11_report.txt, out/hdma/report_v11.txt, out/full/v11/   results;
  out/tiles/report_v10.txt  the step-21b result.  out/largura_160_vs_512.py ran with the tool in
  bak_v10/ (it needs the stretched layout).
  bak_v10/                  the tool as it was for the stretched (step 21b) layout
