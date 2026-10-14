# sdcard/: arquivos do cartão para o modo Atari

Esta pasta tem só os 3 arquivos que o modo Atari acrescenta ou substitui na pasta
`/sd2snes/` do cartão do sd2snes (Mk.II). O resto da pasta (menu, demais cores
do FPGA) vem da release do sd2snes (passo 1 da Instalação).

Estado: **Passo 26**: bitstream do Passo 26 (versão `$07`), player v7 e o firmware do Passo 25, que detecta o mapper FE.

| Arquivo | Tamanho | md5 | O que é |
|---|---|---|---|
| `sd2snes/fpga_atari.bit` | 120807 | `7d19e73ad27b7a03e51e2fe0947b663a` | bitstream do core do Atari (Passo 26: correção da bola) |
| `sd2snes/atari_snes.bin` | 32768 | `c89e847b9fab2aa53aade96387d4fbe2` | player SNES v7 (é o `atari_snes7.bin` das Releases, já com o nome que o firmware abre) |
| `sd2snes/firmware.img` | 113323 | `f9634a74371d24489c0727ded05604b3` | firmware do Mk.II com o modo Atari e a detecção do FE (Passo 25, compilado em 2026-10-14; na Release `v0.7-p25` se chama `firmware_p25.img`) |

Os mesmos md5 estão em `MD5SUMS`.

## Aviso

Sem nenhuma garantia (ver a `LICENSE` na raiz); use por sua conta e risco.

- O `firmware.img` é **só para o sd2snes Mk.II** e regrava o firmware do
  cartão, não só o modo Atari.
- Antes de instalar, guarde o `/sd2snes/firmware.img` que está no cartão. O
  firmware anterior deste projeto tem md5 `8b1ee64bd9cbc2c24517d902b3fdf788` e
  sai com `git show 54b223e:sdcard/sd2snes/firmware.img > firmware.img` (ver
  "Voltar ao firmware anterior").
- Se o cartão não iniciar depois da troca: o bootloader do sd2snes não é
  regravado e roda a cada partida. Ele lê o `/sd2snes/firmware.img` e regrava o
  flash quando a versão do arquivo é diferente da gravada e o CRC confere; um
  arquivo corrompido não é gravado. Ponha no cartão um `firmware.img` válido (o
  que você guardou) e ligue o console.
- Projeto independente, não afiliado à Atari nem aos autores do sd2snes e do
  MiSTer. Não inclui ROMs.

## Instalação

0. **Guarde uma cópia do `/sd2snes/firmware.img` que está hoje no cartão.** O
   daqui substitui o firmware do cartão inteiro, não só o modo Atari.
1. Baixe a release [v1.11.2-br-v2.16.4 do ludufre/sd2snes](https://github.com/ludufre/sd2snes/releases/tag/v1.11.2-br-v2.16.4)
   (`sd2snes_firmware_v1.11.2-br-2.16.4.zip`) e copie a pasta `sd2snes` dela
   para a raiz do cartão.
2. Copie os 3 arquivos desta pasta `sd2snes/` (`fpga_atari.bit`,
   `atari_snes.bin`, `firmware.img`) para a pasta `sd2snes` do cartão,
   substituindo o `firmware.img`. Antes, se quiser, confira os md5: dentro de
   `sdcard/`, `md5sum -c MD5SUMS`.
3. Ponha as ROMs `.a26` em qualquer pasta do cartão (não são distribuídas com
   este projeto). Ligue o console: o bootloader grava o `firmware.img` na
   primeira partida.

**Testado apenas** com o firmware do Passo 25 (feito do commit `1b5d9d79` do
ludufre/sd2snes) junto com a release v1.11.2-br-v2.16.4. Com a base 2.17 não
foi testado.

## Voltar ao bitstream anterior

O bitstream do Passo 24 tem 121293 bytes e md5
`473215f082acd657de7f586d61e5d214`. Ele está na Release `v0.7-p24` e no
histórico do repositório:

```
git show v0.7-p25:sdcard/sd2snes/fpga_atari.bit > fpga_atari.bit
```

Grave-o como `/sd2snes/fpga_atari.bit`. O bitstream é lido do cartão a cada
jogo, sem gravação em flash: basta trocar o arquivo.

## Voltar ao firmware anterior

O firmware anterior (Passos 23 e 24, sem a detecção do FE) tem 113079 bytes e
md5 `8b1ee64bd9cbc2c24517d902b3fdf788`. Ele continua no histórico do
repositório:

```
git show 54b223e:sdcard/sd2snes/firmware.img > firmware.img
```

Grave esse arquivo como `/sd2snes/firmware.img` e ligue o console. O
bootloader regrava o flash sempre que a versão no cabeçalho do arquivo é
diferente da gravada, e só grava se o CRC do arquivo conferir.

## Avisos

- No console, em 2026-10-14, com este conjunto: Crackpots e Decathlon OK (o
  Decathlon original abre e a bola está no lugar). Checkers, H.E.R.O. e Seaquest
  continuam com a limitação de cor do Passo 24. Robot Tank e Thwocker também
  passam a FE, mas só foram testados em simulação.
- O `firmware.img` é só para o Mk.II; o Mk.III não foi compilado com o modo
  Atari. Ele é uma cópia modificada do firmware do
  [sd2snes](https://github.com/ludufre/sd2snes) (GPL versão 2); as mudanças e
  como recompilar estão em `firmware/`.
- A detecção do FE segue o Stella (ver `firmware/LEIAME.md`). Os outros
  arquivos de 8 KB continuam como F8.
- ROMs com RAM Superchip não são recusadas, mas o core não a implementa.
