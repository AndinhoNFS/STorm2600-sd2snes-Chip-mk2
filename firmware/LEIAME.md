# firmware/: modo Atari no firmware do sd2snes Mk.II

O `sdcard/sd2snes/firmware.img` é o firmware do
[ludufre/sd2snes](https://github.com/ludufre/sd2snes) na tag oficial
`v1.11.2-br-v2.18.1` (versão `1.11.2-br-2.18.1`), compilado para o Mk.II com as
mudanças desta pasta (Passo 37; os Passos 35 e 36 usaram a tag `v1.11.2-br-v2.17`; o Passo 25 usou o commit `1b5d9d79`, que é a
v2.17 mais 4 commits, e o `menu.bin` dele só existe compilando o `snes/` desse
commit). O
firmware é GPL versão 2; os cabeçalhos de licença e de autoria originais dos
arquivos foram mantidos.

| Arquivo | Conteúdo |
|---|---|
| `mk2_atari.patch` | diferença completa em relação à tag `v1.11.2-br-v2.18.1` (5 arquivos) |
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
- `atari.c` / `memory.c` (Passo 36): Superchip. No Mk.II o `.a26` de 8 KB ou 16 KB
  vale como Superchip pela regra de antes **ou** pela do espelho (os primeiros 128
  bytes de cada banco de 4 KB se repetem nos 128 seguintes); a regra do espelho
  não usa buffer, só compara dentro do bloco de 512 bytes da leitura. O
  `memory.c` grava o bit 4 do byte do mapper (`$7FF0`) quando há Superchip em F8
  ou F6; o F4 com Superchip continua F4 (a ROM do core tem 16 KB).
- `memory.c`: para um `.a26` a máscara de ROM passa a 4 MB, para o SNES
  enxergar os buffers de quadro do core em `$70:8000`; o Mk.II não usa o
  CHIPFEAT para o Atari.

## Como reproduzir

```
git clone https://github.com/ludufre/sd2snes && cd sd2snes
git checkout v1.11.2-br-v2.18.1
git apply /caminho/para/firmware/mk2_atari.patch
cd src && make CONFIG=config-mk2
```

O resultado sai em `src/obj-mk2/firmware.img`. Numa árvore limpa, compile antes
os utilitários (`make -C utils bin2c` e `make -C src/utils`). O `config-mk2`
aponta para `../verilog/sd2snes_mini/fpga_mini.bit`, que não existe na árvore.
O binário distribuído foi compilado com o conteúdo de 11 bytes `placeholder` no
lugar dele: `make CONFIG=config-mk2 CONFIG_CFGWARE=<arquivo com "placeholder">`.

O binário do Passo 25 foi compilado com arm-none-eabi-gcc 13.2.1 em 2026-10-14.
Compilado de novo a partir da v2.17 com este patch, ele sai idêntico byte
a byte, menos os 4 bytes de versão do cabeçalho (bytes 4 a 7). Esses bytes são
um hash da hora do build, então o md5 de um build novo nunca bate com o de
`sdcard/MD5SUMS`.

## Detecção do mapper FE (Passo 25)

O critério: cinco assinaturas de código e a regra do ramo de 8 KB. Um `.a26` de 8192 bytes vira mapper 5 (FE)
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
(Decathlon, Robot Tank e hacks dele, Thwocker), e a regra dá FE
exatamente nos mesmos.

No console (2026-10-14, com o bitstream do Passo 24): o Decathlon original abre.
Robot Tank e Thwocker foram testados só em simulação.

## Limitações

- E0, 3F e F8SC de 8 KB continuam saindo como F8, como antes do Passo 25.
- O Mk.III não foi compilado nem testado com estas mudanças.

## Passo 35: o que mudou em relação ao Passo 25

- Base: tag `v1.11.2-br-v2.17`. O `menu.bin` que acompanha é o da zip oficial
  da v2.17 (md5 `07e111b629fb...`); com o firmware do Passo 25 ele não servia,
  porque o firmware já gravava a marca de pasta `?` + cluster que só o menu
  daquele commit entende (sintoma: pastas mostrando "?10", "?G").
- O enum `A26_BS_FE` e a varredura de FE (`a26_fe_byte` e campos de
  `a26_scan_t`) ficam dentro de `CONFIG_MK2`: o firmware do Mk.III compilado
  com este patch é idêntico ao oficial (só os bytes 4 a 7 do cabeçalho, o hash
  da hora do build, diferem).
- Tamanho do Mk.II: 112.327 bytes (limite 122.880), sobra de 10.553 bytes.

## Passo 37: base v1.11.2-br-v2.18.1

- Base: tag `v1.11.2-br-v2.18.1` do ludufre (não a `v2.18`, que tem um defeito no menu de
  Configuração). `atari.c`, `atari.h` e `verilog/sd2snes_a26` do ludufre não mudaram da 2.17 para
  a 2.18.1; `memory.c` e `fpga.h` mudaram bastante, e o patch foi refeito sobre eles (os mesmos
  ganchos, em `load_set_features`, `load_setup_masks`, `load_stage_consoles` e `load_identify`).
- O Mk.II da 2.18.1, sem o modo Atari, usa 121.739 bytes de flash e sobram 1.141 até o limite
  (o `ld` recusa a ligação se o `.data` inicializado passar do fim da flash). O modo Atari com o
  `atari.c` do Passo 36 passava desse limite em 619 bytes. O que foi feito para caber, **só dentro de
  `CONFIG_MK2`** (o Mk.III segue idêntico):
  - saíram do Mk.II os contadores que só alimentavam a linha de log (`score_3f`, `dist_3f`,
    contagem de E0, `score_ua`, `feat16`, o `size_class`), porque no Mk.II o esquema não vai por
    CHIPFEAT e nada lê esses campos;
  - o mapa de 128 bits dos operandos de leitura do Superchip virou "primeiro operando + há outro?"
    (a decisão só pede dois distintos); a pergunta "o preâmbulo de 256 bytes é um byte constante?"
    virou uma comparação de bloco, no mesmo lugar da regra do espelho;
  - a varredura passou a ser uma só, byte a byte (`a26_scan_byte`), com o histórico dos quatro
    bytes anteriores em um `uint32_t`: some o carregamento de 2 bytes entre blocos de 512;
  - `a26_scan_byte` e `a26_decide` ficam fora de linha (`noinline`), o que no Mk.II economiza 73 bytes.
  O veredito (esquema, Superchip, recusa) não muda: o detector do Passo 37 e o do Passo 36,
  ambos compilados com `CONFIG_MK2`, dão o mesmo resultado nos 5.055 arquivos da biblioteca
  e em 4.000 imagens sintéticas com padrões plantados (3F, UA, leitura da RAM do Superchip, FE,
  `STA $1FF9`, preâmbulo constante e espelho de 128 bytes, inclusive nas fronteiras de bloco).
- Tamanho do Mk.II: 122.807 bytes na imagem; sobram **73 bytes** antes do limite do
  `.data` inicializado em flash (o `ld` recusa a ligação se estourar). Qualquer acréscimo
  em `atari.c` ou `memory.c` no Mk.II exige tirar outro tanto.
- `make modcheck` (os módulos de cartão `fileops.bin` e `rmdir.bin` cabem no bloco de 10.960
  bytes depois do `ptrcache`, com o espaço de trabalho de 1.792 bytes) passa para o Mk.II e o Mk.III, igual à
  tag sem o patch; o `ptrcache` fica no mesmo endereço.
