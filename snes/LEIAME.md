# Player SNES

O fonte do player v7 (assembly 65816 e script de montagem) **ainda não está
neste repositório** e será adicionado depois. Ele foi procurado nas pastas de
trabalho do projeto em 2026-10-13 e não foi encontrado; lá só existem os fontes
das versões 1 e 2 (`atari_snes.s`, `atari_snes2.s`, montados com ca65/ld65,
`lorom.cfg` e `fix_snes_checksum.py`), que não servem para o bitstream atual e
não foram importados.

O binário (md5 `c89e847b9fab2aa53aade96387d4fbe2`) está em
`sdcard/sd2snes/atari_snes.bin`, com o nome que o firmware abre, e na página de
Releases como `atari_snes7.bin`.

O funcionamento do player, quadro a quadro, e como ele foi construído estão em
`docs/player_descricao_completa.md`. Segundo essa descrição, o fonte é o
`atari_snes7.s` (ca65/ld65, com `lorom.cfg` e `fix_snes_checksum.py`), testado
com um emulador 65816 em Python (`emu65816.py`, `test7.py`); são esses os
arquivos que faltam aqui. O contrato com o core está em `docs/DESIGN.md` e
`docs/LAYOUT_BUFFER.txt`.
