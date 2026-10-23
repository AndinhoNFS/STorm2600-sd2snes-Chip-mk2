# Pendências

## Bugs abertos

- **Linhas com mais de 4 cores**: o SNES recebe 4 cores por linha. Na
  coleção, 7.142 das 1.429.995 linhas medidas (119 ROMs, quase todas demos de
  cor) têm mais de 4. Opções estudadas (8 paletas por tile com HDMA, 16 cores
  por linha): ganhariam de 25 a 41 ROMs, com player, gravador e orçamento de
  DMA novos; não feitas.
- **F4SC e jogos de 32 KB**: a ROM do core é de 16 KB de BRAM e o F4 aliasa os
  bancos 4 a 7 nos 0 a 3. Frente futura: avaliar servir a ROM pela PSRAM em
  vez de BRAM (a porta `rom_rd`/`rom_ack` já existe; o risco é a latência: a
  resposta tem de chegar em cerca de 3 clocks de cor). Libera o F4SC (26 ROMs
  distintas, ex. Fatal Run) e os demais de 32 KB.
- **Superchip F8SC e F6SC, 54 de 88 ROMs ainda não OK contra o Stella** (Passo
  36; ver abaixo): 6 com 1 pixel de diferença no TIA, 25 com 18 a 94 pixels
  (detalhe do TIA), 1 limite de captura, 8 com um bloco fixo de linhas
  diferente (hipótese: o Stella enche a RAM do cartucho com valores aleatórios,
  o core parte de zero), 14 cuja diferença varia com o tempo (podem ser o
  estado inicial da RAM ou erro do Superchip; a verificar com o Stella com a
  RAM zerada). Uma leitura da porta de escrita ($1000-$107F) devolve o byte da
  ROM e não grava; o console grava o valor do barramento.
- **Mappers não suportados**: E0, E7, FA/12K, 64K, CV, UA, Supercharger.
- **Imagem PAL**: passa das 232 linhas que o SNES mostra (115 ROMs da
  coleção, medido com 224). O registrador de deslocamento (`$2026`) existe; falta o player
  escolher o deslocamento por jogo.
- **Diferença que cresce com o tempo** (~139 ROMs da coleção, ex.: Enduro,
  Pitfall): parte é o estado da RAM ao ligar (aleatório no console); o resto
  sem causa medida.
- **TIA**: diferenças fixas em algumas linhas (barra do HMOVE, borda de sprite;
  Robot Tank nas linhas 175-182), a estudar jogo a jogo.
- **Timer do RIOT**: lê um a mais que o emulador logo depois da escrita. Um
  protótipo um ciclo antes não mudou nenhum jogo; não aplicado.
- **Rally X (2004, WIP)**: continua com tela preta; causa não medida.

## Em observação: troca de quadro (Passos 34 e 35)

Estudo em simulação (sistema completo, com um modelo do player que lê o buffer
mais novo e grava a trava) da trava dos 3 buffers com a captura de 232 linhas:

- A trava só falha se o SNES demorar, entre ler o buffer e gravar a trava, mais
  do que o intervalo entre publicar um quadro e começar a gravar o seguinte:
  no mínimo 0,64 ms (Bobby, deslocamento -16) e de 1,64 a 1,90 ms com o
  deslocamento 0. O player v17 gasta uns 5 µs: margem de mais de 100 vezes.
- Nenhum quadro foi perdido (`fb_dropped` e `fifo_ovf` em 0), nem com 300 a 370
  tiles diferentes por quadro.
- As quatro palavras de cor da **última linha** (entrada 231) são gravadas ~12 µs
  **depois** da publicação do quadro, no buffer já publicado. Sem efeito prático
  medido (o HDMA lê essas cores milissegundos depois). Correção possível: segurar
  a publicação até essas palavras saírem (até 1 linha de atraso, bit novo).
- Fica em observação até confirmar a olho nu no console e fazer o A/B com o
  Passo 33 + player v14.

## Aprovado no console (Passo 36, Superchip F8SC e F6SC, 23/10/2026)

Bit `fpga_atari.bit` md5 `d33d69b587c485e9435126053061b8a9` (versão `$0E`,
semente 7), `firmware.img` (Passo 36) md5 `789fb4f590d76aebfc09a745adb1bfd1` e
`atari_snes.bin` (player v17, inalterado) md5 `4074bd4c8861c1dd586a8799d16e412f`.
Testado no console: as duas ROMs de teste do Superchip (`sc_ram_f8sc` e
`sc_ram_f6sc`, em verde), Dig Dug, Crystal Castles, Klax, Secret Quest, Desert
Falcon, Jr. Pac-Man, Millipede e Stargate; River Raid, Pitfall, Bobby Is Going
Home e Decathlon iguais ao Passo 35.

Em simulação (88 ROMs F8SC/F6SC, contra o Stella): 34 OK com a RAM contra 8 sem
ela, 26 viraram OK, nenhuma piorou. As 516 ROMs da régua: iguais, pixel a
pixel, com o Superchip desligado. Folga de timing de **+0,001 ns** a 96 MHz
(semente 7; é a menor já publicada): qualquer mudança no core pede nova varredura
de sementes. 5.455 LUTs, 3.141 slices (87%).

## Aprovado no console (Passos 34 e 35 + player v17, 22/10/2026)

Bit `fpga_atari.bit` md5 `a6769dd1c0da788fbd5450242752753f` (versão `$0D`),
`atari_snes.bin` (player v17) md5 `4074bd4c8861c1dd586a8799d16e412f` e
`firmware.img` (Passo 35, sobre a release oficial v1.11.2-br-v2.17) md5
`ae29494ac8d370b263aef5a1042c5b79`. Captura de 232 linhas, placar com
prioridade (V1) e as pastas do menu sem o "?10". Feito a partir da lógica do
chip original (notas do Towers, esquemáticos e *Stella Programmer's Guide*), não
medido num Atari. Barras do HMOVE: ficam pretas, como no original.

Diferenças em aberto: **Ghoul** (+1 pixel, `hm_stuck`) e **Chess** (janela de
START do míssil logo depois de RESMx). Folga de timing de +0,003 ns a 96 MHz
(abaixo da meta de +0,2 ns): qualquer mudança no core pede nova varredura de
sementes.

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
- **Bobby Is Going Home**: tratado nas 232 linhas do Passo 34.
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
