# Pendências

## Bugs abertos

- **Checkers**: no console o tabuleiro azul não aparece (relato do usuário).
  Em simulação são 982.260 pixels de cor errada em 85 quadros, em cada cenário
  (parado e jogando): o jogo troca a cor de fundo depois do pixel 16, onde o
  core lê as 4 cores da linha. Item B do Passo 26, ainda aberto (ver abaixo).
- **Barras do H.E.R.O. (POWER) e do Seaquest (OXYGEN)**: no console o efeito
  da barra existe (a parte vermelha, que é a gasta, aparece e encolhe a barra),
  mas a cor da parte que resta (amarela no H.E.R.O., branca no Seaquest) não
  aparece. Em simulação a linha inteira sai cinza: o jogo troca COLUPF no meio
  da linha e todos os pixels da linha recebem o mesmo índice de tile (H.E.R.O.
  32.450 / 31.545 e Seaquest 26.145 pixels de cor errada em 85 quadros). Como o
  console mostra algo que a simulação não grava, o hardware grava índices
  diferentes dos da simulação. Item aberto: ler a PSRAM no console para
  descobrir o quê.
- **Alocação das 4 cores por linha (item B do Passo 26)**: cada pixel pega o
  índice que já tem a sua cor final, senão um índice livre, e as cores da linha
  vão para a tabela durante a linha seguinte. Em simulação dá 0 pixels de cor
  errada nos 11 jogos medidos (Checkers, H.E.R.O. e Seaquest inclusive), sem
  descartes. Não fecha o timing: -2,614 ns (semente 17) e -1,536 ns (semente
  10); o caminho pix_src (TIA) -> fb_wdata (gravador) não é relaxado e a
  alocação põe 9 níveis de lógica nele. Proposta (não feita): registrar o pixel
  do TIA e processá-lo num strobe atrasado ~13 clocks, num caminho relaxado. O
  código está em `atari_core/proto_p26B` (fora deste repositório).
- **Leituras do TIA**: os bits 5..0 voltam 0 em vez do último valor do
  barramento.

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
- Folga de timing: 0,024 ns no Passo 24, depois de 12 sementes. O caminho do
  TIA até o gravador de vídeo está no limite.

## Corrigidos no Passo 26

- **Bola (Crackpots, Decathlon)**: RESBL logo depois de HMOVE, ainda no
  apagamento, punha a bola 1 pixel à esquerda e, no HMOVE seguinte, na última
  coluna da direita. Agora vai para a posição 3, como no emulador. Confirmado no
  console com o bitstream `7d19e73ad27b7a03e51e2fe0947b663a` (versão `$07`):
  Crackpots e Decathlon OK (os 2-3 pixels da bola do Decathlon sumiram). Em
  simulação: 0 pixels diferentes do emulador na bola, outros 9 jogos sem
  mudança. Esse bitstream ainda não está neste repositório.

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
