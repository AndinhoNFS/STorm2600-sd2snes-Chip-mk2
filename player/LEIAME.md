# player/: player SNES v13

Fonte do player (65816, ca65), escrito do zero para este projeto
(GPL-2.0-or-later). É a "ROM" de 32 KB que o SNES executa: mostra o quadro que
o core deixou na PSRAM, lê o controle e escreve nos registradores do core.
Substitui o player v7 (que está na tag `v0.7-p26`, pasta `snes/`).

| Arquivo | Conteúdo |
|---|---|
| `atari_snes13.s` | o player |
| `font_txt.inc` | fonte e linhas de texto do aviso na tela (gerado por `gen_font.py`) |
| `swcha_lut.inc` | tabela do joystick |
| `lorom.cfg` | mapa LoROM de 32 KB para o ld65 |
| `fix_snes_checksum.py` | preenche o checksum do cabeçalho SNES |
| `emu65816.py`, `test3g.py`, `test13.py`, `palette_ntsc.inc` | emulador 65816 em Python e os testes do player |

## O que o v13 acrescenta ao v7

- **X**: próxima paleta (Color-1, Color-2, Color-3, Black/White), escrita no
  registrador 8 do core (`$2028`) a cada quadro. Ignorado durante a pausa.
- **Y**: nível Easy, Normal, Hard (chaves de dificuldade do Atari: Easy = as
  duas em B, Normal = esquerda B e direita A, Hard = as duas em A). Começa em
  Hard, como no v7; o primeiro Y passa para Easy.
- O nome da paleta ou do nível aparece por ~2,5 s em texto verde, sem fundo,
  dentro da imagem (BG2).
- A paleta do texto é regravada a cada quadro durante o apagamento vertical.

## Montar

Precisa do cc65 (`ca65` e `ld65`). Nesta pasta:

```
ca65 -l atari_snes13.lst -o atari_snes13.o atari_snes13.s
ld65 -C lorom.cfg -o atari_snes13.bin atari_snes13.o
python3 fix_snes_checksum.py atari_snes13.bin
md5sum atari_snes13.bin
```

O md5 deve ser `8735f54a9edb3e8da8b32d25855a6c96`, o mesmo de
`sdcard/sd2snes/atari_snes.bin`. Conferido em 2026-10-16 com o pacote `cc65`
2.19-1 do Ubuntu 24.04 (`ca65 V2.18 - Ubuntu 2.19-1`): o binário sai idêntico,
byte a byte. `python3 gen_font.py` regenera o `font_txt.inc` idêntico.

## Testar

```
cp atari_snes13.lst atari_snes3.lst    # o teste lê os símbolos deste nome
python3 test13.py                      # deve terminar com "ALL OK v13"
```

Os arquivos gerados (`.o`, `.lst`, `.bin`) não são versionados.
