; SPDX-License-Identifier: GPL-2.0-or-later
; res_basic.s -- RESxx on CPU cycle C = CBASE .. CBASE + 35 (C <> 3): line A strobes the reset, line B shows the object (enabled from the start of
; the line until about x = 136).  -D OBJ = 1 M1, 2 BL, 3 P0, 4 P1;  -D NUS = NUSIZ (players, missiles) or CTRLPF (ball: bits 5:4 = width);
; -D CBASE = 2 or 38 (36 cycles per ROM).  The player shows GRP = $B1 so that a position error and a reflection error can be told apart.
; FONTE: Stella PG §4.A (RESxx), §6 (objects); Towers, "Player 0 and Player 1 Horizontal Position Counters".
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
        .endif
        .ifndef CBASE
        CBASE = 2
        .endif
        .ifndef OBJ
        OBJ = 3
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
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta HMM0
        sta HMM1
        sta HMBL
        sta HMP0
        sta HMP1
        sta RESMP0
        sta RESMP1
        .if OBJ = 2
        lda #NUS
        sta CTRLPF
        .elseif OBJ = 4 .or OBJ = 1
        lda #NUS
        sta NUSIZ1
        .else
        lda #NUS
        sta NUSIZ0
        .endif
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        .if (CBASE + i) <> 3
        .if OBJ = 1
        probe_l RESM1, ENAM1, 2, CBASE + i
        .elseif OBJ = 2
        probe_l RESBL, ENABL, 2, CBASE + i
        .elseif OBJ = 3
        probe_l RESP0, GRP0, $B1, CBASE + i
        .else
        probe_l RESP1, GRP1, $B1, CBASE + i
        .endif
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
