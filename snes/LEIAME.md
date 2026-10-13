# snes/: player SNES v7

Fonte do player (65816, ca65), escrito do zero para este projeto
(GPL-2.0-or-later). É a "ROM" de 32 KB que o SNES executa: mostra o quadro que
o core deixou na PSRAM, lê o controle e escreve nos registradores do core.

| Arquivo | Conteúdo |
|---|---|
| `atari_snes7.s` | o player |
| `swcha_lut.inc` | tabela do joystick |
| `lorom.cfg` | mapa LoROM de 32 KB para o ld65 |
| `fix_snes_checksum.py` | preenche o checksum do cabeçalho SNES |
| `emu65816.py`, `test3g.py`, `test7.py`, `palette_ntsc.inc` | emulador 65816 em Python e os testes do player |
| `LEIAME.txt` | as instruções originais que vieram com os fontes |

## Montar

Precisa do cc65 (`ca65` e `ld65`). Nesta pasta:

```
ca65 -l atari_snes7.lst -o atari_snes7.o atari_snes7.s
ld65 -C lorom.cfg -o atari_snes7.bin atari_snes7.o
python3 fix_snes_checksum.py atari_snes7.bin
md5sum atari_snes7.bin
```

O md5 deve ser `c89e847b9fab2aa53aade96387d4fbe2`, o mesmo de
`sdcard/sd2snes/atari_snes.bin`. Conferido em 2026-10-13 com o pacote `cc65`
2.19-1 do Ubuntu 24.04 (o `ca65 --version` dele responde "V2.18 - Ubuntu
2.19-1"): o binário sai idêntico, byte a byte.

## Testar

```
cp atari_snes7.lst atari_snes3.lst    # o teste lê os símbolos deste nome
python3 test7.py                      # deve terminar com "ALL OK"
```

Os arquivos gerados (`.o`, `.lst`, `.bin`) não são versionados.

O funcionamento, quadro a quadro, está em `docs/player_descricao_completa.md`;
o contrato com o core, em `docs/DESIGN.md` e `docs/LAYOUT_BUFFER.txt`.
