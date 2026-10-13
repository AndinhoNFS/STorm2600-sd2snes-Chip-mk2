# Pendências

## Bugs abertos

- **Decathlon (e outros FE da Activision)**: tela preta no console. O core
  já tem o mapper FE (valor 5), mas o firmware escolhe F8 para todo arquivo
  de 8 KB. Falta o firmware detectar FE e passar 5. Pela descrição do player
  (`docs/player_descricao_completa.md`), o v7 repassa valores até 7 ao
  registrador 3; isso não foi conferido contra o fonte.
- **Decathlon**: a bola sai 1 pixel à esquerda do emulador numa linha em que o
  jogo faz RESBL logo depois de HMOVE (8 pixels por quadro, só em simulação).
- **Leituras do TIA**: os bits 5..0 voltam 0 em vez do último valor do
  barramento.

## A confirmar no console (Passo 24)

Corrigidos em simulação contra o emulador; o bitstream do Passo 24 ainda não
foi testado em hardware.

- **H.E.R.O.**: dois pixels perdidos apareciam em outro ponto da mesma tela, em
  várias telas, e tocar neles matava o herói. Em simulação os pixels somem
  (340 → 0 em 85 quadros). A morte do herói não foi reproduzida em simulação,
  então só o teste no console confirma essa parte.
- **Seaquest**: lacuna de pixels na barra de oxigênio (20 → 0).

## Melhorias possíveis

- Genlock (elimina o quadro repetido a cada ~5,5 s).
- Paleta PAL e autodetecção NTSC/PAL.
- Deslocamento salvo por ROM.
- Folga de timing: 0,024 ns no Passo 24, depois de 12 sementes. O caminho do
  TIA até o gravador de vídeo está no limite.
- Importar o fonte do player v7 para `snes/` (o binário já está em `sdcard/`).
  Enquanto ele faltar, o repositório distribui um binário sem o fonte.

## Corrigidos no Passo 24

- Escritas em PF0/PF1/PF2 só valem na próxima célula de 4 pixels (causa do
  H.E.R.O. e do Seaquest acima).
- GRP0/GRP1 valem 1 pixel depois (1 pixel de cor no H.E.R.O.).
- Mapper FE no core (valor 5).

## Corrigidos no Passo 23

- Bloco extra no arco‑íris da Activision (Enduro, Frostbite etc.).
- Placar do jogador 2 do Boxing.
