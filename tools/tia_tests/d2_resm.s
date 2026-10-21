; SPDX-License-Identifier: GPL-2.0-or-later
; d2_resm.s -- RESM0 strobed while the missile is ALREADY being drawn on the same line.  ENAM0 stays on for the whole frame (missile
; width 8, NUSIZ0 = $30), so every line shows the missile; each line strobes RESM0 on CPU cycle C = 6, 8, ..., 72 (one per line).  The old
; position is drawn up to the strobe point (hardware: the new position only takes effect on the NEXT line, because RESMx does not send a
; START).  First case where the P31 TIA is expected to differ (it moves the missile on the same line).
; FONTE: Towers, "Missile 0 and Missile 1 Horizontal Position Counters" (RESMx does not generate a START); Stella PG §4.A.
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
        sta WSYNC
        delay 40
        sta RESM0               ; start position: about x = 40
        lda #2
        sta ENAM0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 34, i
        sta WSYNC
        delay 6 + 2 * i - 2
        sta RESM0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
