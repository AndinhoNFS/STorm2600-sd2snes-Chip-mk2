; SPDX-License-Identifier: GPL-2.0-or-later
; sc_ram.s -- Superchip RAM test (F8SC and F6SC).  One bank per assembly; the Makefile joins the banks.
;   -D BANK=1  the last bank (the core powers up in it; an emulator that starts in bank 0 gets here through $F100): writes the 128 bytes of RAM through $1000-$107F with
;              the pattern x ^ $A5, reads them back through $1080-$10FF and compares, then does the same with x ^ $FF;
;              the number of wrong bytes goes to $80.  Then it switches to bank 0 and back (the RAM is shared by all banks).
;   -D BANK=0  after the switch: reads the 128 bytes back (pattern x ^ $FF), the number of wrong bytes goes to $81, and
;              switches back to the last bank.
;   -D HS_TO0 = hotspot of bank 0 ($1FF8 for F8, $1FF6 for F6);  HS_LAST = hotspot of the last bank ($1FF9 for both)
; The result is on the screen: COLUBK green when both counts are 0, red otherwise.  Without the Superchip RAM the window
; is plain ROM (zeros) and the screen is red.
; FONTE: layout of the Superchip as in the Stella Programmer's Guide / the public cartridge description (128 bytes, write port
; first, read port 128 bytes above); the test itself is original.
        .include "tia_test.inc"
        .ifndef BANK
        BANK = 1
        .endif
        .ifndef HS_TO0
        HS_TO0 = $1FF8
        .endif
        .ifndef HS_LAST
        HS_LAST = $1FF9
        .endif
        .segment "CODE"
start:
        .if BANK = 0
        lda HS_LAST             ; started in another bank (Stella starts F8/F6 in bank 0): go to the last one,
                                ; which continues at $F103
        .else
        jmp main                ; the core starts in the last bank; after a bank switch the CPU lands on main
main:
        cold_start
        ldy #0
        ldx #$7F
fill_a: txa
        eor #$A5
        sta $1000,x
        dex
        bpl fill_a
        ldx #$7F
chk_a:  txa
        eor #$A5
        cmp $1080,x
        beq ok_a
        iny
ok_a:   dex
        bpl chk_a
        ldx #$7F
fill_b: txa
        eor #$FF
        sta $1000,x
        dex
        bpl fill_b
        ldx #$7F
chk_b:  txa
        eor #$FF
        cmp $1080,x
        beq ok_b
        iny
ok_b:   dex
        bpl chk_b
        sty $80
        jmp $F200
        .endif
        .segment "SWITCH"
        .if BANK = 1
        lda HS_TO0              ; the next instruction is fetched from bank 0, at $F203
        nop
        nop
        nop
        .else
        nop
        nop
        nop
        nop
        nop
        nop
        ldy #0                  ; bank 0, $F203
        ldx #$7F
chk_0:  txa
        eor #$FF
        cmp $1080,x
        beq ok_0
        iny
ok_0:   dex
        bpl chk_0
        sty $81
        jmp $F300
        .endif
        .segment "BACK"
        .if BANK = 1
        nop
        nop
        nop
        jmp show                ; bank 1 again, at $F303
        .else
        lda HS_LAST             ; the next instruction is fetched from the last bank
        .endif
        .if BANK = 1
        .segment "CODE"
show:   lda #$FF
frame:  frame_top
        lda $80
        ora $81
        beq green
        lda #$44
        bne set
green:  lda #$C6
set:    sta COLUBK
        lda #0
        sta VBLANK
        ldy #192
@l:     sta WSYNC
        dey
        bne @l
        frame_bottom
        jmp frame
        .endif
        .segment "VECTORS"
        .word start, start
