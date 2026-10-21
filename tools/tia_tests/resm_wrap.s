; SPDX-License-Identifier: GPL-2.0-or-later
; resm_wrap.s -- missile that straddles the right edge of the screen.  Groups of 4 lines: A strobes RESM0 on CPU cycle C = 60..73 (late in the
; line, the missile ends up near x = 150..159), B and C have ENAM0 on for the whole line (width 8, NUSIZ0 = $30), D has it off.  Shows on which
; line the part of the missile that is cut by the HBLANK is drawn at the left edge (same line, or the next one).
; FONTE: Towers, "Missile 0 and Missile 1 Horizontal Position Counters" (the counters stop in the HBLANK); Stella PG §4.A.
        .include "tia_test.inc"
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #$30
        sta NUSIZ0
        lda #0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta HMM0
        sta RESMP0
        sta ENAM0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 14, i
        sta WSYNC               ; A: strobe
        delay 58 + i
        sta RESM0
        sta WSYNC               ; B: ENAM on from the start of the line
        lda #2
        sta ENAM0
        sta WSYNC               ; C
        sta WSYNC               ; D: off
        lda #0
        sta ENAM0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
