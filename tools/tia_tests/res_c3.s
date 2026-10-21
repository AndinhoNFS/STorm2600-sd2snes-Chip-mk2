; SPDX-License-Identifier: GPL-2.0-or-later
; res_c3.s -- RESxx strobed on CPU cycle 3 of the line, i.e. `sta WSYNC / sta RESxx` (the commonest way to place an object at the left edge).  Line A
; strobes it (colour clock 8, inside the HBLANK); line B shows the object.  -D OBJ: 0 = M0, 1 = M1, 2 = ball, 3 = P0, 4 = P1;  -D WID = 0..3 is
; the width code (NUSIZ bits 5:4 for the missiles, CTRLPF bits 5:4 for the ball; the players use NUSIZ 0 and 5 for WID = 0 and 1).
; -D SAME: the object is already enabled on line A, so line A itself shows where the strobe left it (the common `enable always on, strobe each line`).
; Found in a game (Video Chess hack: RESM0 right after WSYNC, width 8; the second model of tia_obj.v drew 2 pixels too far left).
; FONTE: Stella PG §4.A (RESxx); Towers, "CPU Clock to Player Pixel Table" (HBLANK strobes).
        .include "tia_test.inc"
        .ifndef OBJ
        OBJ = 0
        .endif
        .ifndef WID
        WID = 3
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
        lda #0
        sta PF0
        sta PF1
        sta PF2
        sta GRP0
        sta GRP1
        sta ENAM0
        sta ENAM1
        sta ENABL
        sta HMCLR
        sta RESMP0
        sta RESMP1
        .if OBJ = 2
        lda #(WID << 4)
        sta CTRLPF
        .else
        lda #0
        sta CTRLPF
        .if OBJ < 2
        lda #(WID << 4)
        sta NUSIZ0
        sta NUSIZ1
        .else
        lda #(WID * 5)
        sta NUSIZ0
        sta NUSIZ1
        .endif
        .endif
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 30
        .ifdef SAME
        lda #2
        .if OBJ = 0
        sta ENAM0
        .elseif OBJ = 1
        sta ENAM1
        .elseif OBJ = 2
        sta ENABL
        .elseif OBJ = 3
        lda #$FF
        sta GRP0
        .else
        lda #$FF
        sta GRP1
        .endif
        .endif
        sta WSYNC
        .if OBJ = 0
        sta RESM0
        .elseif OBJ = 1
        sta RESM1
        .elseif OBJ = 2
        sta RESBL
        .elseif OBJ = 3
        sta RESP0
        .else
        sta RESP1
        .endif
        .ifndef SAME
        sta WSYNC
        .else
        delay_loop 14
        .endif
        lda #2
        .if OBJ = 0
        sta ENAM0
        .elseif OBJ = 1
        sta ENAM1
        .elseif OBJ = 2
        sta ENABL
        .elseif OBJ = 3
        lda #$FF
        sta GRP0
        .else
        lda #$FF
        sta GRP1
        .endif
        delay_loop 10
        nop
        lda #0
        sta ENAM0
        sta ENAM1
        sta ENABL
        sta GRP0
        sta GRP1
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
