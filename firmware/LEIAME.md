# firmware/: modo Atari no firmware do sd2snes Mk.II

O `sdcard/sd2snes/firmware.img` é o firmware do
[ludufre/sd2snes](https://github.com/ludufre/sd2snes) no commit `1b5d9d79`
("fix(menu): slow opening of folders with many MSU-1 games", versão
`1.11.2-br-2.17`), compilado para o Mk.II com as mudanças desta pasta. O
firmware é GPL versão 2; os cabeçalhos de licença e de autoria originais dos
arquivos foram mantidos.

| Arquivo | Conteúdo |
|---|---|
| `mk2_atari.patch` | diferença completa em relação ao commit `1b5d9d79` (5 arquivos) |
| `src/atari.c`, `src/atari.h`, `src/fpga.h`, `src/memory.c` | os quatro arquivos do firmware já modificados, inteiros |
| `tests/host/a26_detect_cli.c` | o programa de teste no PC que roda o detector de `atari.c`; só ganhou o nome "FE" |

Nenhum outro arquivo do firmware foi alterado.

## O que muda

- `atari.c`: o código que detecta o mapper e carrega o `.a26`, que no original
  só compila para o Mk.III, passa a compilar também para o Mk.II.
- `atari.h`: no Mk.II o player é `/sd2snes/atari_snes.bin`. O firmware entrega
  o mapper ao player gravando dois bytes na imagem dele na PSRAM (`$7FF0` =
  mapper, `$7FF1` = `$A2`); é o player que escreve o mapper no registrador 3
  do core.
- `fpga.h`: nome do bitstream, `/sd2snes/fpga_atari.bit`.
- `atari.c` / `atari.h` (Passo 25): detecção do mapper FE, descrita abaixo.
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

O resultado sai em `src/obj-mk2/firmware.img`. Numa árvore limpa, compile antes
os utilitários (`make -C utils bin2c` e `make -C src/utils`). O `config-mk2`
aponta para `../verilog/sd2snes_mini/fpga_mini.bit`, que não existe na árvore.
O binário distribuído foi compilado com o conteúdo de 11 bytes `placeholder` no
lugar dele: `make CONFIG=config-mk2 CONFIG_CFGWARE=<arquivo com "placeholder">`.

O binário do Passo 25 foi compilado com arm-none-eabi-gcc 13.2.1 em 2026-10-14.
Compilado de novo a partir do `1b5d9d79` com este patch, ele sai idêntico byte
a byte, menos os 4 bytes de versão do cabeçalho (bytes 4 a 7). Esses bytes são
um hash da hora do build, então o md5 de um build novo nunca bate com o de
`sdcard/MD5SUMS`.

## Detecção do mapper FE (Passo 25)

O critério é o mesmo do Stella (`CartDetector::isProbablyFE` e o ramo de 8 KB de
`autodetectType`, commit `2c3d7023`). Um `.a26` de 8192 bytes vira mapper 5 (FE)
quando atende às três condições:

- tem uma destas sequências em qualquer lugar do arquivo:
  `20 00 D0 C6 C5` (Decathlon), `20 C3 F8 A5 82` (Robot Tank),
  `D0 FB 20 73 FE` e `D0 FB 20 68 FE` (Space Shuttle), `20 00 F0 84 D6` (Thwocker);
- não tem duas vezes nem `8D F9 1F` (`STA $1FF9`) nem `8D F9 FF` (`STA $FFF9`);
- não foi recusado como 3F ou UA e não tem indício de RAM Superchip.

Qualquer outro arquivo fica com o mapper de antes. A detecção só existe no Mk.II
(`A26_HAVE_FE` em `atari.h`); no Mk.III nada muda. O valor 5 chega ao core pelo
mesmo caminho dos outros mappers: `$7FF0` da imagem do player.

Na coleção de 5.317 `.a26` do autor, só 13 arquivos mudaram de F8 para FE
(Decathlon, Robot Tank e hacks dele, Thwocker), e a regra do Stella dá FE
exatamente nos mesmos.

No console (2026-10-14, com o bitstream do Passo 24): o Decathlon original abre.
Robot Tank e Thwocker foram testados só em simulação.

## Limitações

- E0, 3F e F8SC de 8 KB continuam saindo como F8, como antes do Passo 25.
- O Mk.III não foi compilado nem testado com estas mudanças.
