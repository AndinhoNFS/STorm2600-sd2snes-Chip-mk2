; SPDX-License-Identifier: GPL-2.0-or-later
; powerup.s -- an object that was NEVER reset (no RESxx at all, not even the zero-fill loop of cold_start): where is it?  The position counter
; of a real chip powers up in an arbitrary state; every model picks its own.  Games that enable an object they never placed (Mortal Kurling!
; enables the ball without RESBL) show that choice.  -D OBJ: 0 = M0 (ENAM0, width 4)  1 = M1  2 = ball  3 = P0 (GRP0 = $FF)  4 = P1.
; FONTE: medida, out/passo33.txt (the power-up state is not documented by Towers or the Stella PG).
        .include "tia_test.inc"
        .ifndef OBJ
        OBJ = 2
        .endif
        .segment "CODE"
start:  sei
        cld
        ldx #$FF
        txs
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        sta COLUP1
        sta COLUPF
        lda #0
        sta NUSIZ0
        sta NUSIZ1
        .if OBJ = 2
        lda #$20
        .endif
        sta CTRLPF
        lda #0
        sta PF0
        sta PF1
        sta PF2
        sta GRP0
        sta GRP1
        sta ENAM0
        sta ENAM1
        sta ENABL
        sta WSYNC
        lda #0
        sta VBLANK
        lda #2
        .repeat 20
        sta WSYNC
        .if OBJ = 0
        sta ENAM0
        .elseif OBJ = 1
        sta ENAM1
        .elseif OBJ = 2
        sta ENABL
        .elseif OBJ = 3
        lda #$FF
        sta GRP0
        .else
        lda #$FF
        sta GRP1
        .endif
        .endrepeat
        lda #0
        sta ENAM0
        sta ENAM1
        sta ENABL
        sta GRP0
        sta GRP1
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
