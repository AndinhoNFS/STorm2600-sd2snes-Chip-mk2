# Pendências

## Bugs abertos

- **Bola (Decathlon, Crackpots)**: quando o jogo faz RESBL logo depois de
  HMOVE, ainda no apagamento, a bola sai 1 pixel à esquerda do emulador. No
  HMOVE seguinte ela aparece na última coluna da direita. No console sobram 2-3
  pixels no Decathlon. Em simulação são 8 pixels por quadro no Decathlon e uma
  linha na coluna 159 do Crackpots. Item A do Passo 26.
- **Checkers**: as casas azuis do tabuleiro somem, porque o jogo troca a cor
  de fundo depois do pixel 16, onde o core lê as 4 cores da linha. Item B do
  Passo 26.
- **Leituras do TIA**: os bits 5..0 voltam 0 em vez do último valor do
  barramento.

## A confirmar no console (Passo 24/25)

Corrigidos em simulação contra o emulador. Em 2026-10-14 o bitstream do Passo 24
foi usado no console: o Decathlon abre (com o firmware do Passo 25), e as barras
POWER do H.E.R.O. e OXYGEN do Seaquest aparecem.

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
