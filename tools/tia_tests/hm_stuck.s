; SPDX-License-Identifier: GPL-2.0-or-later
; hm_stuck.s -- the "stuck motion latch" (HMCLR 20 cycles after HMOVE with HMP1 = $60) and what it does to P1 over the LINES THAT FOLLOW.
; Line A: HMP1 = HMV (default $60) on cycle 19, RESP1 on cycle 23.  Line B: HMOVE (write on cycle 3) and HMCLR on cycle C = 23 (default; -D C=n
; moves it).  Then NLINES lines (default 12) with GRP1 = $FF drawn from cycle 0 on and no HMOVE, so each line shows where P1 is while the
; latch may still be stuck.  Found in a game (Ghoul: the same HMP1/RESP1/HMOVE/HMCLR sequence once per frame, P1 drawn 40 lines later).
; -D RESTROBE adds one more HMOVE on the line after the HMCLR (as Ghoul does); NLINES lines follow.
; FONTE: Towers, "Playing with the HMOVE registers" (a HMCLR 20 cycles after HMOVE leaves the "more movement required" latch set, "during
; visible and non-visible parts of the scanline", "until another HMOVE operation clears the latch").
        .include "tia_test.inc"
        .ifndef HMV
        HMV = $60
        .endif
        .ifndef C
        C = 23
        .endif
        .ifndef NLINES
        NLINES = 12
        .endif
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP1
        lda #0
        sta NUSIZ1
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta GRP1
        sta VDELP1
        sta HMCLR
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 3, i
        sta WSYNC
        lda #HMV
        delay 19 - 2 - 3
        sta HMP1
        sta RESP1
        sta WSYNC
        sta HMOVE
        delay C - 3 - 3
        sta HMCLR
        .ifdef RESTROBE
        sta WSYNC
        sta HMOVE               ; a second HMOVE (HMP1 = 0 now): does it clear the stuck latch, and where does P1 end up?
        .endif
        lda #$FF
        sta WSYNC
        sta GRP1
        .repeat NLINES
        sta WSYNC
        .endrepeat
        lda #0
        sta GRP1
        sta WSYNC
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
