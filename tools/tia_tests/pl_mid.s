; SPDX-License-Identifier: GPL-2.0-or-later
; pl_mid.s -- a player register changed while the sprite is being drawn.  P0 sits at about x = 20 (RESP0 early in the vertical blank), 8 wide.
; Every line writes one register on CPU cycle C = 22, 24, ..., 56 (CLK 66..168, i.e. while pixels 0..100 are on the screen):
; -D WHAT = 0: REFP0 $08 (reflection switches on in the middle of the sprite), 1: GRP0 (from $B1 to $4E), 2: VDELP0 = 1 with an old GRP0 of $0F.
; The scan counter reads REFP0, GRP0 and VDELP0 for every pixel (docs/tia_spec.md sec. 4).
; FONTE: Towers, "Player 0 and Player 1 Graphics Scan Counters"; Stella PG §6.C, §6.D.
        .include "tia_test.inc"
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
        sta HMP0
        sta REFP0
        sta VDELP0
        sta GRP0
        sta WSYNC
        delay 4
        sta RESP0
        .if WHAT = 2
        lda #$0F
        sta GRP0
        lda #0
        sta GRP1                ; copies GRP0 ($0F) into the old register of P0
        .endif
        lda #$B1
        sta GRP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 18, i
        sta WSYNC
        .if WHAT = 0
        lda #$08
        delay 22 + 2 * i - 2 - 2
        sta REFP0
        .elseif WHAT = 1
        lda #$4E
        delay 22 + 2 * i - 2 - 2
        sta GRP0
        .else
        lda #$08
        delay 22 + 2 * i - 2 - 2
        sta VDELP0
        .endif
        sta WSYNC               ; restore for the next test
        lda #0
        sta REFP0
        sta VDELP0
        lda #$B1
        sta GRP0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
