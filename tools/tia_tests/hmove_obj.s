; SPDX-License-Identifier: GPL-2.0-or-later
; hmove_obj.s -- HMOVE strobed on CPU cycle C = 4, 6, ..., 74 (not only at the start of the line) with one object as the moving object.
; The object is placed again with its RESxx before EVERY test (the test of one instant must not depend on the previous ones), HMxx = HMV (default $70 = 7 pixels left).  Three lines per test: one places the object, line A strobes HMOVE on cycle C, line B shows the object.
; Assemble with -D OBJ=<n>:  1 = M1 (width 4)   2 = ball (width 4)   3 = P0 (GRP0 = $FF, one copy)   4 = P0 double size (NUSIZ0 = 5)
; 5 = P0 quad size (NUSIZ0 = 7)   6 = P0 with three copies close (NUSIZ0 = 3).
; FONTE: Towers, "Playing with the HMOVE registers" and "HMOVE during the visible scanline"; Stella PG §4.F (HMOVE).
        .include "tia_test.inc"
        .ifndef OBJ
        OBJ = 3
        .endif
        .ifndef HMV
        HMV = $70               ; HMxx byte (value in the upper nibble)
        .endif
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        sta COLUP1
        sta COLUPF
        .if OBJ = 4
        lda #5
        .elseif OBJ = 5
        lda #7
        .elseif OBJ = 6
        lda #3
        .else
        lda #0
        .endif
        sta NUSIZ0
        lda #0
        sta PF0
        sta PF1
        sta PF2
        sta ENAM0
        sta ENAM1
        sta ENABL
        sta RESMP0
        sta RESMP1
        sta GRP0
        sta HMCLR
        .if OBJ = 2
        lda #$20
        .else
        lda #0
        .endif
        sta CTRLPF              ; ball width 4 for OBJ = 2
        .if OBJ = 1
        lda #$20
        sta NUSIZ1
        .endif
        lda #HMV
        .if OBJ = 1
        sta HMM1
        .elseif OBJ = 2
        sta HMBL
        .else
        sta HMP0
        .endif
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        sta WSYNC
        delay 38
        .if OBJ = 1
        sta RESM1
        probe HMOVE, ENAM1, 2, 4 + 2 * i
        .elseif OBJ = 2
        sta RESBL
        probe HMOVE, ENABL, 2, 4 + 2 * i
        .else
        sta RESP0
        probe HMOVE, GRP0, $FF, 4 + 2 * i
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
