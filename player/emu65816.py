#!/usr/bin/env python3
"""Minimal 65816 interpreter, only the instructions used by atari_snes3.s.
Test aid, not a general emulator (binary ADC/SBC only, no interrupts)."""
import sys

class CPU:
    def __init__(s, rom):
        s.rom = rom                      # 32 KB LoROM image
        s.wram = bytearray(0x20000)
        s.fb = bytearray(0x8000)         # bank $70 $8000-$FFFF
        s.regs_read = {}                 # address -> value (hardware regs)
        s.writes = []                    # (addr, value) hardware writes
        s.C = 0; s.X = 0; s.Y = 0; s.S = 0x1FF; s.D = 0; s.DB = 0; s.PB = 0; s.PC = 0
        s.N = s.V = s.Z = s.Cf = 0; s.M = 1; s.XF = 1; s.E = 1; s.I = 1
        s.steps = 0
    # ---- bus
    def rd(s, a):
        a &= 0xFFFFFF; b = a >> 16; o = a & 0xFFFF
        if b == 0x7E: return s.wram[o]
        if b == 0x7F: return s.wram[0x10000 + o]
        if b == 0x70 and o >= 0x8000: return s.fb[o - 0x8000]
        if (b & 0x7F) < 0x40:
            if o < 0x2000: return s.wram[o]
            if 0x2000 <= o < 0x6000: return s.regs_read.get(o, 0)
            if o >= 0x8000: return s.rom[o & 0x7FFF]
        return 0
    def wr(s, a, v):
        a &= 0xFFFFFF; b = a >> 16; o = a & 0xFFFF; v &= 0xFF
        if b == 0x7E: s.wram[o] = v; return
        if b == 0x7F: s.wram[0x10000 + o] = v; return
        if (b & 0x7F) < 0x40:
            if o < 0x2000: s.wram[o] = v; return
            if 0x2000 <= o < 0x6000: s.writes.append((o, v)); return
    def rd16(s, a): return s.rd(a) | (s.rd(a + 1) << 8)
    def wr16(s, a, v): s.wr(a, v); s.wr(a + 1, v >> 8)
    # ---- fetch
    def f8(s):
        v = s.rd((s.PB << 16) | s.PC); s.PC = (s.PC + 1) & 0xFFFF; return v
    def f16(s): return s.f8() | (s.f8() << 8)
    # ---- helpers
    @property
    def A8(s): return s.M == 1
    @property
    def X8(s): return s.XF == 1
    def getA(s): return (s.C & 0xFF) if s.A8 else s.C
    def setA(s, v):
        if s.A8: s.C = (s.C & 0xFF00) | (v & 0xFF)
        else: s.C = v & 0xFFFF
    def nz(s, v, w8):
        m = 0x80 if w8 else 0x8000
        s.N = 1 if v & m else 0
        s.Z = 1 if (v & (0xFF if w8 else 0xFFFF)) == 0 else 0
    def push(s, v): s.wr(s.S, v); s.S = (s.S - 1) & 0xFFFF
    def pull(s): s.S = (s.S + 1) & 0xFFFF; return s.rd(s.S)
    def P(s):
        return (s.N<<7)|(s.V<<6)|(s.M<<5)|(s.XF<<4)|(s.I<<2)|(s.Z<<1)|s.Cf
    def setP(s, p):
        s.N=(p>>7)&1; s.V=(p>>6)&1; s.M=(p>>5)&1; s.XF=(p>>4)&1
        s.I=(p>>2)&1; s.Z=(p>>1)&1; s.Cf=p&1
        if s.XF: s.X &= 0xFF; s.Y &= 0xFF
    # effective addresses
    def ea_dp(s): return (s.D + s.f8()) & 0xFFFF
    def ea_abs(s): return (s.DB << 16) | s.f16()
    def ea_absx(s): return ((s.DB << 16) + s.f16() + s.X) & 0xFFFFFF
    def ea_absy(s): return ((s.DB << 16) + s.f16() + s.Y) & 0xFFFFFF
    def ea_ldpy(s):
        d = (s.D + s.f8()) & 0xFFFF
        p = s.rd(d) | (s.rd(d+1) << 8) | (s.rd(d+2) << 16)
        return (p + s.Y) & 0xFFFFFF
    def ea_ldp(s):
        d = (s.D + s.f8()) & 0xFFFF
        return s.rd(d) | (s.rd(d+1) << 8) | (s.rd(d+2) << 16)
    def load(s, ea, w8):
        return s.rd(ea) if w8 else s.rd16(ea)
    def store(s, ea, v, w8):
        if w8: s.wr(ea, v)
        else: s.wr16(ea, v)
    def imm(s, w8): return s.f8() if w8 else s.f16()
    def branch(s, cond):
        o = s.f8()
        if o & 0x80: o -= 0x100
        if cond: s.PC = (s.PC + o) & 0xFFFF
    def alu(s, op, v, w8):
        a = s.getA()
        if op == 'and': r = a & v
        elif op == 'ora': r = a | v
        elif op == 'eor': r = a ^ v
        elif op == 'adc':
            t = a + v + s.Cf; mask = 0xFF if w8 else 0xFFFF
            s.Cf = 1 if t > mask else 0
            r = t & mask
            s.V = 1 if (~(a ^ v) & (a ^ r)) & (0x80 if w8 else 0x8000) else 0
        elif op == 'sbc':
            mask = 0xFF if w8 else 0xFFFF
            t = a + (v ^ mask) + s.Cf
            s.Cf = 1 if t > mask else 0
            r = t & mask
            s.V = 1 if ((a ^ v) & (a ^ r)) & (0x80 if w8 else 0x8000) else 0
        s.setA(r); s.nz(r, w8)
    def cmp(s, reg, v, w8):
        mask = 0xFF if w8 else 0xFFFF
        r = (reg - v) & mask
        s.Cf = 1 if (reg & mask) >= (v & mask) else 0
        s.nz(r, w8)
    # ---- step
    def step(s):
        s.steps += 1
        op = s.f8()
        A8 = s.A8; X8 = s.X8
        if op == 0x78: s.I = 1
        elif op == 0x58: s.I = 0
        elif op == 0x18: s.Cf = 0
        elif op == 0x38: s.Cf = 1
        elif op == 0xFB:
            s.E, s.Cf = s.Cf, s.E
            if s.E: s.M = 1; s.XF = 1; s.X &= 0xFF; s.Y &= 0xFF
        elif op == 0xC2: s.setP(s.P() & ~s.f8())
        elif op == 0xE2: s.setP(s.P() | s.f8())
        elif op == 0xA9: v = s.imm(A8); s.setA(v); s.nz(v, A8)
        elif op == 0xA2: v = s.imm(X8); s.X = v; s.nz(v, X8)
        elif op == 0xA0: v = s.imm(X8); s.Y = v; s.nz(v, X8)
        elif op in (0xA5, 0xAD, 0xBD, 0xB9, 0xB7, 0xA7):
            ea = {0xA7: s.ea_ldp, 0xA5: s.ea_dp, 0xAD: s.ea_abs, 0xBD: s.ea_absx, 0xB9: s.ea_absy, 0xB7: s.ea_ldpy}[op]()
            v = s.load(ea, A8); s.setA(v); s.nz(v, A8)
        elif op in (0xA4, 0xAC): 
            ea = s.ea_dp() if op == 0xA4 else s.ea_abs()
            v = s.load(ea, X8); s.Y = v; s.nz(v, X8)
        elif op in (0xA6, 0xAE):
            ea = s.ea_dp() if op == 0xA6 else s.ea_abs()
            v = s.load(ea, X8); s.X = v; s.nz(v, X8)
        elif op in (0x85, 0x8D, 0x9D, 0x99, 0x97):
            ea = {0x85: s.ea_dp, 0x8D: s.ea_abs, 0x9D: s.ea_absx, 0x99: s.ea_absy, 0x97: s.ea_ldpy}[op]()
            s.store(ea, s.getA(), A8)
        elif op in (0x86, 0x8E):
            ea = s.ea_dp() if op == 0x86 else s.ea_abs(); s.store(ea, s.X, X8)
        elif op in (0x84, 0x8C):
            ea = s.ea_dp() if op == 0x84 else s.ea_abs(); s.store(ea, s.Y, X8)
        elif op in (0x64, 0x9C):
            ea = s.ea_dp() if op == 0x64 else s.ea_abs(); s.store(ea, 0, A8)
        elif op == 0x9A: s.S = s.X & 0xFFFF
        elif op == 0x4B: s.push(s.PB)
        elif op == 0xAB: s.DB = s.pull()
        elif op == 0x8A:
            if A8: s.C = (s.C & 0xFF00) | (s.X & 0xFF)
            else: s.C = s.X & 0xFFFF
            s.nz(s.getA(), A8)
        elif op == 0x98:
            if A8: s.C = (s.C & 0xFF00) | (s.Y & 0xFF)
            else: s.C = s.Y & 0xFFFF
            s.nz(s.getA(), A8)
        elif op == 0xAA:
            s.X = s.C & (0xFF if X8 else 0xFFFF); s.nz(s.X, X8)
        elif op == 0xA8:
            s.Y = s.C & (0xFF if X8 else 0xFFFF); s.nz(s.Y, X8)
        elif op == 0x48:
            if A8: s.push(s.C & 0xFF)
            else: s.push(s.C >> 8); s.push(s.C & 0xFF)
        elif op == 0x68:
            if A8: v = s.pull(); s.C = (s.C & 0xFF00) | v; s.nz(v, True)
            else: lo = s.pull(); hi = s.pull(); s.C = lo | (hi << 8); s.nz(s.C, False)
        elif op in (0xDA, 0x5A):
            r = s.X if op == 0xDA else s.Y
            if X8: s.push(r & 0xFF)
            else: s.push(r >> 8); s.push(r & 0xFF)
        elif op in (0xFA, 0x7A):
            if X8: v = s.pull()
            else: lo = s.pull(); hi = s.pull(); v = lo | (hi << 8)
            if op == 0xFA: s.X = v
            else: s.Y = v
            s.nz(v, X8)
        elif op == 0x0A:
            a = s.getA(); m = 0x80 if A8 else 0x8000
            s.Cf = 1 if a & m else 0; r = (a << 1) & (0xFF if A8 else 0xFFFF)
            s.setA(r); s.nz(r, A8)
        elif op == 0x4A:
            a = s.getA(); s.Cf = a & 1; r = a >> 1; s.setA(r); s.nz(r, A8)
        elif op == 0xEB:
            s.C = ((s.C & 0xFF) << 8) | ((s.C >> 8) & 0xFF); s.nz(s.C & 0xFF, True)
        elif op == 0x1A:
            r = (s.getA() + 1) & (0xFF if A8 else 0xFFFF); s.setA(r); s.nz(r, A8)
        elif op in (0x29, 0x09, 0x49, 0x69, 0xE9):
            v = s.imm(A8); s.alu({0x29:'and',0x09:'ora',0x49:'eor',0x69:'adc',0xE9:'sbc'}[op], v, A8)
        elif op in (0xE6, 0xC6):
            ea = s.ea_dp(); v = s.load(ea, A8); v = (v + (1 if op == 0xE6 else -1)) & (0xFF if A8 else 0xFFFF)
            s.store(ea, v, A8); s.nz(v, A8)
        elif op == 0xE5:
            v = s.load(s.ea_dp(), A8); s.alu('sbc', v, A8)
        elif op == 0x65:
            v = s.load(s.ea_dp(), A8); s.alu('adc', v, A8)
        elif op in (0x25, 0x05):
            v = s.load(s.ea_dp(), A8); s.alu('and' if op == 0x25 else 'ora', v, A8)
        elif op == 0xC9: s.cmp(s.getA(), s.imm(A8), A8)
        elif op == 0xCD: s.cmp(s.getA(), s.load(s.ea_abs(), A8), A8)
        elif op == 0xC5: s.cmp(s.getA(), s.load(s.ea_dp(), A8), A8)
        elif op == 0xE0: s.cmp(s.X, s.imm(X8), X8)
        elif op == 0xC0: s.cmp(s.Y, s.imm(X8), X8)
        elif op == 0xE8: s.X = (s.X + 1) & (0xFF if X8 else 0xFFFF); s.nz(s.X, X8)
        elif op == 0xC8: s.Y = (s.Y + 1) & (0xFF if X8 else 0xFFFF); s.nz(s.Y, X8)
        elif op == 0xCA: s.X = (s.X - 1) & (0xFF if X8 else 0xFFFF); s.nz(s.X, X8)
        elif op == 0xD0: s.branch(not s.Z)
        elif op == 0xF0: s.branch(s.Z)
        elif op == 0x90: s.branch(not s.Cf)
        elif op == 0xB0: s.branch(s.Cf)
        elif op == 0x80: s.branch(True)
        elif op == 0x4C: s.PC = s.f16()
        elif op == 0x20:
            t = s.f16(); r = (s.PC - 1) & 0xFFFF
            s.push(r >> 8); s.push(r & 0xFF); s.PC = t
        elif op == 0x60:
            lo = s.pull(); hi = s.pull(); s.PC = ((lo | (hi << 8)) + 1) & 0xFFFF
        elif op == 0x40:
            s.setP(s.pull()); lo = s.pull(); hi = s.pull(); s.PC = lo | (hi << 8)
            if not s.E: s.PB = s.pull()
        else:
            raise Exception("unimplemented opcode %02X at %02X:%04X" % (op, s.PB, (s.PC - 1) & 0xFFFF))
