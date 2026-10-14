# sdcard/: arquivos do cartão para o modo Atari

Esta pasta espelha a raiz do cartão SD do sd2snes (Mk.II). Contém só o que o
modo Atari acrescenta ou substitui; o resto da pasta `/sd2snes/` do cartão
(menu, demais cores do FPGA) continua sendo o da instalação normal do sd2snes.

Estado: **Passo 25**: bitstream do Passo 24 (versão `$06`), player v7 e o firmware do Passo 25, que detecta o mapper FE.

| Arquivo | Tamanho | md5 | O que é |
|---|---|---|---|
| `sd2snes/fpga_atari.bit` | 121293 | `473215f082acd657de7f586d61e5d214` | bitstream do core do Atari (Passo 24) |
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

- No console, em 2026-10-14: com este conjunto o Decathlon original abre, com
  2-3 pixels da bola fora do lugar. Eles foram corrigidos pelo bitstream do
  Passo 26 (md5 `7d19e73ad27b7a03e51e2fe0947b663a`, versão `$07`), confirmado no
  console, que ainda não está nesta pasta. Robot Tank e Thwocker também passam a
  FE, mas só foram testados em simulação.
- O `firmware.img` é só para o Mk.II; o Mk.III não foi compilado com o modo
  Atari. Ele é uma cópia modificada do firmware do
  [sd2snes](https://github.com/ludufre/sd2snes) (GPL versão 2); as mudanças e
  como recompilar estão em `firmware/`.
- A detecção do FE segue o Stella (ver `firmware/LEIAME.md`). Os outros
  arquivos de 8 KB continuam como F8.
- ROMs com RAM Superchip não são recusadas, mas o core não a implementa.
