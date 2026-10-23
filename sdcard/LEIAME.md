# sdcard/: arquivos do cartão para o modo Atari

Esta pasta tem só os 3 arquivos que o modo Atari acrescenta ou substitui na pasta
`/sd2snes/` do cartão do sd2snes (Mk.II). O resto da pasta (menu, demais cores
do FPGA) vem da release do sd2snes (passo 1 da Instalação).

Estado: **Passo 36**, aprovado no console em 23/10/2026: bitstream do Passo 36 (versão `$0E`, Superchip F8SC e F6SC), player v17 (o mesmo do Passo 35) e o firmware do Passo 36, feito sobre a release oficial v1.11.2-br-v2.17 do ludufre/sd2snes.

| Arquivo | Tamanho | md5 | O que é |
|---|---|---|---|
| `sd2snes/fpga_atari.bit` | 129888 | `d33d69b587c485e9435126053061b8a9` | bitstream do core do Atari (Passo 36: Superchip F8SC e F6SC, versão `$0E`; mantém a captura de 232 linhas do Passo 34 e o TIA do Passo 33) |
| `sd2snes/atari_snes.bin` | 32768 | `4074bd4c8861c1dd586a8799d16e412f` | player SNES v17 (232 linhas; X paleta, Y nível, R pausa com PAUSE na tela), já com o nome que o firmware abre |
| `sd2snes/firmware.img` | 112435 | `789fb4f590d76aebfc09a745adb1bfd1` | firmware do Mk.II com o modo Atari, a detecção do FE e a do Superchip, feito sobre a tag `v1.11.2-br-v2.17` (Passo 36); casa com o `menu.bin` da própria v2.17 |

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

0. **Guarde uma cópia da pasta `/sd2snes` do cartão inteira.** O `firmware.img`
   daqui substitui o firmware do cartão, não só o modo Atari.
1. Baixe a release [v1.11.2-br-v2.17 do ludufre/sd2snes](https://github.com/ludufre/sd2snes/releases/tag/v1.11.2-br-v2.17)
   (`sd2snes_firmware_v1.11.2-br-2.17.zip`) e copie a pasta `sd2snes` dela
   **inteira** para a raiz do cartão. Isso sobrescreve `menu.bin`, `m3nu.bin`,
   `igmenu.bin`, `menu.spc`, `savestate_fixes.yml`, os `firmware.*`, `a26_snes.bin`
   (o player do Mk.III do ludufre; o nosso é `atari_snes.bin`) e os núcleos
   `fpga_*`, e acrescenta os arquivos novos da 2.17 (`onboarding.bin`,
   `welcome.*`, `music/` e outros). Se você personalizou o `menu.spc` ou o
   `savestate_fixes.yml`, guarde-os antes. Vindo de uma 2.16.x, a 2.17 não move
   nenhum arquivo do cartão; vindo da 2.15 ou anterior, siga as notas da 2.16
   do ludufre (Web Manager).
2. Copie os 3 arquivos desta pasta `sd2snes/` (`fpga_atari.bit`,
   `atari_snes.bin`, `firmware.img`) para a pasta `sd2snes` do cartão,
   substituindo o `firmware.img` da zip. Antes, se quiser, confira os md5:
   dentro de `sdcard/`, `md5sum -c MD5SUMS`.
3. Ponha as ROMs `.a26` em qualquer pasta do cartão (não são distribuídas com
   este projeto). Ligue o console: o bootloader grava o `firmware.img` na
   primeira partida, e a 2.17 mostra o tour de boas-vindas.
4. Na primeira vez que abrir um `.a26`, o menu pede a confirmação de "core
   experimental"; marque "não avisar de novo" se não quiser vê-la outra vez.

**Testado** no console com o firmware do Passo 36 junto com o pacote oficial
v1.11.2-br-v2.17 inteiro (o firmware do Passo 25 com o menu da 2.16.4 mostrava
as pastas como "?10", "?G": o menu era anterior ao firmware).

## Voltar ao bitstream e ao player anteriores

O bitstream e o player são lidos do cartão a cada jogo, sem gravação em flash:
basta trocar os arquivos. **Troque os dois juntos**: o player v17 só funciona
com o bitstream do Passo 34 ou posterior (232 linhas, Passo 36 incluído), e o v14
só com o do Passo 33 ou anterior. O conjunto do Passo 35 (Release `v0.10-p35`) é
`a6769dd1c0da788fbd5450242752753f` (bitstream, Passo 34) com o player v17 e o
firmware `ae29494ac8d370b263aef5a1042c5b79`. O conjunto do Passo 33 + player v14 (Release `v0.9-p33`) é
`87887c111a788c51805a644313b16808` (bitstream) com
`9cbeeda15bec0d7cacd8fea0c9e4b48c` (player). O conjunto do Passo 31 + player v13 (Release
`v0.8-p31`) é `5bbcf7b2be8815e326de021119af63bf` (bitstream) com
`8735f54a9edb3e8da8b32d25855a6c96` (player); os arquivos estão na Release e no
histórico (`git show v0.8-p31:sdcard/sd2snes/fpga_atari.bit`). O conjunto mais antigo (Release `v0.7-p26`) é o
bitstream do Passo 26 (120807 bytes, md5 `7d19e73ad27b7a03e51e2fe0947b663a`) com
o player v7 (32768 bytes, md5 `c89e847b9fab2aa53aade96387d4fbe2`):

```
git show v0.7-p26:sdcard/sd2snes/fpga_atari.bit > fpga_atari.bit
git show v0.7-p26:sdcard/sd2snes/atari_snes.bin > atari_snes.bin
```

Grave-os como `/sd2snes/fpga_atari.bit` e `/sd2snes/atari_snes.bin`. Troque
os dois juntos: o player v13 escreve o registrador de paleta, que o bitstream
do Passo 26 não tem (lá o X não faz nada); o player v7 com o bitstream do
Passo 31 funciona, mas fica sempre em Color-1.

## Voltar ao firmware anterior

O firmware do Passo 25 (base `1b5d9d79`, 113323 bytes, md5
`f9634a74371d24489c0727ded05604b3`) continua na Release `v0.9-p33`; ele só serve
com o `menu.bin` da release v1.11.2-br-v2.16.4 do ludufre (com o menu da 2.17 as
pastas MSU-1 não ganham o ícone de jogo). O firmware ainda anterior (Passos 23 e 24, sem a detecção do FE) tem 113079 bytes e
md5 `8b1ee64bd9cbc2c24517d902b3fdf788`. Ele continua no histórico do
repositório:

```
git show 54b223e:sdcard/sd2snes/firmware.img > firmware.img
```

Grave esse arquivo como `/sd2snes/firmware.img` e ligue o console. O
bootloader regrava o flash sempre que a versão no cabeçalho do arquivo é
diferente da gravada, e só grava se o CRC do arquivo conferir.

## Avisos

- Passo 36 (bitstream do Passo 36 + player v17 + firmware sobre a 2.17)
  aprovado pelo autor no console em 23/10/2026: as duas ROMs de teste do
  Superchip (verdes), Dig Dug, Crystal Castles, Klax, Secret Quest, Desert
  Falcon, Jr. Pac-Man, Millipede e Stargate; River Raid, Pitfall, Bobby Is
  Going Home e Decathlon iguais ao Passo 35. Passo 35 (bitstream do Passo 34 +
  player v17 + firmware sobre a 2.17) aprovado em 22/10/2026. Diferenças conhecidas: Ghoul
  (+1 pixel) e Chess; a troca de quadro (trava dos 3 buffers) segue em
  observação. Conjuntos anteriores aprovados: Passo 33 + player v14
  (21/10/2026) e Passo 31 + player v13: Checkers, H.E.R.O., Seaquest, River
  Raid, Pitfall, Decathlon, Pac-Man, Boxing e Combat Tank AI.
- O `firmware.img` é só para o Mk.II; o Mk.III não é alterado (o patch fica
  dentro de `CONFIG_MK2`: o firmware do Mk.III compilado com ele é idêntico ao
  oficial). Ele é uma cópia modificada do firmware do
  [sd2snes](https://github.com/ludufre/sd2snes) (GPL versão 2); as mudanças e
  como recompilar estão em `firmware/`.
- O `.a26` pede a confirmação de "core experimental" da 2.17 na primeira vez.
- A detecção do FE segue o Stella (ver `firmware/LEIAME.md`). Os outros
  arquivos de 8 KB continuam como F8.
- O Superchip é implementado em F8SC e F6SC. O F4SC (32 KB) roda como F4 comum:
  a ROM do core é de 16 KB. Folga de timing do bitstream: +0,001 ns a 96 MHz.
- Limitações conhecidas e resultado na coleção: ver o `README.md` da raiz.
