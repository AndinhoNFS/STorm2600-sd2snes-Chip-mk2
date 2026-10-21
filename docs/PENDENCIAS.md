# Pendências

## Bugs abertos

- **Linhas com mais de 4 cores**: o SNES recebe 4 cores por linha. Na
  coleção, 7.142 das 1.429.995 linhas medidas (119 ROMs, quase todas demos de
  cor) têm mais de 4. Opções estudadas (8 paletas por tile com HDMA, 16 cores
  por linha): ganhariam de 25 a 41 ROMs, com player, gravador e orçamento de
  DMA novos; não feitas.
- **Superchip** (RAM de 128 bytes no cartucho): 114 arquivos da coleção. Os 16
  BRAMs estão em uso; em LUT-RAM caberia, mas os slices estão em 88%.
- **Mappers não suportados**: E0, E7, FA/12K, 64K, CV, UA, Supercharger.
- **Imagem PAL**: passa das 224 linhas que o SNES mostra (115 ROMs da
  coleção). O registrador de deslocamento (`$2026`) existe; falta o player
  escolher o deslocamento por jogo.
- **Diferença que cresce com o tempo** (~139 ROMs da coleção, ex.: Enduro,
  Pitfall): parte é o estado da RAM ao ligar (aleatório no console); o resto
  sem causa medida.
- **TIA**: diferenças fixas em algumas linhas (barra do HMOVE, borda de sprite;
  Robot Tank nas linhas 175-182), a estudar jogo a jogo.
- **Timer do RIOT**: lê um a mais que o emulador logo depois da escrita. Um
  protótipo um ciclo antes não mudou nenhum jogo; não aplicado.
- **Rally X (2004, WIP)**: continua com tela preta; causa não medida.

## Aprovado no console (Passo 33 + player v14, 21/10/2026)

Bit `fpga_atari.bit` md5 `87887c111a788c51805a644313b16808` (versão `$0C`) e
`atari_snes.bin` (player v14) md5 `9cbeeda15bec0d7cacd8fea0c9e4b48c`, aprovados
pelo autor no console. Feito a partir da lógica do chip original (notas do
Towers, esquemáticos e *Stella Programmer's Guide*), não medido num Atari.
As ROMs de `tools/tia_tests/` ainda não foram rodadas num Atari 2600 real.

Diferenças conhecidas do Passo 33 ainda em aberto:

- **Ghoul**: 1 pixel a mais no caso `hm_stuck` (HMOVE com o contador de
  movimento preso).
- **Chess**: janela de START do míssil logo depois de RESMx.
- **Bobby Is Going Home**: defeito no console; as simulações sem tecla não
  mostram diferença entre o P31 e o P33.
- **Crackpots**: estalos no áudio.
- **Meta de folga**: +0,045 ns, abaixo da meta de +0,2 ns; os caminhos mais
  apertados são do sd2snes base, não do core.

## A confirmar no console (Passo 24/25)

Corrigidos em simulação contra o emulador. Em 2026-10-14 o bitstream do Passo 24
foi usado no console: o Decathlon original abre com o firmware do Passo 25.

- **H.E.R.O.**: dois pixels perdidos apareciam em outro ponto da mesma tela, em
  várias telas, e tocar neles matava o herói. Em simulação os pixels somem
  (340 → 0 em 85 quadros). A morte do herói não foi reproduzida em simulação,
  então só o teste no console confirma essa parte.
- **Seaquest**: lacuna de pixels na barra de oxigênio (20 → 0).
- **Robot Tank e Thwocker**: passam a mapper FE com o firmware do Passo 25;
  rodam em simulação, mas não foram testados no console. Em simulação, o Robot
  Tank ainda difere do emulador em ~266 pixels por quadro, por causa do TIA e
  não do mapper.

## Melhorias possíveis

- Genlock (elimina o quadro repetido a cada ~5,5 s).
- Paleta PAL e autodetecção NTSC/PAL.
- Deslocamento salvo por ROM.
- Folga de timing: +0,013 ns no Passo 31 (semente 13). Qualquer mudança no
  core pede uma nova varredura de sementes.

## Corrigidos no Passo 31

- **Cor trocada no meio da linha** (Checkers, barras POWER do H.E.R.O. e
  OXYGEN do Seaquest): os 4 índices de cor de cada linha passam a ser
  alocados conforme as cores aparecem, num strobe atrasado de 13 clocks (a
  alocação do item B do Passo 26, que não fechava o timing, agora fecha:
  +0,013 ns, semente 13). Em simulação: Checkers e H.E.R.O. iguais ao
  emulador; no Seaquest o erro do gravador some (sobra uma diferença do TIA).
  Na coleção: 349 ROMs a mais iguais ao emulador, nenhuma das 500 da amostra
  que já davam iguais mudou. Versão `$0B`.
- Player v13: X troca a paleta, Y o nível (Easy/Normal/Hard), aviso verde na
  tela.

## Corrigidos no Passo 29

- **Opcodes não documentados do 6502** (antes NOP de 1 byte): validados com
  ROMs de teste contra o emulador. Na coleção: 217 ROMs passaram a iguais, 427
  melhoraram.
- **Leitura do TIA**: os bits 5..0 são o último valor do barramento (antes 0).
- Versão `$0A`.

## Passos 27 e 28: paletas

- Passo 27: paleta nova (a anterior desbotava os tons claros). Versão `$08`.
- Passo 28: 4 paletas no registrador `$2028` (Color-1, Color-2, Color-3,
  Black/White). Passo 28b: o `$00` da Color-2 virou preto puro. Versão `$09`.

## Corrigidos no Passo 26

- **Bola (Crackpots, Decathlon)**: RESBL logo depois de HMOVE, ainda no
  apagamento, punha a bola 1 pixel à esquerda e, no HMOVE seguinte, na última
  coluna da direita. Agora vai para a posição 3, como no emulador. Confirmado no
  console com o bitstream `7d19e73ad27b7a03e51e2fe0947b663a` (versão `$07`):
  Crackpots e Decathlon OK (os 2-3 pixels da bola do Decathlon sumiram). Em
  simulação: 0 pixels diferentes do emulador na bola, outros 9 jogos sem
  mudança. Release `v0.7-p26`.

## Corrigidos no Passo 25

- Firmware detecta o mapper FE (critério do Stella) e passa 5 ao player: o
  Decathlon original abre no console.

## Corrigidos no Passo 24

- Escritas em PF0/PF1/PF2 só valem na próxima célula de 4 pixels (causa do
  H.E.R.O. e do Seaquest acima).
- GRP0/GRP1 valem 1 pixel depois (1 pixel de cor no H.E.R.O.).
- Mapper FE no core (valor 5).

## Corrigidos no Passo 23

- Bloco extra no arco‑íris da Activision (Enduro, Frostbite etc.).
- Placar do jogador 2 do Boxing.
