import sys,re,random
sys.path.insert(0,'.')
src=open('test3g.py').read().split("# convert with CROP")[0]
src=src.replace("atari_snes3g.bin","atari_snes17.bin").replace("v==0x81","v==0x21")
src=src.replace("        return super().rd(a)","""        b=(a>>16)&0xFF; o=a&0xFFFF
        if 0x70<=b<=0x72 and o>=0x8000: return C2.fbs[b-0x70][o-0x8000]
        if b in (0,0x80) and o==0x213D:
            if not C2.vq: C2.vq=[240&255,240>>8]
            return C2.vq.pop(0)
        return super().rd(a)""",1).replace("class C2(CPU):","class C2(CPU):\n    fbs=[bytearray(0x8000) for _ in range(3)]\n    vq=[]",1)
exec(src)
random.seed(9)
NT=[141,0,300]
PICL=232; HL=PICL+2     # HDMA lines: 1 black + 232 picture + 1 black, then stop
def mk(n):
    f=bytearray(0x8000)
    f[0]=n&255;f[1]=n>>8
    for k in range(5):
        base=0x4000+k*0x400; size=4 if k<4 else 2
        for L in range(PICL+1):
            o=base+L*size
            if k<4:
                f[o]=k;f[o+1]=k
                if L<PICL: f[o+2]=random.randrange(256);f[o+3]=random.randrange(256)
            else:
                if L<PICL: f[o]=random.choice([0,13]);f[o+1]=255
                else: f[o]=0;f[o+1]=255
    return f
for i in range(3): C2.fbs[i][:]=mk(NT[i])
def run_irq(r0):
    cpu.regs_read[0x2020]=r0
    cpu.writes.clear()
    ret=cpu.PC; cpu.E=0;cpu.M=1;cpu.XF=0
    cpu.push(0);cpu.push(ret>>8);cpu.push(ret&255);cpu.push(cpu.P()); sp=cpu.S+4
    cpu.PC=sym['Nmi']
    while not(cpu.PC==ret and cpu.S==sp): cpu.step()
    return list(cpu.writes)
def hdma(tbl, bank, k):
    size=4 if k<4 else 2; out=[]; p=tbl
    while len(out)<300:
        h=cpu.wram[p]
        if h==0: break
        n=h&0x7F; rep=h&0x80
        ptr=cpu.wram[p+1]|cpu.wram[p+2]<<8; p+=3
        assert ptr>=0x8000,hex(ptr)
        for i in range(n):
            if rep or i==0: last=bytes(C2.fbs[bank][ptr-0x8000+(i if rep else 0)*size:ptr-0x8000+((i if rep else 0)+1)*size])
            out.append(last)
    return out
def expected(bank,k,voff):
    size=4 if k<4 else 2; f=C2.fbs[bank]; base=0x4000+k*0x400; res=[]
    for X in range(HL):
        A=X-voff
        if A<0 or A>=PICL: A=PICL
        res.append(bytes(f[base+A*size:base+(A+1)*size]))
    return res
def check(bank,tag):
    voff=cpu.wram[0x64]; bad=0
    for k in range(5):
        got=hdma(0x2000+k*0x20,bank,k)
        if len(got)!=HL: print(tag,"len",k,len(got)); bad+=1; continue
        bad+=sum(1 for a,b in zip(got,expected(bank,k,voff)) if a!=b)
    print(f"{tag}: voff {voff} bank ${0x70+bank:02X} mismatching lines (of {HL} x5): {bad}")
    assert bad==0
cpu.regs_read[0x4210]=0x80
check(0,"reset tables"); check(2,"reset tables (other bank)")
def d_of(w):
    d={}
    for a,v in w: d.setdefault(a,[]).append(v)
    return d
for n in (0,1,2,3):
    w=run_irq(n); d=d_of(w); nn=n if n<3 else 0
    # DMA writes in order: map then tiles
    srcs=[(d[0x4302][i]|d[0x4303][i]<<8) for i in range(len(d[0x4302]))]
    lens=[(d[0x4305][i]|d[0x4306][i]<<8) for i in range(len(d[0x4305]))]
    n_exp=NT[nn]; n_exp=min(n_exp,512)
    print(f"R0={n}: lock {d[0x2027][0]:#04x} hdma bank {d[0x4317][0]:#x} dma banks {d[0x4304]} src {[hex(s) for s in srcs]} len {lens} vram {[hex(x) for x in d[0x2116]]} scroll {[hex(x) for x in d[0x210E]]} cnt $420B {len(d[0x420B])}")
    assert d[0x2027][0]==0x80|nn and d[0x4317][0]==0x70+nn
    assert srcs[0]==0x8010 and lens[0]==1856 and d[0x2116][0]==0 and d[0x2117][0]==0x18
    if n_exp==0:
        assert len(d[0x420B])==1
    else:
        assert srcs[1]==0x8800 and lens[1]==n_exp*16 and len(d[0x420B])==2 and d[0x2116][1]==0 and d[0x2117][1]==0
    assert d[0x210E][:2]==[0xFF-1,3]
    run_irq(n)
def pad(l,h): cpu.regs_read[0x4218]=l; cpu.regs_read[0x4219]=h
def frame(r0=0):
    global LW
    run_irq(r0); LW=run_irq(r0); return LW
pad(0,0); frame()
assert cpu.wram[0x64]==1 and [v for a,v in LW if a==0x2026]==[0]
check(0,"default"); 
d=d_of(LW)
# L+Select no longer does anything special: game sees them, VOFF stays 8
pad(0x20,0x28); frame(); frame(); assert cpu.wram[0x64]==1 and [v for a,v in LW if a==0x2026][-1]==0
check(0,"VOFF stays 1 (1 black on top, 1 below, then HDMA stops)")
# D-pad without L: game gets it, VOFF untouched
pad(0,0x08); frame(); d=d_of(LW); print("up w/o L: SWCHA",hex(d[0x2020][-1]),"VOFF",cpu.wram[0x64]); assert cpu.wram[0x64]==1 and d[0x2020][-1]!=0xFF
# Select alone -> SWCHB bit1 low ; Start -> bit0 low ; B -> fire
pad(0,0x20); frame(); d=d_of(LW); assert d[0x2021][-1]==0xFD
pad(0,0x10); frame(); d=d_of(LW); assert d[0x2021][-1]==0xFE
pad(0x80,0); frame(); d=d_of(LW); assert d[0x2022][-1]==2
# pause
pad(0x10,0); frame(); pad(0,0); frame(); print("pause",cpu.wram[0x5A],"reg3",[hex(v) for a,v in LW if a==0x2023][-1]); assert cpu.wram[0x5A]==1

# ---- v8: palette key X ----
def frame(r0=0):
    global LW
    w1=run_irq(r0); w2=run_irq(r0); LW=w1+w2; return LW
def regs(tag): return [v for a,v in LW if a==tag]
WINB=0x2020
pad(0x10,0); frame(); pad(0,0); frame()   # leave the pause of the v7 tests
assert cpu.wram[0x5A]==0
pad(0,0); frame(); frame()
assert regs(0x2028)[-1]==0 and cpu.wram[0x6C]==0
# X alone: PAL 0->1, name shown
pad(0x40,0); frame()
print("X: PAL",cpu.wram[0x6C],"TXTUP",cpu.wram[0x6E],"TXTCNT",cpu.wram[0x6D],"reg8",regs(0x2028),"212C",[hex(v) for v in regs(0x212C)])
# v14: BG2 stays off until the new row is in VRAM (no one-frame flash of the old name)
assert cpu.wram[0x6C]==1 and regs(0x2028)[-1]==1 and cpu.wram[0x6E]==1 and cpu.wram[0x6D]==150 and regs(0x212C)[-1]==0x01
# the text row is uploaded at the next V=232 IRQ (phase 1)
w=run_irq(0); d=d_of(w)
print("row upload: vram",hex(d[0x2116][-1]|d[0x2117][-1]<<8),"src",hex(d[0x4302][-1]|d[0x4303][-1]<<8),"len",d[0x4305][-1]|d[0x4306][-1]<<8,"bank",d[0x4304][-1],"TXTUP",cpu.wram[0x6E])
assert (d[0x2116][-1]|d[0x2117][-1]<<8)==0x1C00+26*32 and (d[0x4305][-1]|d[0x4306][-1]<<8)==64 and d[0x4304][-1]==0 and cpu.wram[0x6E]==0
# the bytes at the DMA source are the "Color-2" row (palette 1) of font_txt15.inc
src=d[0x4302][-1]|d[0x4303][-1]<<8
rom8=open('atari_snes17.bin','rb').read()
rows=[l for l in open('font_txt15.inc') if l.strip().startswith('.word')]
exp=bytearray()
for x in rows[1].split(';')[0].replace('.word','').split(','):
    v=int(x.strip().replace('$',''),16); exp+=bytes([v&255,v>>8])
assert rom8[src-0x8000:src-0x8000+64]==bytes(exp) and len(exp)==64
print("row bytes at DMA source = Color-2 row")
# holding X does not repeat
for i in range(5): frame()
assert cpu.wram[0x6C]==1 and regs(0x212C)[-1]==0x03
# 4 presses wrap around: 1->2->3->0
for want in (2,3,0,1):
    pad(0,0); frame(); pad(0x40,0); frame(); assert cpu.wram[0x6C]==want and regs(0x2028)[-1]==want
# name expires after TXTFR frames, then BG2 is off
pad(0,0)
for i in range(160): frame()
assert regs(0x212C)[-1]==0x01 and cpu.wram[0x6D]==0
print("name expires: 212C",hex(regs(0x212C)[-1]))
# X with L, R or Select held does nothing
cur=cpu.wram[0x6C]
for l,h in ((0x60,0),(0x50,0),(0x40,0x20),(0x70,0)):
    pad(0,0); frame(); pad(l,h); frame(); assert cpu.wram[0x6C]==cur,(hex(l),hex(h))
print("X ignored with L/R/Select held")
# ---- v12: Y = Easy -> Normal -> Hard ----
rom12=open('atari_snes17.bin','rb').read()
rows=[l for l in open('font_txt15.inc') if l.strip().startswith('.word')]
def rowbytes(i):
    e=bytearray()
    for x in rows[i].split(';')[0].replace('.word','').split(','):
        v=int(x.strip().replace('$',''),16); e+=bytes([v&255,v>>8])
    return bytes(e)
def ypress():
    pad(0,0); frame(); pad(0,0x40); frame()
    d=d_of(LW); src=d[0x4302][-1]|d[0x4303][-1]<<8
    r=rom12[src-0x8000:src-0x8000+64], regs(0x2021)[-1]
    frame()                                   # v14: BG2 turns on once the row is in VRAM
    return r
pad(0,0); frame(); frame()
assert cpu.wram[0x75]==2 and regs(0x2021)[-1]&0xC0==0xC0       # start: Hard (both A)
for name,idx,sw in (("Easy",4,0x3F),("Normal",5,0xBF),("Hard",6,0xFF),("Easy",4,0x3F)):
    row,swb=ypress()
    print("Y ->",name,"level",cpu.wram[0x75],"SWCHB",hex(swb),"name row ok",row==rowbytes(idx))
    assert row==rowbytes(idx) and swb==sw and cpu.wram[0x6F]==idx and regs(0x212C)[-1]==3
# held Y does not repeat
for i in range(3): frame()
assert cpu.wram[0x75]==0
# Y ignored with Select / L / R / X held
for l,h in ((0,0x60),(0x20,0x40),(0x10,0x40),(0x40,0x40)):
    pad(0,0); frame(); pad(l,h); frame(); assert cpu.wram[0x75]==0,(hex(l),hex(h))
print("Y ignored with Select/L/R/X")
# Start (RESET) still clears bit 0 with Easy
pad(0,0); frame()
pad(0,0x10); frame(); assert regs(0x2021)[-1]==0x3E
print("Start still clears bit 0 with Easy")
pad(0,0); frame()
# ---- v13: text palette rewritten every frame, after the DMAs ----
ph1_seen=0
for i in range(4):
    w=run_irq(0)
    if any(a==0x2121 and v==32 for a,v in w):
        ph1_seen+=1
        idx=max(k for k,(a,v) in enumerate(w) if a==0x420B)
        pk=[k for k,(a,v) in enumerate(w) if a==0x2121 and v==32][0]
        assert pk>idx,"palette written before the last DMA"
        assert [v for a,v in w if a==0x2122]==[0,0,0xE0,3,0xE0,3,0xE0,3]
print("text palette refreshed in",ph1_seen,"of 4 IRQs (the ph1 ones), after the last DMA")
assert ph1_seen==2
# ---- v14: "PAUSE" on screen while paused ----
def one_irq(l,h):
    pad(l,h); return run_irq(0)
def ph1_until_reg3(l,h):
    # runs IRQs one by one until the phase-1 IRQ (the one that writes register 3)
    for _ in range(4):
        w=one_irq(l,h)
        if any(a==0x2023 for a,v in w): return w
    raise AssertionError("no phase-1 IRQ")
pause_row=rowbytes(7)
assert all(x>1 for x in pause_row[26:36:2])   # columns 13..17 hold the 5 letters
pad(0,0); frame(); frame()
if cpu.wram[0x5A]:                            # the Y test above pressed R+Y: leave that pause
    pad(0x10,0); frame(); pad(0,0); frame()
assert cpu.wram[0x5A]==0 and regs(0x212C)[-1]==0x01   # resuming hid PAUSE at once
pad(0x40,0); frame(); pad(0,0); frame()       # X: a palette name is on screen
assert cpu.wram[0x6D]>0 and regs(0x212C)[-1]==0x03
pal0=cpu.wram[0x6C]; lvl0=cpu.wram[0x75]
for rnd in range(2):
    # press R -> pause
    w=ph1_until_reg3(0x10,0); d=d_of(w)
    assert cpu.wram[0x5A]==1 and d[0x2023][-1]&0x10 and cpu.wram[0x6F]==7 and cpu.wram[0x6E]==1 and cpu.wram[0x6D]==0
    assert d[0x212C][-1]==0x01                # row not uploaded yet: no old name shown
    w=one_irq(0x10,0); d=d_of(w)              # V=232: "PAUSE" goes to VRAM
    src=d[0x4302][-1]|d[0x4303][-1]<<8
    assert rom12[src-0x8000:src-0x8000+64]==pause_row and (d[0x2116][-1]|d[0x2117][-1]<<8)==0x1C00+26*32
    pad(0,0); frame(); assert regs(0x212C)[-1]==0x03
    # stays on with no timeout (20 s)
    for i in range(1200): frame()
    assert regs(0x212C)[-1]==0x03 and cpu.wram[0x5A]==1
    # X and Y are ignored while paused: no new name, PAUSE stays
    for l,h in ((0x40,0),(0,0x40)):
        pad(0,0); frame(); pad(l,h); frame(); pad(0,0); frame()
        assert cpu.wram[0x6C]==pal0 and cpu.wram[0x75]==lvl0 and cpu.wram[0x6F]==7 and regs(0x212C)[-1]==0x03
    # press R -> resume: BG2 off in the SAME IRQ that un-pauses the core
    w=ph1_until_reg3(0x10,0); d=d_of(w)
    assert cpu.wram[0x5A]==0 and not d[0x2023][-1]&0x10 and d[0x212C][-1]==0x01, (d[0x2023],d[0x212C])
    pad(0,0)
    for i in range(10): frame()
    assert regs(0x212C)[-1]==0x01 and cpu.wram[0x6D]==0   # the old palette name does not come back
    print("pause round",rnd+1,": PAUSE shown while paused, off in the resume frame")
# after the pause X works again
pad(0x40,0); frame(); pad(0,0); frame()
assert cpu.wram[0x6C]==(pal0+1)&3 and regs(0x212C)[-1]==0x03
pad(0,0)
for i in range(160): frame()
assert regs(0x212C)[-1]==0x01
print("X works again after the pause")
# ---- v15: IRQ lines, 1-line top, DMA diagnostic on L ----
inc=open('font_txt15.inc').read()
DIG0=int(re.search(r'DIG0\s*=\s*\$([0-9A-F]+)',inc).group(1),16)
DCOLN=int(re.search(r'DCOLN\s*=\s*(\d+)',inc).group(1)); DCOLL=int(re.search(r'DCOLL\s*=\s*(\d+)',inc).group(1))
pad(0,0); frame()
ph=[]
for i in range(2):
    w=run_irq(0); ph.append([v for a,v in w if a==0x4209])
assert sorted(x[0] for x in ph)==[1,233], ph
print("IRQ lines: display on at V=1, force blank at V=233")
# v17 public build: L does nothing at all (no diagnostic row, BG2 stays off, no WRAM row DMA)
pad(0,0); frame(); frame()
before=bytes(cpu.wram[0x300:0x340])
for i in range(20):
    pad(0x20,0); w=run_irq(0)
    d=d_of(w)
    assert all((d[0x4302][k]|d[0x4303][k]<<8)!=0x300 for k in range(len(d.get(0x4302,[]))))
    if 0x212C in d: assert d[0x212C][-1]==0x01
assert cpu.wram[0x7E]==0 and cpu.wram[0x7F]==0 and bytes(cpu.wram[0x300:0x340])==before
# the game still gets the pad normally while L is held (fire + d-pad)
pad(0xA0,0x08); frame(); d=d_of(LW); assert d[0x2022][-1]==2 and d[0x2020][-1]!=0xFF
pad(0,0); frame(); frame()
print("v17: L ignored (no diagnostic in the public build)")
# the d-pad and fire still work together with X
pad(0xC0,0x08); frame(); d=d_of(LW); assert d[0x2022][-1]==2 and d[0x2020][-1]!=0xFF
# reset combo still works (it is handled in the V=0 IRQ: make that the next one)
if cpu.wram[0x61]==0: run_irq(0)
pad(0x70,0x20)
cpu.regs_read[0x2020]=0; cpu.writes.clear()
ret=cpu.PC; cpu.E=0;cpu.M=1;cpu.XF=0
cpu.push(0);cpu.push(ret>>8);cpu.push(ret&255);cpu.push(cpu.P()); cpu.PC=sym['Nmi']
for _ in range(20000):
    cpu.step()
    if any(a==0x2A00 for a,v in cpu.writes): break
assert [v for a,v in cpu.writes if a==0x2A00]==[0x81]
print("reset combo still writes $2A00 = $81")
print("ALL OK v17")
