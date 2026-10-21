; SPDX-License-Identifier: GPL-2.0-or-later
; hmclr_mid.s -- HMCLR (or a new value in HMP0) written WHILE the HMOVE is still moving.  Test i: line 0 places P0 (RESP0 on cycle 38), line A:
; `sta WSYNC / sta HMOVE` (write on cycle 3) and then the second write on CPU cycle C = 8 + i; line B shows P0 (GRP0 = $FF).
; HMP0 = HMV (default $60) before the HMOVE.  -D WHAT = 0: HMCLR (default)   1: HMP0 = $00 (same effect, other register)   2: HMP0 = $80.
; FONTE: Towers, "Playing with the HMOVE registers" (writing HMxx or HMCLR while the motion counter runs; the Cosmic Ark stars and Rabbit
; Transit cases); Stella PG §4.F ("do not change HMxx for 24 cycles after an HMOVE").
        .include "tia_test.inc"
        .ifndef HMV
        HMV = $60
        .endif
        .ifndef WHAT
        WHAT = 0
        .endif
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
        sta GRP0
        sta HMCLR
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 40, i
        lda #HMV
        sta HMP0
        sta WSYNC
        delay 38 - 2 - 2
        sta RESP0
        sta WSYNC
        sta HMOVE
        .if WHAT = 0
        delay (8 + i) - 3 - 3
        sta HMCLR
        .elseif WHAT = 1
        lda #0
        delay (8 + i) - 3 - 2 - 3
        sta HMP0
        .else
        lda #$80
        delay (8 + i) - 3 - 2 - 3
        sta HMP0
        .endif
        sta WSYNC
        lda #$FF
        sta GRP0
        delay_loop 10
        nop
        lda #0
        sta GRP0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
