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
| Bitstream FPGA | Passo 23 (`fpga_atari.bit`), versão `$05` em `$2027` |
| Uso do FPGA | 4982/7168 LUTs, 2889/3584 slices, 16/16 BRAM, folga +0,034 ns |

Testado no console: Pitfall, River Raid, Pac‑Man, Enduro, Frostbite e Boxing
corretos. Bugs conhecidos em [docs/PENDENCIAS.md](docs/PENDENCIAS.md).

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
fpga/    fontes do core (Verilog/VHDL) e projeto ISE
snes/    player SNES (65816)
tools/   scripts de comparação e medição
docs/    design, layout do buffer e pendências
```

## Instalação no cartão

Baixe `fpga_atari.bit` e `atari_snes7.bin` da página de Releases e copie para
o cartão. ROMs de Atari não são distribuídas com este projeto.

## Licença

GPL-2.0, a mesma do sd2snes. Veja [LICENSE](LICENSE).
