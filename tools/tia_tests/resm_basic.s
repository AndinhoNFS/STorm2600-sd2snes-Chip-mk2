; SPDX-License-Identifier: GPL-2.0-or-later
; resm_basic.s -- RESM0 on CPU cycle C = 2..73 (C <> 3): line A strobes RESM0, line B shows the missile (ENAM0 = 2).  Assemble with
; -D NUS=<NUSIZ0> and -D CBASE=<first cycle> (2 or 38; 36 cycles per ROM) (bits 5:4 = width 1/2/4/8, bits 2:0 = copies) to cover the widths and the copy decodes.
; FONTE: Stella PG §6.B (missile width), Towers, "Missile 0 and Missile 1 Horizontal Position Counters".
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
        .endif
        .ifndef CBASE
        CBASE = 2
        .endif
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #NUS
        sta NUSIZ0
        lda #0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta HMM0
        sta RESMP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        .if (CBASE + i) <> 3
        probe RESM0, ENAM0, 2, CBASE + i
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
