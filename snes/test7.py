import sys,re,random
sys.path.insert(0,'.')
src=open('test3g.py').read().split("# convert with CROP")[0]
src=src.replace("atari_snes3g.bin","atari_snes7.bin").replace("v==0x81","v==0x21")
src=src.replace("        return super().rd(a)","""        b=(a>>16)&0xFF; o=a&0xFFFF
        if 0x70<=b<=0x72 and o>=0x8000: return C2.fbs[b-0x70][o-0x8000]
        return super().rd(a)""",1).replace("class C2(CPU):","class C2(CPU):\n    fbs=[bytearray(0x8000) for _ in range(3)]",1)
exec(src)
random.seed(9)
NT=[141,0,300]
def mk(n):
    f=bytearray(0x8000)
    f[0]=n&255;f[1]=n>>8
    for k in range(5):
        base=0x4000+k*0x400; size=4 if k<4 else 2
        for L in range(225):
            o=base+L*size
            if k<4:
                f[o]=k;f[o+1]=k
                if L<224: f[o+2]=random.randrange(256);f[o+3]=random.randrange(256)
            else:
                if L<224: f[o]=random.choice([0,13]);f[o+1]=255
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
    while len(out)<239:
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
    for X in range(239):
        A=X-voff
        if A<0 or A>=224: A=224
        res.append(bytes(f[base+A*size:base+(A+1)*size]))
    return res
def check(bank,tag):
    voff=cpu.wram[0x64]; bad=0
    for k in range(5):
        got=hdma(0x2000+k*0x20,bank,k)
        if len(got)!=239: print(tag,"len",k,len(got)); bad+=1; continue
        bad+=sum(1 for a,b in zip(got,expected(bank,k,voff)) if a!=b)
    print(f"{tag}: voff {voff} bank ${0x70+bank:02X} mismatching lines (of 239 x5): {bad}")
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
    assert srcs[0]==0x8010 and lens[0]==1792 and d[0x2116][0]==0 and d[0x2117][0]==0x18
    if n_exp==0:
        assert len(d[0x420B])==1
    else:
        assert srcs[1]==0x8800 and lens[1]==n_exp*16 and len(d[0x420B])==2 and d[0x2116][1]==0 and d[0x2117][1]==0
    assert d[0x210E][:2]==[0xFF-8,3]
    run_irq(n)
def pad(l,h): cpu.regs_read[0x4218]=l; cpu.regs_read[0x4219]=h
def frame(r0=0):
    global LW
    run_irq(r0); LW=run_irq(r0); return LW
pad(0,0); frame()
assert cpu.wram[0x64]==8 and [v for a,v in LW if a==0x2026]==[0]
check(0,"default"); 
d=d_of(LW)
# L+Select no longer does anything special: game sees them, VOFF stays 8
pad(0x20,0x28); frame(); frame(); assert cpu.wram[0x64]==8 and [v for a,v in LW if a==0x2026][-1]==0
check(0,"VOFF stays 8 (8 black on top, 7 below)")
# D-pad without L: game gets it, VOFF untouched
pad(0,0x08); frame(); d=d_of(LW); print("up w/o L: SWCHA",hex(d[0x2020][-1]),"VOFF",cpu.wram[0x64]); assert cpu.wram[0x64]==8 and d[0x2020][-1]!=0xFF
# Select alone -> SWCHB bit1 low ; Start -> bit0 low ; B -> fire
pad(0,0x20); frame(); d=d_of(LW); assert d[0x2021][-1]==0xFD
pad(0,0x10); frame(); d=d_of(LW); assert d[0x2021][-1]==0xFE
pad(0x80,0); frame(); d=d_of(LW); assert d[0x2022][-1]==2
# pause
pad(0x10,0); frame(); pad(0,0); frame(); print("pause",cpu.wram[0x5A],"reg3",[hex(v) for a,v in LW if a==0x2023][-1]); assert cpu.wram[0x5A]==1
# reset combo: handler spins after writing $2A00 = $81
pad(0x70,0x20); run_irq(0)
cpu.regs_read[0x2020]=0; cpu.writes.clear()
ret=cpu.PC; cpu.E=0;cpu.M=1;cpu.XF=0
cpu.push(0);cpu.push(ret>>8);cpu.push(ret&255);cpu.push(cpu.P()); cpu.PC=sym['Nmi']
for _ in range(20000):
    cpu.step()
    if any(a==0x2A00 for a,v in cpu.writes): break
print("reset combo writes $2A00:",[hex(v) for a,v in cpu.writes if a==0x2A00]); assert [v for a,v in cpu.writes if a==0x2A00]==[0x81]
print("ALL OK")
