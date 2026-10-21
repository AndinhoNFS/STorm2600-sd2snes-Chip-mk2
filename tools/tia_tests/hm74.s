; SPDX-License-Identifier: GPL-2.0-or-later
; hm74.s -- a single strobe (HMOVE, or the harmless DUMMY write for the baseline) on CPU cycle C with HMM0 = HMV, M0 (width 4) as the
; moving object; the same structure as hmove_m0.s.  Settles the HMOVE-on-cycle-74 case: assemble with -D C=<cycle> -D HMV=<byte> -D STROBE=$2A (HMOVE) or $2D (DUMMY).
; FONTE: Towers, "Playing with the HMOVE registers"; Stella PG §4.F (HMOVE).
        .include "tia_test.inc"
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #$20
        sta NUSIZ0
        lda #0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta ENAM0
        sta RESMP0
        sta HMCLR
        lda #HMV
        sta HMM0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 8
        sta WSYNC
        delay 38
        sta RESM0
        probe STROBE, ENAM0, 2, C
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
