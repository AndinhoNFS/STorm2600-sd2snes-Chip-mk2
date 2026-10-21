; SPDX-License-Identifier: GPL-2.0-or-later
; gp_seq.s -- the register sequence of a game (Grand Prix, lines 198-203 of its frame), cut down to P0 only.  Line 0: HMCLR late in the line
; (HMP0 = 0).  Line K0: HMOVE, RESP0 on cycle 24 (colour clock 71), then HMP0 = $70 on cycle 27.  Line K1: HMOVE (moves P0 by 7), NUSIZ0 = NUS on cycle 38,
; HMP0 = 0 on cycle 41.  Lines K2, K3: HMOVE (HMP0 = 0), GRP0 = $FF for the line, HMCLR on cycle 47 in the line before K0 (the game did it there).  Variants, -D:
;   NUS = 6 (default) or 0 (NUSIZ0 not changed);  HM70 = 1 (default) writes HMP0 = $70 in K0, 0 skips it;  K1HM = 1 (default) does the HMOVE in K1.
; Repeats 8 times per frame with the player shown in K2 and K3; every test is a block of 5 lines.
; FONTE: medida, out/passo33.txt (Grand Prix, first line where the second model of tia_obj.v differed from the first reference).
        .include "tia_test.inc"
        .ifndef SLIDE
        SLIDE = 100
        .endif
        .ifndef NUS
        NUS = 6
        .endif
        .ifndef HM70
        HM70 = 1
        .endif
        .ifndef K1HM
        K1HM = 1
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
        ; the game places P0 once (RESP0, HMP0 = $20) and then strobes HMOVE on every line: P0 slides 2 pixels to the left per line
        sta WSYNC
        lda #$20
        sta HMP0
        delay 27 - 3 - 2
        sta RESP0
        ldy #SLIDE
slide:  sta WSYNC
        sta HMOVE
        dey
        bne slide
        .repeat 8, i
        sta WSYNC
        sta HMOVE
        lda #0
        sta NUSIZ0
        delay 47 - 3 - 2 - 3 - 3
        sta HMCLR
        sta WSYNC                       ; K0
        sta HMOVE
        delay 24 - 3 - 2
        lda #$70
        sta RESP0
        .if HM70 = 1
        sta HMP0
        .endif
        sta WSYNC                       ; K1
        .if K1HM = 1
        sta HMOVE
        .endif
        lda #NUS
        ldy #0
        delay 38 - 3 - 2 - 2 - 3
        sta NUSIZ0
        sty HMP0
        sta WSYNC                       ; K2
        sta HMOVE
        lda #$FF
        sta GRP0
        delay 24
        lda #0
        sta GRP0
        sta WSYNC                       ; K3
        sta HMOVE
        lda #$FF
        sta GRP0
        delay 24
        lda #0
        sta GRP0
        sta WSYNC
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
