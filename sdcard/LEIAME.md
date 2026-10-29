# sdcard/: arquivos do cartão para o modo Atari

Esta pasta tem só os 3 arquivos que o modo Atari acrescenta ou substitui na pasta
`/sd2snes/` do cartão do sd2snes (Mk.II). O resto da pasta (menu, demais cores
do FPGA) vem da release do sd2snes (passo 1 da Instalação).

Estado: **Passo 37**, aprovado no console em 28/10/2026: bitstream do Passo 36 (versão `$0E`, Superchip F8SC e F6SC) e player v17, ambos inalterados, e o firmware do Passo 37, feito sobre a release oficial v1.11.2-br-v2.18.1 do ludufre/sd2snes (não a v2.18, que tem um defeito no menu de Configuração).

| Arquivo | Tamanho | md5 | O que é |
|---|---|---|---|
| `sd2snes/fpga_atari.bit` | 129888 | `d33d69b587c485e9435126053061b8a9` | bitstream do core do Atari (Passo 36: Superchip F8SC e F6SC, versão `$0E`; mantém a captura de 232 linhas do Passo 34 e o TIA do Passo 33) |
| `sd2snes/atari_snes.bin` | 32768 | `4074bd4c8861c1dd586a8799d16e412f` | player SNES v17 (232 linhas; X paleta, Y nível, R pausa com PAUSE na tela), já com o nome que o firmware abre |
| `sd2snes/firmware.img` | 122807 | `31da69608e230b9d38323ae556a5fcb0` | firmware do Mk.II com o modo Atari, a detecção do FE e a do Superchip, feito sobre a tag `v1.11.2-br-v2.18.1` (Passo 37); casa com o `menu.bin` da própria 2.18.1 |

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
- **Flash do Mk.II quase cheia**: com o nosso patch sobre a 2.18.1 sobram só
  **73 bytes** (o Mk.II tem 128 KB; o `.data` inicializado não pode passar de
  0x20000). Para caber, o detector do Atari foi enxugado só dentro de
  `CONFIG_MK2` (o resultado é o mesmo do Passo 36). Qualquer acréscimo ao
  firmware do Mk.II exige tirar outro tanto.
- Projeto independente, não afiliado à Atari nem aos autores do sd2snes e do
  MiSTer. Não inclui ROMs.

## Instalação

0. **Guarde uma cópia da pasta `/sd2snes` do cartão inteira.** O `firmware.img`
   daqui substitui o firmware do cartão, não só o modo Atari.
1. Baixe a release [v1.11.2-br-v2.18.1 do ludufre/sd2snes](https://github.com/ludufre/sd2snes/releases/tag/v1.11.2-br-v2.18.1)
   (`sd2snes_firmware_v1.11.2-br-2.18.1.zip`; **não** a v2.18) e copie a pasta `sd2snes` dela
   **inteira** para a raiz do cartão. Isso sobrescreve `menu.bin`, `m3nu.bin`,
   `igmenu.bin`, `onboarding.bin`, `welcome.fmv`, os `firmware.*`, os núcleos
   `fpga_*` e os players `gbc_snes.bin`, `nes_snes.bin` e `sms_snes.bin`, e
   acrescenta 18 arquivos novos: os módulos de cartão (`fileops.bin`,
   `rmdir.bin`, `nsfplay.bin`, `pcmplay.bin`, `memtest.bin`, `rtc7110.bin`;
   os dois primeiros são necessários ao gerenciador de arquivos do menu),
   `xc_soc.bin`, núcleos novos (`fpga_xc.*`, `fpga_dspx.bit` etc.) e a pasta
   `lang/` (japonês e chinês). Não toca `config.yml`, `lastgame.cfg`,
   `atari_snes.bin` nem `fpga_atari.bit`. Faça o passo 0 antes. Para voltar da
   2.18.1, restaure a cópia.
2. Copie os 3 arquivos desta pasta `sd2snes/` (`fpga_atari.bit`,
   `atari_snes.bin`, `firmware.img`) para a pasta `sd2snes` do cartão,
   substituindo o `firmware.img` da zip. Antes, se quiser, confira os md5:
   dentro de `sdcard/`, `md5sum -c MD5SUMS`.
3. Ponha as ROMs `.a26` em qualquer pasta do cartão (não são distribuídas com
   este projeto). Ligue o console: o bootloader grava o `firmware.img` na
   primeira partida, e a 2.18.1 pode mostrar o tour de boas-vindas.
4. Na primeira vez que abrir um `.a26`, o menu pede a confirmação de "core
   experimental"; marque "não avisar de novo" se não quiser vê-la outra vez.

**Testado** no console com o firmware do Passo 37 junto com o pacote oficial
v1.11.2-br-v2.18.1 inteiro: menu e Configuração da 2.18.1, `.a26` com o nosso
core, Superchip, FE e jogos de SNES. (Firmware e `menu.bin` têm de ser da mesma
versão: o firmware do Passo 25 com o menu da 2.16.4 mostrava as pastas como
"?10", "?G".) O firmware do Passo 36, sobre a 2.17, só serve com o `menu.bin`
da 2.17 (Release `v0.11-p36`).

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

- Passo 37 (firmware sobre a 2.18.1; bitstream do Passo 36 e player v17
  inalterados) aprovado pelo autor no console em 28/10/2026: o detector do
  Atari dá o mesmo resultado do Passo 36 nos 5.055 arquivos da coleção. Passo 36
  (bitstream do Passo 36 + player v17 + firmware sobre a 2.17) aprovado pelo autor no console em 23/10/2026: as duas ROMs de teste do
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
- O `.a26` pede a confirmação de "core experimental" na primeira vez.
- A detecção do FE segue o Stella (ver `firmware/LEIAME.md`). Os outros
  arquivos de 8 KB continuam como F8.
- O Superchip é implementado em F8SC e F6SC. O F4SC (32 KB) roda como F4 comum:
  a ROM do core é de 16 KB. Folga de timing do bitstream: +0,001 ns a 96 MHz.
- Limitações conhecidas e resultado na coleção: ver o `README.md` da raiz.
