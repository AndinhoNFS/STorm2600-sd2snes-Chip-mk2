# firmware/: modo Atari no firmware do sd2snes Mk.II

O `sdcard/sd2snes/firmware.img` é o firmware do
[ludufre/sd2snes](https://github.com/ludufre/sd2snes) no commit `1b5d9d79`
("fix(menu): slow opening of folders with many MSU-1 games", versão
`1.11.2-br-2.17`), compilado para o Mk.II com as mudanças desta pasta. O
firmware é GPL versão 2; os cabeçalhos de licença e de autoria originais dos
arquivos foram mantidos.

| Arquivo | Conteúdo |
|---|---|
| `mk2_atari.patch` | diferença completa em relação ao commit `1b5d9d79` (4 arquivos) |
| `src/atari.c`, `src/atari.h`, `src/fpga.h`, `src/memory.c` | os quatro arquivos já modificados, inteiros |

Nenhum outro arquivo do firmware foi alterado.

## O que muda

- `atari.c`: o código que detecta o mapper e carrega o `.a26`, que no original
  só compila para o Mk.III, passa a compilar também para o Mk.II.
- `atari.h`: no Mk.II o player é `/sd2snes/atari_snes.bin`. O firmware entrega
  o mapper ao player gravando dois bytes na imagem dele na PSRAM (`$7FF0` =
  mapper, `$7FF1` = `$A2`); é o player que escreve o mapper no registrador 3
  do core.
- `fpga.h`: nome do bitstream, `/sd2snes/fpga_atari.bit`.
- `memory.c`: para um `.a26` a máscara de ROM passa a 4 MB, para o SNES
  enxergar os buffers de quadro do core em `$70:8000`; o Mk.II não usa o
  CHIPFEAT para o Atari.

## Como reproduzir

```
git clone https://github.com/ludufre/sd2snes && cd sd2snes
git checkout 1b5d9d79
git apply /caminho/para/firmware/mk2_atari.patch
cd src && make CONFIG=config-mk2
```

O resultado sai em `src/obj-mk2/firmware.img`. O binário distribuído foi
compilado com arm-none-eabi-gcc 13.2.1 em 2026-10-11. O md5 do `firmware.img`
muda a cada compilação, mesmo com o mesmo fonte, então um build novo não
reproduz o md5 de `sdcard/MD5SUMS`.

## Limitações

- A detecção escolhe F8 para todo arquivo de 8 KB; falta detectar o FE
  (Decathlon). Ver `docs/PENDENCIAS.md`.
- O Mk.III não foi compilado nem testado com estas mudanças.
