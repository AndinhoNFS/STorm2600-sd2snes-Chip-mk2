; SPDX-License-Identifier: GPL-2.0-or-later
; resp_double.s -- TWO RESP0 on the same line, K cycles apart (K = 3, 5..12), GRP0 = $FF always.  Assemble with -D NUS=<NUSIZ0>:
; NUS = 0 (one copy) shows an EMPTY line (the second strobe resets the counter before it completes the 160 CLK: the main copy is
; never drawn); NUS = 3 (three copies close) shows the close and medium copies of each strobe.
; FONTE: Towers, "The Re-trigger Trick, and all that jazz".
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
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
        sta HMP0
        lda #$FF
        sta GRP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 3, j
        .repeat 8, k
        sta WSYNC
        delay 18 + 12 * j - 2
        sta RESP0
        .if (k + 5) <> 4
        delay (k + 5) - 3
        .endif
        sta RESP0
        .endrepeat
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
