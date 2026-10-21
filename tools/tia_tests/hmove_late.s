; SPDX-License-Identifier: GPL-2.0-or-later
; hmove_late.s -- HMOVE strobed on CPU cycle C = 4, 6, ..., 74 of the line (not only at the start); P0 is placed first in the vertical
; blank, HMP0 = $70 (7 pixels left); line A strobes HMOVE on cycle C, line B shows P0 (GRP0 = $FF).
; FONTE: Towers, "Playing with the HMOVE registers" (HMOVE on cycle 74: no comb, movement only to the left) and "HMOVE during the
; visible scanline".
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
        sta HMCLR
        sta WSYNC
        delay 20
        sta RESP0               ; P0 position for every test line
        lda #$70
        sta HMP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        probe HMOVE, GRP0, $FF, 4 + 2 * i
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
