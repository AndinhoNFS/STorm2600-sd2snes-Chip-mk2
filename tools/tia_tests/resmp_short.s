; SPDX-License-Identifier: GPL-2.0-or-later
; resmp_short.s -- RESMP0 held for a SHORT window.  Line 0 places P0 (RESP0 on CPU cycle PCYC, default 30, everything off).  Line A: GRP0 = $FF
; and ENAM0 on at the start, then RESMP0 = 2 written on CPU cycle C = 8 + 3 * i and released again WIN cycles later (default 13, i.e. 39 colour
; clocks); line B (GRP0 off, ENAM0 on) shows where the missile is.  The window sweeps along line A, so the test says whether the missile is
; moved to the player's centre only if the centre of the player's main copy passes while RESMP0 = 1 (as a reset line gated by RESMP would do) or
; whenever RESMP0 is released (the missile jumps to the player's current position).  -D NUS = NUSIZ0.
; Found in a game (Attack Of The Mighty Aliens From Outer Space: RESMP1 = 2, then 0, 15 cycles later, on the line before P1 is drawn).
; FONTE: Stella PG §4.D (RESMPx); Towers, "Missile 0 and Missile 1 Horizontal Position Counters" (the missile counter is reset when the player's
; scan counter is at the centre decode of the main copy).
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
        .endif
        .ifndef PCYC
        PCYC = 30
        .endif
        .ifndef WIN
        WIN = 13
        .endif
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta HMM0
        sta HMP0
        sta RESMP0
        sta GRP0
        sta ENAM0
        lda #NUS
        sta NUSIZ0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 18, i
        sta WSYNC
        delay PCYC - 2
        sta RESP0
        delay 24
        sta RESM0               ; the missile is somewhere else (about colour clock 105) before the window
        sta WSYNC               ; A
        lda #2
        sta ENAM0
        delay (8 + 3 * i) - 8
        sta RESMP0
        lda #0
        delay WIN - 5
        sta RESMP0
        sta WSYNC               ; B
        lda #2
        sta ENAM0
        delay_loop 11
        nop
        lda #0
        sta ENAM0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
