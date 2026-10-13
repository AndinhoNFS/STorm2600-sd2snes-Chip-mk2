# sdcard/: arquivos do cartão para o modo Atari

Esta pasta espelha a raiz do cartão SD do sd2snes (Mk.II). Contém só o que o
modo Atari acrescenta ou substitui; o resto da pasta `/sd2snes/` do cartão
(menu, demais cores do FPGA) continua sendo o da instalação normal do sd2snes.

Estado: **Passo 24** (bitstream versão `$06`, player v7).

| Arquivo | Tamanho | md5 | O que é |
|---|---|---|---|
| `sd2snes/fpga_atari.bit` | 121293 | `473215f082acd657de7f586d61e5d214` | bitstream do core do Atari (Passo 24) |
| `sd2snes/atari_snes.bin` | 32768 | `c89e847b9fab2aa53aade96387d4fbe2` | player SNES v7 (é o `atari_snes7.bin` das Releases, já com o nome que o firmware abre) |
| `sd2snes/firmware.img` | 113079 | `8b1ee64bd9cbc2c24517d902b3fdf788` | firmware do Mk.II com o modo Atari (compilado em 2026-10-11) |

Os mesmos md5 estão em `MD5SUMS`.

## Instalação

1. **Guarde uma cópia do `/sd2snes/firmware.img` que está hoje no cartão.** O
   daqui substitui o firmware do cartão inteiro, não só o modo Atari.
2. Confira os arquivos: dentro de `sdcard/`, rode `md5sum -c MD5SUMS`.
3. Copie o conteúdo de `sdcard/` para a raiz do cartão, mesclando com a pasta
   `/sd2snes/` que já existe (não apague a pasta do cartão). `LEIAME.md` e
   `MD5SUMS` não precisam ir.
4. Coloque o cartão e ligue o console. O bootloader grava o `firmware.img` na
   primeira partida.
5. Copie suas ROMs `.a26` para onde quiser no cartão. ROMs não são
   distribuídas com este projeto.

## Avisos

- O bitstream do Passo 24 ainda não foi testado no console. O último testado é
  o do Passo 23, na Release `v0.7-p23`.
- O `firmware.img` é só para o Mk.II; o Mk.III não foi compilado com o modo
  Atari. Ele é uma cópia modificada do firmware do
  [sd2snes](https://github.com/ludufre/sd2snes) (GPL-2.0), e o fonte modificado
  ainda não está neste repositório.
- Este firmware escolhe o mapper F8 para todo arquivo de 8 KB, então o
  Decathlon (mapper FE) continua com tela preta. Ver `docs/PENDENCIAS.md`.
- ROMs com RAM Superchip não são recusadas, mas o core não a implementa.
