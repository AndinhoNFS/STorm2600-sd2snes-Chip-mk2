# STorm2600: Atari 2600 no SD2SNES (FPGA MK2)

Roda jogos de Atari 2600 no próprio Super Nintendo, usando o FPGA Spartan‑3 do
SD2SNES/FXPak (revisão MK2). O Atari é emulado em hardware dentro do FPGA do
cartão; o SNES só exibe a imagem e lê os controles.

Projetos de base:

- [ludufre/sd2snes](https://github.com/ludufre/sd2snes): firmware e base do FPGA do cartão.
- [MiSTer-devel/Atari2600_MiSTer](https://github.com/MiSTer-devel/Atari2600_MiSTer):
  referência de comportamento. O TIA usado aqui foi escrito do zero para caber no Spartan‑3.

## Estado

| Item | Versão |
|---|---|
| Player SNES | v7 (`atari_snes7.bin`) |
| Bitstream FPGA | Passo 24 (`fpga_atari.bit`), versão `$06` em `$2027` |
| Uso do FPGA | 5003/7168 LUTs, 2875/3584 slices, 16/16 BRAM, folga +0,024 ns |

Testado no console com o bitstream do Passo 23 (Release `v0.7-p23`): Pitfall,
River Raid, Pac‑Man, Enduro, Frostbite e Boxing corretos. O bitstream do
Passo 24 (Release `v0.7-p24`) corrige H.E.R.O. e Seaquest em simulação e ainda
não foi testado no console. Bugs conhecidos em
[docs/PENDENCIAS.md](docs/PENDENCIAS.md).

## Como funciona (resumo)

1. O core do Atari roda no FPGA e grava cada quadro na PSRAM do cartão em
   triplo buffer: mapa de tiles BG1, lista de tiles 2bpp, 4 canais de cor por
   linha e janela horizontal.
2. O player no SNES, no IRQ da linha 232, trava o buffer mais recente e copia
   mapa e tiles para a VRAM por DMA.
3. HDMA indireto troca a paleta e a janela linha a linha, reproduzindo as cores
   do Atari.
4. Imagem 1:1 (160 colunas), 224 linhas centradas em modo overscan 239.

Detalhes em [docs/DESIGN.md](docs/DESIGN.md).

## Controles

| SNES | Atari |
|---|---|
| D‑pad | Joystick |
| B / A | Fire |
| Start | RESET |
| Select | SELECT |
| R | Pausa |
| L+R+Select+X | Volta ao menu |

## Estrutura

```
fpga/    fontes do core (Verilog), testbenches e script que gera o projeto ISE
snes/    player SNES (65816); o fonte do v7 ainda não foi importado
tools/   scripts de comparação e medição contra o emulador (ALE)
firmware/ mudanças no firmware do sd2snes para o modo Atari (patch)
sdcard/  arquivos prontos para o cartão (bitstream, player e firmware)
docs/    design, layout do buffer, descrição do player, pendências e notas
```

Cada pasta tem um LEIAME próprio (`tools/README.txt` no caso das ferramentas).

## Origem do código

- Todo o Verilog em `fpga/` foi escrito do zero para este projeto
  (GPL-2.0-or-later). Nenhum arquivo do sd2snes ou do MiSTer é copiado aqui.
- O projeto ISE é gerado por `fpga/make_atari_shell.py` a partir de uma árvore
  intacta do [sd2snes](https://github.com/ludufre/sd2snes) (GPL-2.0): o `main.v`,
  o `.ucf` e o `.xise` gerados derivam dos originais e não são versionados.
- O [Atari2600_MiSTer](https://github.com/MiSTer-devel/Atari2600_MiSTer) é só
  referência de comportamento (por exemplo, a numeração dos mappers).
- As ferramentas em `tools/` usam o [ALE](https://github.com/Farama-Foundation/Arcade-Learning-Environment)
  (núcleo do Stella) como referência; ele é instalado à parte com `pip`.
- `fpga/tb_m6507_func.v` roda o teste funcional do 6502 de
  [Klaus Dormann](https://github.com/Klaus2m5/6502_65C02_functional_tests)
  (GPL-3.0), que não é distribuído aqui.
- O `sdcard/sd2snes/firmware.img` é o firmware do sd2snes (GPL versão 2) no
  commit `1b5d9d79`, compilado com as mudanças de [`firmware/`](firmware/): o
  patch e os quatro arquivos modificados, com os cabeçalhos originais.
- O `sdcard/sd2snes/fpga_atari.bit` contém, além do core deste repositório, o
  restante do FPGA do sd2snes (`verilog/sd2snes_base` do mesmo commit).
- O fonte do player (`sdcard/sd2snes/atari_snes.bin`) ainda não está aqui; ver
  `snes/LEIAME.md`.

## Instalação no cartão

Copie o conteúdo de [`sdcard/`](sdcard/) para a raiz do cartão, mesclando com a
pasta `/sd2snes/` que já existe. São três arquivos: `fpga_atari.bit`,
`atari_snes.bin` (o player v7) e `firmware.img`. O `firmware.img` substitui o
firmware do cartão: guarde uma cópia do atual antes. O passo a passo e os md5
estão em [`sdcard/LEIAME.md`](sdcard/LEIAME.md).

O bitstream e o player de cada versão também ficam na página de Releases (lá o
player se chama `atari_snes7.bin`; no cartão, `atari_snes.bin`). ROMs de Atari não são distribuídas com este projeto.

## Autoria

Copyright (C) 2026 AndinhoNFS.

O projeto foi concebido, dirigido e testado no console por AndinhoNFS. Grande
parte do código (o Verilog de `fpga/`, as ferramentas de `tools/` e as mudanças
de `firmware/`) foi escrita com assistência do Claude, da Anthropic, a partir
das especificações e dos resultados de teste dele; os commits feitos assim
levam a linha `Co-Authored-By: Claude`. As partes derivadas do sd2snes mantêm
os autores e a licença originais.

## Licença

GPL-2.0, a mesma do sd2snes. Veja [LICENSE](LICENSE).
