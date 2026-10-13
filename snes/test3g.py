import sys,re,random
sys.path.insert(0,'.')
from emu65816 import CPU
rom=open('atari_snes3g.bin','rb').read()
sym={}
for l in open('atari_snes3.lst'):
    m=re.match(r'([0-9A-F]{6})r 1\s+(\w+):\s*$',l)
    if m: sym[m.group(2)]=0x8000+int(m.group(1),16)
vals=[int(x.replace('$',''),16) for x in re.findall(r'\$[0-9A-Fa-f]+',open('palette_ntsc.inc').read())]
class C2(CPU):
    def __init__(s,*a):
        super().__init__(*a)
        s.state='ready'; s.p_in=[0xAA,0xBB,0,0]; s.p_out=[0,0,0,0]; s.mem={}; s.exec=None; s.expect=0; s.addr=0
    def rd(s,a):
        if 0x2140<=a<=0x2143 and (a>>16)==0: return s.p_in[a-0x2140]
        return super().rd(a)
    def wr(s,a,v):
        if 0x2140<=(a&0xFFFF)<=0x2143 and (a>>16)==0:
            i=(a&0xFFFF)-0x2140; s.p_out[i]=v&0xFF
            if i==0:
                v&=0xFF
                if s.state=='ready' and v==0xCC:
                    s.addr=s.p_out[2]|s.p_out[3]<<8; s.state='xfer'; s.expect=0; s.p_in[0]=0xCC
                elif s.state=='xfer':
                    if v==s.expect:
                        s.mem[s.addr+s.expect]=s.p_out[1]; s.p_in[0]=v; s.expect=(s.expect+1)&0xFF
                    elif s.p_out[1]==0: s.exec=s.p_out[2]|s.p_out[3]<<8; s.state='run'
                    else: s.state='ready?'
            return
        super().wr(a,v)
cpu=C2(rom); cpu.PC=sym['Reset']
n=0
while not any(a==0x4200 and v==0x81 for a,v in cpu.writes):
    cpu.step(); n+=1
    assert n<3000000
print("reset ok, state",cpu.state,"exec",hex(cpu.exec or 0),"prog",[hex(cpu.mem[k]) for k in sorted(cpu.mem)])
assert [cpu.mem[k] for k in sorted(cpu.mem)]==[0x8F,0x6C,0xF2,0x8F,0x20,0xF3,0x2F,0xFE] and cpu.exec==0x200
# timeout path: SPC never answers
cpu2=CPU(rom); cpu2.PC=sym['Reset']; n=0
while not any(a==0x4200 and v==0x81 for a,v in cpu2.writes):
    cpu2.step(); n+=1
    assert n<8000000,"no timeout"
print("no-IPL case: reset still completes after",n,"steps")
# convert with CROP
for _ in range(20): cpu.step()
acc=[0]
random.seed(7)
pal=[[random.randrange(1,128) for _ in range(4)] for _ in range(224)]
for l in range(224):
    for j in range(4): cpu.fb[0x2300+4*l+j]=pal[l][j]
cpu.regs_read[0x2020]=0; cpu.regs_read[0x4210]=0x80
ret=cpu.PC; cpu.E=0;cpu.M=1;cpu.XF=0
cpu.push(0);cpu.push(ret>>8);cpu.push(ret&255);cpu.push(cpu.P()); sp=cpu.S+4
cpu.PC=sym['Nmi']
while not(cpu.PC==ret and cpu.S==sp): cpu.step()
while cpu.wram[0x4D]: cpu.step()
OTHER=cpu.wram[0x16]|cpu.wram[0x17]<<8
bad=0
for x in range(224):
    ln=x-11
    exp_black = x<11 or ln>=216
    off=3+4*x+(1 if x>=127 else 0)
    for k in range(4):
        o=OTHER+k*0x400+off; got=cpu.wram[o]|cpu.wram[o+1]<<8
        exp=0 if exp_black else vals[pal[ln][k]]
        if got!=exp: bad+=1
print("convert mismatches with CROP:",bad)
w=[(a,v) for a,v in cpu.writes if a==0x210E][:2]
print("VOFS1 writes",[hex(v) for a,v in w])

dm=[(a,v) for a,v in cpu.writes if a in (0x4302,0x4303,0x4305,0x4306)]
print("DMA regs",[(hex(a),hex(v)) for a,v in dm])
tm=open('tilemap.bin','rb').read()
import struct
ent=lambda r,c: struct.unpack('<H',tm[(r*32+c)*2:(r*32+c)*2+2])[0]
print("map r0c6",ent(0,6),"r25c25",ent(25,25),"r26c6",ent(26,6),"r0c5",ent(0,5))
