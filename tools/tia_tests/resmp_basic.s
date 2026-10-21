; SPDX-License-Identifier: GPL-2.0-or-later
; resmp_basic.s -- RESMP0 (missile locked to player 0).  Three lines per test: (0) RESP0 on CPU cycle C = CBASE .. CBASE + 35 places P0 with
; everything off; (A) GRP0 = $FF and RESMP0 = 2 (the player is drawn, the missile is held at its centre); (B) RESMP0 released, ENAM0 on, GRP0 off:
; line B shows where the missile ended up.  -D NUS = NUSIZ0 (width and copies of the player; the missile width comes from the same register).
; FONTE: Stella PG §4.D (RESMPx: missile locked to the player, centred); Towers, "Missile 0 and Missile 1 Horizontal Position Counters"
; (the missile counter is reset when the player's scan counter is at %100 during the main copy).
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
        .endif
        .ifndef CBASE
        CBASE = 2
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
        lda #NUS
        sta NUSIZ0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 36, i
        .if (CBASE + i) <> 3
        sta WSYNC
        delay (CBASE + i) - 2
        sta RESP0
        sta WSYNC               ; A
        lda #$FF
        sta GRP0
        lda #2
        sta RESMP0
        sta ENAM0
        sta WSYNC               ; B
        lda #0
        sta RESMP0
        sta GRP0
        delay_loop 11
        nop
        lda #0
        sta ENAM0
        .endif
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
