; SPDX-License-Identifier: GPL-2.0-or-later
; nusiz_mid.s -- NUSIZ0 written in the middle of the line, while P0 is being drawn.  P0 sits at about x = 12 (RESP0 early in the vertical
; blank), GRP0 = $FF, NUSIZ0 = 0 at the start of each line, then NUSIZ0 = 5 (double width) is written on CPU cycle C = 24..40
; (CLK 72..120): the scan counter reads NUSIZ every CLK, so the part of the sprite still to be drawn stretches.
; FONTE: Towers, "Player 0 and Player 1 Graphics Scan Counters" (the NUSIZ register can be changed at any time).
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
        sta WSYNC
        delay 20
        sta RESP0
        lda #$FF
        sta GRP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 17, i
        sta WSYNC
        lda #0
        sta NUSIZ0
        lda #5
        delay 24 + i - 2 - 2 - 3 - 2
        sta NUSIZ0
        .endrepeat
        lda #0
        sta NUSIZ0
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
