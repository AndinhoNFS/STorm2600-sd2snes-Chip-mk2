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

## Player v14 (em teste)

Arquivos novos, ao lado do v13: `atari_snes14.s`, `gen_font14.py`,
`font_txt14.inc` e `test14.py`. O v13 continua montando idêntico.

- **PAUSE na tela:** enquanto o jogo está pausado (R), aparece "PAUSE" no
  mesmo lugar e na mesma cor dos nomes de paleta e nível, sem tempo limite. No
  quadro em que o R retoma o jogo, o texto some.
- Pausar apaga um nome de paleta ou nível que ainda estava na tela.
- **Y** é ignorado durante a pausa, como o X já era.
- O texto só liga depois que a linha nova chega à VRAM. Antes, o nome
  anterior podia aparecer por um quadro.

Montar e testar o v14 é igual ao v13, trocando `13` por `14` nos comandos
(`python3 gen_font14.py` regenera o `font_txt14.inc`). O teste termina com
"ALL OK v14". md5 do `atari_snes14.bin`: `9cbeeda15bec0d7cacd8fea0c9e4b48c`.

## Player v17 (versão pública, só com o core do Passo 34)

Arquivos: `atari_snes17.s` e `test17.py` ("ALL OK v17"); usa o
`font_txt15.inc`. md5 do `atari_snes17.bin`: `4074bd4c8861c1dd586a8799d16e412f`.

- Igual ao v15, mas **sem o diagnóstico do L**: na versão pública o L não faz nada.
- **Versão de teste** (só para nós): `ca65 -D DIAGBLD=1 ...` gera um binário
  idêntico byte a byte ao v15 (`2f1494cf…`), com o `N### L###` no L.

## Player v15 (versão de teste, só com o core do Passo 34)

Arquivos: `atari_snes15.s`, `gen_font15.py`, `font_txt15.inc`, `test15.py`
("ALL OK v15"). md5 do `atari_snes15.bin`: `2f1494cf27ebc8b7d68e4707c90b4bb3`.
**Só funciona com o core do Passo 34** (232 linhas, mapa de 29 fileiras,
tabelas de 233 entradas com a 232 preta). Com o core do P33 a imagem sai errada.

- 232 linhas de imagem (TIA 27..258), com cada linha do TIA no mesmo lugar da
  TV que antes (TIA 34 continua na linha V = 9).
- Display ligado em V = 1 e force blank em V = 233: o tempo para a cópia do
  mapa e dos tiles continua de 30 linhas, como no v14.
- **L segurado:** mostra `N### L###` = o maior número de tiles por quadro e o
  maior atraso da cópia, em linhas (quantas linhas do topo apareceram
  atrasadas), desde que o L foi apertado. O L não é entrada do Atari.
- PAUSE tem prioridade sobre o diagnóstico.

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
