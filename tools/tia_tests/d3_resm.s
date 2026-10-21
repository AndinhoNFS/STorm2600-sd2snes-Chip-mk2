; SPDX-License-Identifier: GPL-2.0-or-later
; d3_resm.s -- RESM0 in the HBLANK of a line where the START of the PREVIOUS reset is still waiting.  Test i: line A strobes RESM0 on CPU cycle
; C = 20 + i (colour clock 59 .. 98, so the next START falls inside or just before the next line's HBLANK and stays frozen there until the
; HBLANK ends); line B (ENAM0 already on) strobes RESM0 AGAIN on cycle 3 (`sta WSYNC / sta RESM0`) and shows the missile itself.  -D NUS = NUSIZ0
; (default $30 = width 8).  -D HMV=<byte> replaces the second RESM0 by a HMOVE (cycle 3) with HMM0 = HMV.  Found in a game (Video Chess hack: the missile showed 0-9 instead of 2-9 on the line after a late RESM0).
; FONTE: Towers, "Missile 0 and Missile 1 Horizontal Position Counters" (RESMx resets the position counter only); medida, out/passo33.txt.
        .include "tia_test.inc"
        .ifndef NUS
        NUS = $30
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
        sta GRP0
        sta HMM0
        sta RESMP0
        lda #NUS
        sta NUSIZ0
        .ifdef HMV
        lda #HMV
        sta HMM0
        .endif
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 40, i
        sta WSYNC
        delay (20 + i) - 2
        sta RESM0               ; A
        lda #2
        sta ENAM0
        sta WSYNC               ; B
        .ifdef HMV
        sta HMOVE
        .else
        sta RESM0
        .endif
        delay_loop 14
        nop
        lda #0
        sta ENAM0
        .endrepeat
        frame_bottom
        jmp frame
        .segment "VECTORS"
        .word start, start
