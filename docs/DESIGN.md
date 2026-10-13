# Design: player SNES v7 + bitstream Passo 23

## Quadro na PSRAM

Três buffers em `$70/$71/$72:8000`. Layout de cada buffer:

| Offset | Conteúdo |
|---|---|
| `+$0000` | Cabeçalho; palavra 0 = N tiles distintos (N ≤ 512) |
| `+$0010` | Mapa BG1, 28×32 entradas |
| `+$0800` | Lista de tiles 2bpp, 16 B cada |
| `+$4000 + k*$400` | Canal de cor k=0..3: 225 × `[k, k, BGR lo, BGR hi]` |
| `+$5000` | Janela: 225 × `[esq, dir]` |

A entrada 224 é preta.

## Imagem

- 1:1: pixels do Atari nas colunas 48..207 (tiles 6..25 do mapa). Janela
  esq=48 (56 com barra HMOVE), dir=207; o resto usa o tile 0.
- SNES em overscan 239 (`$2133=$04`): 224 linhas de jogo, 8 pretas em cima e 7
  embaixo (vindas do HDMA, entrada 224). `VOFF0=8`.

## Cores

O core lê as 4 cores (COLUBK/PF/P0/P1) uma vez por linha, no pixel 16.
Passo 23: se a cor final de um pixel difere da cor guardada do seu índice mas
coincide com outra das 4 guardadas, usa o índice dessa. Só acerta com até 4
cores finais por linha (medido nos 6 jogos de teste).

## Player SNES

- IRQ V=232 (fase 0): force blank; trava o buffer N mais recente
  (reg 7 = `$80|N`); DMA do mapa (1792 B de `$8010` → VRAM `$1800`) e dos N
  tiles (N×16 B de `$8800` → VRAM `$0000`); scroll = −(VOFF+1).
- IRQ V=0 (fase 1): display on, joypad, registradores.
- HDMA indireto (banco `$70+N`): canais 1–4 modo 3 (`$2121/$2122`), canal 5
  modo 1 (`$2126/$2127`). Tabelas de ponteiros em WRAM `$7E:2000 + canal*$20`,
  dois segmentos de 112 linhas.

## Registradores do core

| Escrita | Função |
|---|---|
| 0 | SWCHA |
| 1 | SWCHB |
| 2 | fire |
| 3 | {run, mapper 3:1, pause 4} |
| 6 | deslocamento da 1ª linha capturada (o player escreve 0) |
| 7 | trava |

| Leitura | Função |
|---|---|
| `$2027` | versão |
| `$202D` | descartes |
| `$202E/F` | N do último quadro |

## Temporização

Core: 262 linhas/quadro (59,92 Hz) contra 60,10 Hz do SNES: um quadro repetido
a cada ~5,5 s. Genlock é opção futura.

## Decisões

- Vertical: 224 linhas centradas em 239; o OSSC corta o preto.
- Horizontal: hi‑res 512 (3×) medido e descartado. O Enduro estoura 30 linhas
  de DMA, e o dicionário de 32 B pediria 20 BRAM (o Spartan‑3 tem 16).
  Escolhido 1:1 (160 colunas, imagem mais estreita). Se a proporção incomodar,
  a alternativa é o bitstream 21b.
- Arco‑íris à esquerda das faixas Activision começa na coluna 20 no core, no
  buffer e no ALE: não é bug.
- O TIA é próprio (escrito do zero), não o do MiSTer. O Atari2600_MiSTer serve
  de referência de comportamento.
