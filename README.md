# STorm2600: Atari 2600 no SD2SNES (FPGA MK2)

Roda jogos de Atari 2600 no próprio Super Nintendo, usando o FPGA Spartan‑3 do
SD2SNES/FXPak (revisão MK2). O Atari é emulado em hardware dentro do FPGA do
cartão; o SNES só exibe a imagem e lê os controles.

Projetos de base:

- [ludufre/sd2snes](https://github.com/ludufre/sd2snes): firmware e base do FPGA do cartão.
- [MiSTer-devel/Atari2600_MiSTer](https://github.com/MiSTer-devel/Atari2600_MiSTer):
  referência de comportamento, usada como caixa‑preta. O TIA usado aqui foi escrito do zero para caber no Spartan‑3.

## Estado

| Item | Versão |
|---|---|
| Player SNES | v13 (`atari_snes.bin`, md5 `8735f54a…`) |
| Bitstream FPGA | Passo 31 (`fpga_atari.bit`, md5 `5bbcf7b2…`), versão `$0B` em `$2027` |
| Firmware | Passo 25 (`firmware.img`, md5 `f9634a74…`, detecta o mapper FE) |
| Uso do FPGA | 5587/7168 LUTs, 3155/3584 slices (88%), 16/16 BRAM, folga +0,013 ns a 96 MHz |

Passo 31 + player v13 aprovado pelo autor no console. Testados e OK: Checkers, H.E.R.O., Seaquest, River Raid, Pitfall, Decathlon, Pac‑Man, Boxing e Combat Tank AI.
Histórico de testes no console: Passo 23 (Pitfall, River Raid, Pac‑Man, Enduro,
Frostbite e Boxing corretos), Passos 24/25 (Decathlon original abre), Passo 26
(Crackpots e Decathlon sem os pixels da bola fora do lugar).

### Em teste: Passo 33, TIA a partir do hardware do chip

Branch [`passo33`](../../tree/passo33), pré‑release `v0.9-p33`. Ainda não foi
testado no console; a `main` e a pasta `sdcard/` continuam no Passo 31 até a
aprovação.

- **Objetos do TIA refeitos como no chip original** (P0, P1, M0, M1 e bola):
  cada objeto tem o seu contador polinomial de 6 bits com relógio de duas fases,
  decodificações de START e HMOVE por pulsos extras com a trava "more‑motion",
  em vez de um contador binário reconstruído a partir do comportamento de
  emuladores. As regras vêm das *Atari 2600 TIA Hardware Notes* de Andrew
  Towers (tiradas dos esquemáticos do chip), dos esquemáticos do TIA e do
  *Stella Programmer's Guide*. Cada regra tem a fonte citada no código
  (`// FONTE:`); a especificação está em [`docs/tia_spec.md`](docs/tia_spec.md)
  e a proveniência em [`fpga/PROVENIENCIA_TIA.md`](fpga/PROVENIENCIA_TIA.md)
  (nenhum trecho literal de 6 tokens ou mais em comum com o TIA do MiSTer).
- **Saída de áudio I2S reescrita** a partir da especificação do barramento I2S;
  forma de onda idêntica à do Passo 31 nos 4 pinos (0 diferenças em 400.000
  clocks).
- **Color-2** passa a ser uma tabela nova de 128 cores; Color-1, Color-3 e
  Black/White não mudam.
- **ROMs de teste do TIA** em [`tools/tia_tests/`](tools/tia_tests/) (casos de
  canto de RESPx, RESMx, RESMP, NUSIZ e HMOVE), para rodar num Atari 2600 real
  e no core.
- Simulação, 516 ROMs de referência: 506 iguais ao Passo 31, 9 melhoram (Grand
  Prix, Night Grand Prix, Ram Defender, Robot Tank, Attack Of The Mighty Aliens,
  Ghoul, Aqua Hero, Mortal Kurling, Chess), nenhuma piora.
- Síntese: versão `$0C` em `$2027`, 5.487 LUTs, 3.110 slices (86%), 2.677 FFs,
  16/16 BRAM, folga +0,045 ns a 96 MHz (semente 17).

### O que mudou desde o Passo 26

- **Paletas** (Passos 27 e 28): uma paleta nova, mais fiel nos tons claros, e
  quatro paletas à escolha com o botão X: **Color-1** (padrão), **Color-2**,
  **Color-3** e **Black/White** (tons de cinza pela luminância do Atari).
  É questão de gosto; nenhuma é "a certa".
- **Opcodes não documentados do 6502** (Passo 29): LAX, SAX, DCP, ISB, SLO,
  RLA, SRE, RRA, ANC, ALR, ARR, SBX, os NOPs de 2 e 3 bytes etc. Antes rodavam
  como NOP de 1 byte e muitos homebrews e hacks travavam com a tela preta.
- **Leitura do TIA com "open bus"** (Passo 29): o TIA só dirige os bits 7 e 6;
  os bits 5..0 agora são o último valor do barramento, como no console (antes
  eram 0). Programas que leem um registrador do TIA no lugar de um valor
  imediato travavam.
- **Cor trocada no meio da linha** (Passo 31): o core lia as 4 cores de cada
  linha uma vez, no pixel 16; um jogo que trocava a cor depois disso perdia a
  cor nova (tabuleiro azul do Checkers, barras POWER do H.E.R.O. e OXYGEN do
  Seaquest). Agora os 4 índices de cor da linha são distribuídos conforme as
  cores aparecem. Linhas com mais de 4 cores continuam limitadas a 4.
- **Player v13**: X troca a paleta, Y troca o nível (Easy/Normal/Hard), e o
  nome escolhido aparece por ~2,5 s em verde na tela.

### Resultado na coleção (simulação)

Teste automático de uma coleção de 5.059 arquivos `.a26` (4.005 ROMs
distintas, 3.774 com mapper suportado), comparando a imagem do core em
simulação com a de um emulador de referência (ALE) nos quadros 10, 60 e 300,
sem apertar nenhum botão. "Igual" = 0 pixels diferentes nos 3 quadros;
"diferença pequena" = menos de 0,5% dos pixels.

| 3.774 ROMs suportadas | Passo 28b | Passo 29 | Passo 31 |
|---|---|---|---|
| Igual ao emulador | 1.001 | 1.311 | **cerca de 1.660 (44%, estimado)** |
| Diferença pequena | 828 | 1.001 | 854 |
| Defeito visual | 1.473 | 1.211 | 1.010 |
| Sem imagem | 263 | 89 | 88 |
| Emulador de referência falhou | 209 | 162 | 162 |

Cerca de 1.660 (44%, estimado: as ROMs que o Passo 31 não altera herdam o
resultado medido do Passo 29). A coluna do Passo 31 foi medida nas 1.089 ROMs que tinham linhas com a cor
errada no buffer e numa amostra de 500 das que já davam "igual" (nenhuma
piorou); as demais não têm nenhuma linha que o gravador do Passo 31 mude e
ficaram com o resultado do Passo 29. "Igual ao emulador" não quer dizer
jogável do começo ao fim: só os 3 quadros, sem controle, foram comparados.

## Como funciona (resumo)

1. O core do Atari roda no FPGA e grava cada quadro na PSRAM do cartão em
   triplo buffer: mapa de tiles BG1, lista de tiles 2bpp, 4 canais de cor por
   linha e janela horizontal.
2. O player no SNES, no IRQ da linha 232, trava o buffer mais recente e copia
   mapa e tiles para a VRAM por DMA.
3. HDMA indireto troca a paleta e a janela linha a linha, reproduzindo as cores
   do Atari.
4. Imagem 1:1 (160 colunas), 224 linhas centradas em modo overscan 239.

Detalhes em [docs/DESIGN.md](docs/DESIGN.md).

## Controles

| SNES | Atari |
|---|---|
| D‑pad | Joystick |
| B / A | Fire (tiro) |
| Start | RESET |
| Select | SELECT |
| R | Pausa |
| X | Próxima paleta: Color-1 → Color-2 → Color-3 → Black/White |
| Y | Nível: Easy → Normal → Hard (chaves de dificuldade do Atari) |
| L+R+Select+X | Volta ao menu |

Ao trocar a paleta ou o nível, o nome aparece por ~2,5 s em texto verde, sem
fundo, sobre a imagem. O jogo começa em Color-1 e Hard (as duas chaves de
dificuldade em A, como nos players anteriores); o primeiro Y passa para Easy
(as duas em B), depois Normal (esquerda B, direita A). A troca de paleta vale a
partir do quadro seguinte; durante a pausa o X é ignorado.

## Limitações conhecidas

- **Superchip** (RAM extra de 128 bytes no cartucho): não implementada; os 16
  blocos de RAM do FPGA estão em uso. Na coleção testada, 114 arquivos (106
  ROMs distintas) usam Superchip.
- **Mappers**: suportados 2K, 4K, F8, F6, F4 e FE. Os demais (E0, E7, FA/12K,
  64K, CV, UA, 3F, Supercharger e tamanhos fora do padrão) não.
- **Imagem PAL cortada**: o SNES mostra 224 linhas; jogos PAL têm 228 a 250, e
  as linhas que sobram ficam de fora.
- **Mais de 4 cores numa mesma linha**: o SNES recebe 4 cores por linha; a
  quinta em diante sai com uma das 4. Afeta sobretudo demos de cor e poucos
  jogos.
- **Jogos que divergem com o tempo**: em parte das ROMs a imagem bate no começo
  e se afasta do emulador depois de alguns segundos. Uma parte disso é o estado
  da RAM ao ligar (no console ele é aleatório, não é defeito); o resto não tem
  causa medida.
- **Aqua Hero** e **Bobby Is Going Home** ainda aparecem com defeito no console.
- **Quadro repetido**: o Atari roda a 59,92 Hz e o SNES a 60,10 Hz; um quadro
  se repete a cada ~5,5 s.

## Estrutura

```
fpga/    fontes do core (Verilog), testbenches e script que gera o projeto ISE
player/  player SNES v13 (65816, ca65) e os testes dele
tools/   scripts de comparação e medição contra o emulador (ALE)
firmware/ mudanças no firmware do sd2snes para o modo Atari (patch)
sdcard/  arquivos prontos para o cartão (bitstream, player e firmware)
docs/    design, layout do buffer, descrição do player, pendências e notas
```

Cada pasta tem um LEIAME próprio (`tools/README.txt` no caso das ferramentas).

## Origem do código

- O Verilog em `fpga/` foi escrito para este projeto (GPL-2.0-or-later), com
  uma exceção: `fpga/a26_i2s.v` tem cerca de 15 linhas (o clocking do DAC)
  copiadas do `verilog/sd2snes_base/dac.v` do sd2snes (Maximilian Rehkopf e
  colaboradores, GPL-2.0), creditadas no cabeçalho do arquivo, que por isso é
  GPL-2.0-only. Nada do MiSTer é copiado.
- O projeto ISE é gerado por `fpga/make_atari_shell.py` a partir de uma árvore
  intacta do [sd2snes](https://github.com/ludufre/sd2snes) (GPL-2.0): o `main.v`,
  o `.ucf` e o `.xise` gerados derivam dos originais e não são versionados.
- O [Atari2600_MiSTer](https://github.com/MiSTer-devel/Atari2600_MiSTer) é só
  referência de comportamento (por exemplo, a numeração dos mappers).
- As ferramentas em `tools/` usam o [ALE](https://github.com/Farama-Foundation/Arcade-Learning-Environment)
  (núcleo do Stella) como referência; ele é instalado à parte com `pip`.
- `fpga/tb_m6507_func.v` roda o teste funcional do 6502 de
  [Klaus Dormann](https://github.com/Klaus2m5/6502_65C02_functional_tests)
  (GPL-3.0), que não é distribuído aqui.
- O `sdcard/sd2snes/firmware.img` é o firmware do sd2snes (GPL versão 2) no
  commit `1b5d9d79`, compilado com as mudanças de [`firmware/`](firmware/): o
  patch e os quatro arquivos modificados, com os cabeçalhos originais.
- O `sdcard/sd2snes/fpga_atari.bit` contém, além do core deste repositório, o
  restante do FPGA do sd2snes (`verilog/sd2snes_base` do mesmo commit).
- O player (`sdcard/sd2snes/atari_snes.bin`) é montado a partir de `player/`,
  escrito do zero; o binário reproduz byte a byte (ver `player/LEIAME.md`).
- O bitstream é gerado a partir de `fpga/` e do sd2snes no commit `1b5d9d79`;
  o passo a passo (ISE 14.7, `make`, `utils/rle`, semente 13) está em
  [`fpga/LEIAME.md`](fpga/LEIAME.md).
- Fonte correspondente (GPL): a fonte completa do `firmware.img` e do
  `fpga_atari.bit` é o commit `1b5d9d79` de
  [ludufre/sd2snes](https://github.com/ludufre/sd2snes) mais as pastas
  [`firmware/`](firmware/) e [`fpga/`](fpga/) deste repositório.

## Aviso

Este projeto é distribuído **sem nenhuma garantia** (ver a [LICENSE](LICENSE)).
Use por sua conta e risco.

- O `firmware.img` é só para o **sd2snes Mk.II**. Ele regrava o firmware do
  cartão, não só o modo Atari. Antes de instalar, guarde o `/sd2snes/firmware.img`
  que está no cartão. O firmware anterior deste projeto (md5
  `8b1ee64bd9cbc2c24517d902b3fdf788`) sai com
  `git show 54b223e:sdcard/sd2snes/firmware.img > firmware.img`.
- Para voltar atrás, grave o firmware guardado como `/sd2snes/firmware.img` e
  ligue o console. Se o cartão não iniciar, o bootloader do sd2snes, que não é
  regravado, continua rodando a cada partida: ele lê o `/sd2snes/firmware.img` e
  regrava o flash quando a versão do arquivo é diferente da gravada e o CRC
  confere. Basta pôr um `firmware.img` válido (o guardado) no cartão e ligar.
  Detalhes em [`sdcard/LEIAME.md`](sdcard/LEIAME.md).
- Projeto independente, não afiliado à Atari nem aos autores do sd2snes e do
  MiSTer. Não inclui ROMs.

## Instalação no cartão

Só para o sd2snes **Mk.II**.

1. **Guarde uma cópia da pasta `/sd2snes` do cartão**, ou pelo menos do
   `/sd2snes/firmware.img` (ver Aviso acima).
2. Baixe a release [v1.11.2-br-v2.16.4 do ludufre/sd2snes](https://github.com/ludufre/sd2snes/releases/tag/v1.11.2-br-v2.16.4)
   (`sd2snes_firmware_v1.11.2-br-2.16.4.zip`) e copie a pasta `sd2snes` dela
   para a raiz do cartão.
3. Baixe da página de Releases deste projeto o `sd2snes-atari-files.zip` e
   extraia na raiz do cartão (ele já traz a pasta `sd2snes/`), ou copie os 3
   arquivos de [`sdcard/sd2snes/`](sdcard/sd2snes/) — `fpga_atari.bit`,
   `atari_snes.bin` e `firmware.img` — para a pasta `sd2snes` do cartão,
   substituindo o `firmware.img`.
4. Se quiser, confira os md5 (`sdcard/MD5SUMS`):
   `fpga_atari.bit` `5bbcf7b2be8815e326de021119af63bf`,
   `atari_snes.bin` `8735f54a9edb3e8da8b32d25855a6c96`,
   `firmware.img` `f9634a74371d24489c0727ded05604b3`.
5. Ponha as ROMs `.a26` em qualquer pasta do cartão e ligue o console. Na
   primeira partida o bootloader grava o `firmware.img`.

Testado apenas com o firmware do Passo 25 (feito do commit `1b5d9d79` do
ludufre/sd2snes) junto com a release v1.11.2-br-v2.16.4. Com a base 2.17 não
foi testado. Como voltar atrás está em [`sdcard/LEIAME.md`](sdcard/LEIAME.md).
ROMs de Atari não são distribuídas com este projeto.

## Autoria

Copyright (C) 2026 AndinhoNFS.

O projeto foi concebido, dirigido e testado no console por AndinhoNFS. Grande
parte do código (o Verilog de `fpga/`, o player de `player/`, as ferramentas de
`tools/` e as mudanças de `firmware/`) foi escrita com assistência do Claude, da Anthropic, a partir
das especificações e dos resultados de teste dele; os commits feitos assim
levam a linha `Co-Authored-By: Claude`. As partes derivadas do sd2snes mantêm
os autores e a licença originais.

## Licença

GPL-2.0, a mesma do sd2snes. Veja [LICENSE](LICENSE).
