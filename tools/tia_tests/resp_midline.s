; SPDX-License-Identifier: GPL-2.0-or-later
; resp_midline.s -- ONE RESP0 per line in the visible part, with GRP0 = $FF on the whole time (NUSIZ0 = 0).  Test lines have RESP0 on
; CPU cycle C = 22, 25, ..., 73; every line shows the copy left by the PREVIOUS strobe, not the new one.
; FONTE: Towers, "Player 0 and Player 1 Horizontal Position Counters" (RESPx does not generate a START signal: the main copy only
; appears when the counter wraps, 160 CLK later) and "The Re-trigger Trick".
        .include "tia_test.inc"
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #0
        sta NUSIZ0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta HMP0
        lda #$FF
        sta GRP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 18, i
        sta WSYNC
        delay 22 + 3 * i - 2
        sta RESP0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
