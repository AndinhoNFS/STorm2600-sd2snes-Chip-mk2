# Design: player SNES v17 + bitstream Passo 34

## Quadro na PSRAM

Três buffers em `$70/$71/$72:8000`. Layout de cada buffer:

| Offset | Conteúdo |
|---|---|
| `+$0000` | Cabeçalho; palavra 0 = N tiles distintos (N ≤ 512) |
| `+$0010` | Mapa BG1, 29×32 entradas (1.856 B, até `+$074F`) |
| `+$0800` | Lista de tiles 2bpp, 16 B cada |
| `+$4000 + k*$400` | Canal de cor k=0..3: 233 × `[k, k, BGR lo, BGR hi]` (932 B) |
| `+$5000` | Janela: 233 × `[esq, dir]` (466 B) |

A entrada 232 de cada tabela é preta (regravada a cada quadro).

## Imagem

- 1:1: pixels do Atari nas colunas 48..207 (tiles 6..25 do mapa). Janela
  esq=48 (56 com barra HMOVE), dir=207; o resto usa o tile 0.
- Captura de 232 linhas (TIA 27..258; `YS0=27` no gravador, mais o deslocamento
  do registrador 6). Cada linha do TIA fica na mesma linha da TV de antes: o TIA 34
  continua na linha V=9.
- SNES em overscan 239 (`$2133=$04`): `VOFF0=1` (uma linha preta em cima); a
  imagem ocupa V=2..233 e o force blank em V=233 corta a última linha (TIA 258),
  como o v14 cortava a última em V=232. Uma linha preta embaixo vem do HDMA
  (entrada 232).

## Cores

Cada linha tem 4 índices de cor (os canais 0..3 do HDMA).

- Até o Passo 29 o core lia as 4 cores (COLUBK/PF/P0/P1) uma vez por linha, no
  pixel 16; uma cor trocada depois disso se perdia (Checkers, barras do H.E.R.O.
  e do Seaquest).
- Passo 31: os índices são **alocados** conforme os pixels chegam. Cada pixel
  pega o índice que já tem a sua cor final (a do registrador quando o TIA
  desenhou o pixel); senão, um índice livre, que passa a ter essa cor no resto
  da linha. As cores de uma linha vão para a tabela durante a linha seguinte.
  O gravador roda 13 clocks depois do pixel, sobre cópias registradas das
  saídas do TIA, para que essa lógica não fique num caminho de 1 clock.
  Limite: uma linha com mais de 4 cores fica com as 4 primeiras.

Paletas (Passo 28, registrador de escrita 8 = `$2028`, bits 1:0; vale a partir
do quadro seguinte): 0 = Color-1 (padrão), 1 = Color-2, 2 = Color-3,
3 = Black/White (os 8 cinzas de Color-1, pela luminância do Atari). A cor
BGR555 de cada índice sai de `pal_bgr()` em `fpga/a26_vidwr.v` (cópia das
tabelas em `fpga/a26_pal4.hex`).

## TIA: atraso das escritas (Passo 24)

- PF0/PF1/PF2: uma escrita só vale no início da próxima célula de 4 pixels
  (primeiro clock de cor múltiplo de 4 que é ≥ h+3, sendo h o clock em que a
  escrita chega). Há um pendente por registrador.
- GRP0/GRP1: valem 1 pixel depois.
- As demais escritas continuam valendo no clock de cor seguinte.
- RESBL (Passo 26): dado no apagamento horizontal, põe a bola na posição 2, ou
  na 3 se já houve HMOVE nesse mesmo apagamento (como no Stella/ALE).

## Mappers

Valor em `$2023` bits 3:1, com a numeração do MiSTer; ver o cabeçalho de
`fpga/a26_core.v`. Passo 24: 5 = FE (Activision 8 KB, Decathlon). No ciclo
seguinte a um acesso a `$01FE`, o bit 5 do barramento de dados escolhe o
banco (1 = primeiros 4 KB, 0 = segundos). Desde o Passo 25 o firmware passa 5
para os `.a26` de 8 KB que o critério do Stella reconhece como FE (ver
`firmware/LEIAME.md`).

Superchip (Passo 36, versão `$0E`): bit 5 do `$2023`. Com ele ligado, em F8 e F6
os 128 bytes de RAM ocupam o começo de cada banco de 4 KB: escrita em
`$1000-$107F`, leitura em `$1080-$10FF`, a ROM dessa faixa nunca é vista. A RAM
é distribuída (LUTs), dentro do grupo lento de 125 ns (`ucf.extra`), porque as
16 BRAMs estão todas em uso. Uma leitura da porta de escrita devolve o byte da
ROM e não grava. O firmware passa o bit no byte do mapper (`$7FF0`, bit 4); o
player v17 o desloca para o bit 5 do `$2023` e o preserva na pausa. F4SC não
é atendido: a ROM do core tem 16 KB, então esses `.a26` seguem como F4.

## Player SNES

- IRQ V=233 (fase 0): force blank; trava o buffer N mais recente
  (reg 7 = `$80|N`); DMA do mapa (1856 B de `$8010` → VRAM `$1800`) e dos N
  tiles (N×16 B de `$8800` → VRAM `$0000`); scroll = −(VOFF+1). A janela de
  cópia continua de 30 linhas.
- IRQ V=1 (fase 1): display on, joypad, registradores.
- HDMA indireto (banco `$70+N`): canais 1–4 modo 3 (`$2121/$2122`), canal 5
  modo 1 (`$2126/$2127`). Tabelas de ponteiros em WRAM `$7E:2000 + canal*$20`:
  1 linha preta, 232 linhas de imagem (dois segmentos de 116 por canal), 1 linha
  preta e fim (o HDMA para em V=233).

## Registradores do core

| Escrita | Função |
|---|---|
| 0 | SWCHA |
| 1 | SWCHB |
| 2 | fire |
| 3 | {run, mapper 3:1, pause 4, Superchip 5} |
| 6 | deslocamento da 1ª linha capturada (o player escreve 0) |
| 7 | trava |
| 8 | paleta, bits 1:0 (Passo 28) |

| Leitura | Função |
|---|---|
| `$2027` | versão (`$0D` no Passo 34, `$0E` no Passo 36) |
| `$202D` | descartes |
| `$202E/F` | N do último quadro |

## Síntese

ISE 14.7, XC3S400, clock de 96 MHz. A semente de placement é escolhida por
varredura (`fpga/scripts/sweep_sementes.sh`), exigindo folga ≥ 0 ns a 96 MHz (nos passos até o 31, ≥ 0,010 ns; o Passo 34 fechou com +0,003 ns).

| | Passo 23 | Passo 24 | Passo 26 | Passo 27 | Passo 28b | Passo 29 | Passo 31 | Passo 33 | Passo 34 |
|---|---|---|---|---|---|---|---|---|---|
| Versão em `$2027` | `$05` | `$06` | `$07` | `$08` | `$09` | `$0A` | `$0B` | `$0C` | `$0D` |
| Semente | 10 | 17 | 7 | 13 | 9 | 11 | 13 | 17 | 17 |
| Folga a 96 MHz | +0,034 ns | +0,024 ns | +0,065 ns | +0,012 ns | +0,114 ns | +0,021 ns | +0,013 ns | +0,045 ns | +0,003 ns |
| LUTs | 4982 | 5003 | 4965 | 4996 | 5232 | 5519 | 5587 (77%) | 5487 | 5489 |
| Slices | 2889 | 2875 | 2897 | 2931 | 3005 | 3136 | 3155 (88%) | 3110 (86%) | 3096 (86%) |
| FFs | 2205 | 2260 | 2235 | 2254 | 2258 | 2253 | 2337 | 2677 | 2695 |
| BRAM | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 |

O caminho crítico continua sendo o que vai das saídas do TIA ao gravador de
vídeo. A alocação das cores por linha do Passo 26 (item B) punha 9 níveis de
lógica nesse caminho e não fechava (-1,5 a -2,6 ns; guardada em
[`fpga/experimental/p26B/`](../fpga/experimental/p26B/)); no Passo 31 ela roda
num strobe atrasado de 13 clocks (registradores `dsh`/`vsh`, no grupo
`a26_fast` do `ucf.extra`) e fecha. Como gerar o bitstream:
[`fpga/LEIAME.md`](../fpga/LEIAME.md).

## Binários

Os três arquivos que vão para o cartão ficam versionados em `sdcard/`, na
mesma estrutura do cartão, e o bitstream e o player também nas Releases.
Sempre que um deles mudar, `sdcard/` é atualizado no mesmo commit que muda os
fontes.

## Temporização

Core: 262 linhas/quadro (59,92 Hz) contra 60,10 Hz do SNES: um quadro repetido
a cada ~5,5 s. Genlock é opção futura.

## Decisões

- Vertical: 232 linhas em modo 239 (Passo 34); o OSSC corta o preto.
- Horizontal: hi‑res 512 (3×) medido e descartado. O Enduro estoura 30 linhas
  de DMA, e o dicionário de 32 B pediria 20 BRAM (o Spartan‑3 tem 16).
  Escolhido 1:1 (160 colunas, imagem mais estreita). Se a proporção incomodar,
  a alternativa é o bitstream 21b.
- Arco‑íris à esquerda das faixas Activision começa na coluna 20 no core, no
  buffer e no ALE: não é bug.
- O TIA é próprio (escrito do zero), não o do MiSTer. O Atari2600_MiSTer serve
  de referência de comportamento.
