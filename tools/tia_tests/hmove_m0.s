; SPDX-License-Identifier: GPL-2.0-or-later
; hmove_m0.s -- HMOVE strobed on CPU cycle C = 4, 6, ..., 74 (not only at the start of the line) with M0 as the moving object.  Each test takes
; three lines: one places M0 with RESM0 (the same cycle every time), line A strobes HMOVE on cycle C (HMM0 = $70: 7 pixels left), line B shows M0
; (ENAM0 on from its start).  Missile width 4 (NUSIZ0 = $20).
; FONTE: Towers, "Playing with the HMOVE registers" and "HMOVE during the visible scanline"; Stella PG §4.F (HMOVE).
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
        lda #$70
        sta HMM0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        sta WSYNC
        delay 38
        sta RESM0               ; position of M0 for this test (about x = 50)
        probe HMOVE, ENAM0, 2, 4 + 2 * i
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
