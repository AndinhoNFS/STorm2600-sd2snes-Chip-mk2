; SPDX-License-Identifier: GPL-2.0-or-later
; resp_hm.s -- RESxx strobed INSIDE the HBLANK that the HMOVE extends.  Every test: line A strobes HMOVE at the start of the line (cycle 3, the
; normal use: the first 8 pixels are blanked and the HBLANK ends 8 colour clocks late) and then RESxx on CPU cycle C = 18, 19, ..., 33
; (colour clocks 54 to 99: before, inside and after the extended blank, which ends at colour clock 76); line B shows the object.
; HMxx = 0 (the HMOVE only extends the blank).  Assemble with -D OBJ=<n>:  0 = M0 (width 4)   2 = ball (width 4)   3 = P0 (GRP0 = $FF).
; Found in a game (Grand Prix: RESP0 on colour clock 71 right after an HMOVE) where the first model of tia_obj.v put P0 two pixels to the
; right of the reference.
; FONTE: Towers, "Playing with the HMOVE registers" (extended HBlank) and "CPU Clock to Player Pixel Table"; Stella PG §4.A, §4.F.
        .include "tia_test.inc"
        .ifndef OBJ
        OBJ = 3
        .endif
.macro probe_hm res, en, onval, c
        sta WSYNC
        sta HMOVE
        delay (c) - 6
        sta res
        sta WSYNC
        lda #onval
        sta en
        delay_loop 10
        nop
        lda #0
        sta en
.endmacro
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        sta COLUPF
        lda #0
        sta NUSIZ0
        sta PF0
        sta PF1
        sta PF2
        sta ENAM0
        sta ENABL
        sta RESMP0
        sta GRP0
        sta HMCLR
        .if OBJ = 2
        lda #$20
        .else
        lda #0
        .endif
        sta CTRLPF
        .if OBJ = 0
        lda #$20
        sta NUSIZ0
        .endif
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 16, i
        .if OBJ = 0
        probe_hm RESM0, ENAM0, 2, 18 + i
        .elseif OBJ = 2
        probe_hm RESBL, ENABL, 2, 18 + i
        .else
        probe_hm RESP0, GRP0, $FF, 18 + i
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
