; SPDX-License-Identifier: GPL-2.0-or-later
; m_noreset.s -- M1 (or the ball with -D OBJ=2) enabled WITHOUT ever being reset (no RESM1 / RESBL), right after power-up.  A game does this on purpose or
; by accident (Attack Of The Mighty Aliens From Outer Space draws M1 as a laser and only ever places P1).  The position is whatever
; the power-up state of the object counter makes it; the reference models start theirs in a state of their own, so this ROM shows where.
; -D HM: one HMOVE (HMM1 = 0, never written) is strobed first, as the game does once per frame.
; FONTE: medida, out/passo33.txt (the power-up state is not documented in Towers or in the Stella PG).
        .include "tia_test.inc"
        .ifndef OBJ
        OBJ = 1
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
        sta NUSIZ0
        sta NUSIZ1
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta GRP0
        sta GRP1
        sta HMCLR
        sta WSYNC
        lda #0
        sta VBLANK
        .ifdef HM
        sta WSYNC
        sta HMOVE
        .endif
        lda #2
        .repeat 20
        sta WSYNC
        .if OBJ = 1
        sta ENAM1
        .else
        sta ENABL
        .endif
        .endrepeat
        lda #0
        sta ENAM1
        sta ENABL
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
