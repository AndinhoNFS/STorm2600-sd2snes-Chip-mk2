# fpga/: core do Atari 2600

Verilog escrito para este projeto (GPL-2.0-or-later, ver o cabeçalho SPDX de
cada arquivo). Exceção: o `a26_i2s.v` tem cerca de 15 linhas (o clocking do DAC)
copiadas do `verilog/sd2snes_base/dac.v` do sd2snes (Maximilian Rehkopf e
colaboradores, GPL-2.0), creditadas no cabeçalho, e por isso é GPL-2.0-only.
Nada do MiSTer é copiado.

| Arquivo | Conteúdo |
|---|---|
| `m6507.v`, `riot6532.v`, `tia.v`, `tia_audio.v` | CPU, RIOT e TIA (vídeo e áudio) |
| `tia_hc.v`, `tia_obj.v`, `PROVENIENCIA_TIA.md` | Passo 33: contador horizontal e objetos (P0, P1, M0, M1, bola) com os contadores polinomiais do chip original; `tia.v` os usa, e `` `define TIA_P31 `` volta aos objetos do Passo 31. Origem de cada regra em `../docs/tia_spec.md` e `PROVENIENCIA_TIA.md` |
| `a26_core.v` | os quatro acima mais os mappers |
| `a26_vidwr.v`, `a26_tdict.v` | gravador do quadro e dicionário de tiles |
| `a26_mem.v`, `a26_regs.v`, `a26_i2s.v`, `a26_top.v` | ligação com o shell do sd2snes |
| `a26_pal4.hex` | as 4 paletas (Color-1, Color-2, Color-3, Black/White; paleta p em 128·p + c), cópia das tabelas de `a26_vidwr.v` |
| `tb_*.v`, `slot_model.v`, `a26_bgr555.hex` | testbenches (iverilog); `a26_bgr555.hex` = Color-1 |
| `tb_a26_i2s_eq.v`, `experimental/a26_i2s_p31_old.v` | Passo 33: prova de que o `a26_i2s.v` reescrito dirige os mesmos pinos que o do Passo 31 (`iverilog -g2005 -o t tb_a26_i2s_eq.v a26_i2s.v experimental/a26_i2s_p31_old.v && vvp t`) |
| `make_atari_shell.py` | gera o projeto ISE (ver abaixo) |
| `ports.txt` | portas dos módulos do sd2snes que viram stub |
| `scripts/sweep_sementes.sh` | varredura de sementes de placement usada na síntese |
| `experimental/p26B/` | primeira versão da alocação das 4 cores por linha (Passo 26), que não fechava o timing; substituída pela do Passo 31 em `a26_vidwr.v` |

## Projeto ISE

Não há `.ucf`, `.xise` nem `.prj` nesta pasta: eles são **gerados** a partir de
uma árvore intacta do [sd2snes](https://github.com/ludufre/sd2snes) (os
bitstreams distribuídos usam o commit `1b5d9d79`).
`make_atari_shell.py REPO_ROOT --src fpga/` cria `verilog/sd2snes_atari/` ao
lado de `verilog/sd2snes_base/`, com uma cópia de `main.v` em que duas
instâncias são trocadas, stubs dos módulos não usados, o `Makefile`, o
`ucf.extra` e o `.xise`. Os arquivos gerados contêm código do sd2snes (GPL-2.0)
e por isso não são versionados aqui. O script nunca escreve em
`sd2snes_base` e não sobrescreve um `sd2snes_atari` que já exista.

## Gerar o bitstream

Precisa do Xilinx ISE 14.7 (Linux) e de Python 3 (só para o passo 2).

1. Clone o sd2snes e fixe o commit usado:
   `git clone https://github.com/ludufre/sd2snes && git -C sd2snes checkout 1b5d9d79`
2. Gere o projeto: `python3 fpga/make_atari_shell.py sd2snes --src fpga/`
   (cria `sd2snes/verilog/sd2snes_atari/`; a semente de placement já vem no
   `.xise`: `PLACER_SEED = 7` no script, a do bitstream publicado, Passo 36,
   usado também na release do Passo 37).
3. Compile o `utils/rle` do sd2snes (`make -C sd2snes/utils rle`); ele comprime o `main.bit`
   no formato que o firmware lê.
4. Sintetize, dentro de `sd2snes/verilog/sd2snes_atari/`:
   ```
   source <pasta do ISE>/14.7/ISE_DS/settings64.sh
   make main.bit
   ../../utils/rle main.bit fpga_atari.bit
   ```
   O `make` para se o timing não fechar (`IGNORE_TIMING=1` ignora). Confira em
   `main.par`: "All constraints were met" e a folga de
   `TS_snes_a26_clkin1` (96 MHz) positiva. No Passo 36 (semente 7): +0,001 ns.
5. Copie `fpga_atari.bit` para `/sd2snes/fpga_atari.bit` no cartão.

**A semente.** A folga a 96 MHz é pequena e depende do placement. A semente
("Starting Placer Cost Table" de map e par) é escolhida por varredura:
`scripts/sweep_sementes.sh` roda dentro de `verilog/sd2snes_atari/`, testa as
sementes de `SEEDS` (lista padrão começando pela 13) e para na primeira que
fecha com folga de pelo menos `MINSLACK` (padrão 0,010 ns). O bitstream
publicado (Passo 36) fechou só na semente 7, com +0,001 ns (as sementes 17, 13,
11 e 9 não fecharam); para refazê-lo, use
`SEEDS=7 MINSLACK=0 ../../fpga/scripts/sweep_sementes.sh` (o `MINSLACK=0` é
necessário: o padrão de 0,010 ns recusaria +0,001 ns). Se mudar qualquer fonte,
a semente 7 pode deixar de fechar: rode a varredura de novo.

**Reprodutibilidade.** Refeito em 2026-11-18 a partir destes fontes, do commit
`1b5d9d79` do sd2snes e da semente 7, o bitstream saiu com o mesmo tamanho
(129.888 bytes), os mesmos números (5.455 LUTs, 3.141 slices, 16/16 BRAM,
+0,001 ns, "All constraints were met") e o mesmo conteúdo do distribuído; só a
data e a hora da síntese, no cabeçalho de texto do `.bit`, mudam, então o md5
do arquivo inteiro muda a cada build (o distribuído,
`d33d69b587c485e9435126053061b8a9`, tem a data de 2026-10-23). Para comparar,
tire o md5 a partir da palavra de sincronismo `AA 99 55 66` (offset 103 no
arquivo distribuído): deve dar `606d9ff61050865b6de12031c0cbc3ee`.

```
python3 -c "import sys,hashlib; b=open(sys.argv[1],'rb').read(); i=b.find(bytes.fromhex('AA995566')); print(i, hashlib.md5(b[i:]).hexdigest())" fpga_atari.bit
```

## Testbenches

```
iverilog -g2005 -Wall -o tb_tia tb_tia.v tia.v tia_hc.v tia_obj.v && vvp tb_tia
```

O comando de cada um está no cabeçalho do arquivo. `tb_m6507_func.v` precisa de
`func_test.hex`, gerado a partir do `6502_functional_test.bin` de Klaus Dormann
(<https://github.com/Klaus2m5/6502_65C02_functional_tests>, GPL-3.0), que não é
distribuído neste repositório.
