# fpga/: core do Atari 2600

Verilog escrito para este projeto (GPL-2.0-or-later, ver o cabeçalho SPDX de
cada arquivo). Exceção: o `a26_i2s.v` tem cerca de 15 linhas (o clocking do DAC)
copiadas do `verilog/sd2snes_base/dac.v` do sd2snes (Maximilian Rehkopf e
colaboradores, GPL-2.0), creditadas no cabeçalho, e por isso é GPL-2.0-only.
Nada do MiSTer é copiado.

| Arquivo | Conteúdo |
|---|---|
| `m6507.v`, `riot6532.v`, `tia.v`, `tia_audio.v` | CPU, RIOT e TIA (vídeo e áudio) |
| `a26_core.v` | os quatro acima mais os mappers |
| `a26_vidwr.v`, `a26_tdict.v` | gravador do quadro e dicionário de tiles |
| `a26_mem.v`, `a26_regs.v`, `a26_i2s.v`, `a26_top.v` | ligação com o shell do sd2snes |
| `tb_*.v`, `slot_model.v`, `a26_bgr555.hex` | testbenches (iverilog) |
| `make_atari_shell.py` | gera o projeto ISE (ver abaixo) |
| `ports.txt` | portas dos módulos do sd2snes que viram stub |
| `scripts/sweep_sementes.sh` | varredura de sementes de placement usada na síntese |
| `experimental/p26B/` | alocação das 4 cores por linha: funciona em simulação, não fecha o timing, **fora do bitstream** |

## Projeto ISE

Não há `.ucf`, `.xise` nem `.prj` nesta pasta: eles são **gerados** a partir de
uma árvore intacta do [sd2snes](https://github.com/ludufre/sd2snes) (os
bitstreams distribuídos usam o commit `1b5d9d79`).
`make_atari_shell.py REPO_ROOT --src fpga/` cria `verilog/sd2snes_atari/` ao
lado de `verilog/sd2snes_base/`, com uma cópia de `main.v` em que duas
instâncias são trocadas, stubs dos módulos não usados, o `Makefile`, o
`ucf.extra` e o `.xise`. Os arquivos gerados contêm código do sd2snes (GPL-2.0)
e por isso não são versionados aqui. A semente de placement fica em
`PLACER_SEED` no script.

Síntese: ISE 14.7, XC3S400, clock de 96 MHz. `scripts/sweep_sementes.sh` roda
dentro de `verilog/sd2snes_atari/` e para na primeira semente que fecha com
folga de pelo menos 0,010 ns.

## Testbenches

```
iverilog -g2005 -Wall -o tb_tia tb_tia.v tia.v && vvp tb_tia
```

O comando de cada um está no cabeçalho do arquivo. `tb_m6507_func.v` precisa de
`func_test.hex`, gerado a partir do `6502_functional_test.bin` de Klaus Dormann
(<https://github.com/Klaus2m5/6502_65C02_functional_tests>, GPL-3.0), que não é
distribuído neste repositório.
