; SPDX-License-Identifier: GPL-2.0-or-later
; resp_hblank.s -- RESP0 strobed inside the horizontal blank and around its end.  One test per CPU cycle C = 2..40 (C <> 3):
; line A strobes RESP0 on cycle C, line B shows the player (GRP0 = $FF, one 8-pixel copy, NUSIZ0 = 0).
; FONTE: Towers, "CPU Clock to Player Pixel Table" (reset before the end of HBLANK: counter held, graphics at pixel 1).
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
        lda #0
        sta VBLANK
        .repeat 39, i
        .if (i + 2) <> 3
        probe RESP0, GRP0, $FF, i + 2
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
