; SPDX-License-Identifier: GPL-2.0-or-later
; hmove_c3.s -- the commonest use of HMOVE: `sta WSYNC / sta HMOVE` (the write lands on CPU cycle 3 of the line).  Test i: line 0 places P0 with
; RESP0 on CPU cycle C = 20 + 2 i (colour clocks 60..140), line A strobes HMOVE right after WSYNC, line B shows P0 (GRP0 = $FF).
; Assemble with -D NUS=<NUSIZ0> (default 0), -D HMV=<HMP0 byte> (default $70), -D C0=<first RESP0 cycle> (default 20) and -D HMC=<CPU cycle of the HMOVE write, default 3> and -D GAP=<empty lines between the RESP0 and the HMOVE> (default 0).
; FONTE: Stella PG §4.F (HMOVE); Towers, "Playing with the HMOVE registers".
        .include "tia_test.inc"
        .ifndef NUS
        NUS = 0
        .endif
        .ifndef HMV
        HMV = $70
        .endif
        .ifndef C0
        C0 = 20                 ; RESP0 on CPU cycle C0 + 2 i (use 21 for the odd cycles)
        .endif
        .ifndef HMC
        HMC = 3                 ; CPU cycle the HMOVE write lands on (3 = right after WSYNC; >= 5 adds a delay)
        .endif
        .ifndef GAP
        GAP = 0
        .endif
        .segment "CODE"
start:  cold_start
frame:  frame_top
        lda #$02
        sta COLUBK
        lda #$36
        sta COLUP0
        lda #NUS
        sta NUSIZ0
        lda #0
        sta CTRLPF
        sta PF0
        sta PF1
        sta PF2
        sta GRP0
        sta HMCLR
        lda #HMV
        sta HMP0
        sta WSYNC
        lda #0
        sta VBLANK
        .repeat 160 / (GAP + 4), i
        sta WSYNC
        delay (C0 + 2 * (i .mod 40)) - 2
        sta RESP0
        .repeat GAP
        sta WSYNC
        .endrepeat
        sta WSYNC
        .if HMC > 3
        delay HMC - 3
        .endif
        sta HMOVE
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
