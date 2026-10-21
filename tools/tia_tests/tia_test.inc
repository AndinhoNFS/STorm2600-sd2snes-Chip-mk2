; SPDX-License-Identifier: GPL-2.0-or-later
; tia_test.inc -- registers of the TIA (write addresses, from the public register list) and small macros for the
; corner-case test ROMs of Step 33.  ca65 syntax.
; FONTE: Stella PG, "Write address summary" (addresses of the TIA registers).

VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
RSYNC   = $03
NUSIZ0  = $04
NUSIZ1  = $05
COLUP0  = $06
COLUP1  = $07
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
REFP0   = $0B
REFP1   = $0C
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESP1   = $11
RESM0   = $12
RESM1   = $13
RESBL   = $14
GRP0    = $1B
GRP1    = $1C
ENAM0   = $1D
ENAM1   = $1E
ENABL   = $1F
HMP0    = $20
HMP1    = $21
HMM0    = $22
HMM1    = $23
HMBL    = $24
VDELP0  = $25
VDELP1  = $26
VDELBL  = $27
RESMP0  = $28
RESMP1  = $29
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C
DUMMY   = $2D           ; unused TIA write address, used as a harmless 3-cycle filler

; delay exactly N CPU cycles (N = 0 or N >= 2), with NOPs and one 3-cycle filler store when N is odd; the argument is
; parenthesised everywhere because ca65 substitutes macro arguments textually (`delay c - 2` with c = 4 + 2 * i)
.macro delay n
        .if (n) = 1
        .error "delay 1 is impossible"
        .endif
        .if ((n) .mod 2) = 1
        sta DUMMY
        .repeat ((n) - 3) / 2
        nop
        .endrepeat
        .else
        .repeat (n) / 2
        nop
        .endrepeat
        .endif
.endmacro

; start of the program: sei, cld, clear TIA and RAM, stack
.macro cold_start
        sei
        cld
        ldx #$FF
        txs
        lda #0
        tay
@clr:   sta $00,x
        dex
        bne @clr
.endmacro

; vertical sync (3 lines) and 37 lines of vertical blank; leaves VBLANK ON; the caller turns it off
.macro frame_top
        lda #2
        sta VSYNC
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC
        lda #2
        sta VBLANK
        ldy #36
@vb:    sta WSYNC
        dey
        bne @vb
.endmacro

; overscan: 30 lines
.macro frame_bottom
        lda #2
        sta VBLANK
        ldy #30
@os:    sta WSYNC
        dey
        bne @os
.endmacro

; busy-wait of 5*K+1 cycles (K >= 1): ldx #K / dex / bne; keep the loop inside one page so the branch never costs a cycle
.macro delay_loop k
        .local l
        ldx #k
        ; (page crossing of the branch only shifts the END of line B, which the tests do not use)
l:      dex
        bne l
.endmacro

; PROBE: line A strobes `res` on CPU cycle C (the write is the last cycle of the STA; C >= 2, C <> 3) with the object
; OFF; line B (next line) has the object ON from its start to near its end, so line B shows where line A's strobe put it.
.macro probe res, en, onval, c
        sta WSYNC
        delay c - 2
        sta res
        sta WSYNC
        lda #onval
        sta en
        delay_loop 10
        nop
        lda #0
        sta en
.endmacro

; PROBE_L: like PROBE but the object stays on until about x = 136 (the loop is 11 x 5 cycles)
.macro probe_l res, en, onval, c
        sta WSYNC
        delay (c) - 2
        sta res
        sta WSYNC
        lda #onval
        sta en
        delay_loop 11
        nop
        lda #0
        sta en
.endmacro
