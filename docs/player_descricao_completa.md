# Como o nosso player funciona e como foi criado (estado em 13/10/2026)

## 1. Visão geral: três camadas
1. **Firmware do sd2snes (cópia patchada em ~/projetos/atari_fw).** Carrega a ROM do Atari, carrega o bit do FPGA e informa o tipo de cartucho (mapper) ao player pelos bytes $FFF0/$FFF1 da ROM do player (magic $A2). Hoje decide o mapper só pelo tamanho do arquivo (8 KB vira F8): por isso o Decathlon original (FE) não roda.
2. **Core no FPGA Spartan-3 XC3S400 (~/projetos/atari_core).** Escrito do zero em Verilog: CPU 6507, TIA, RIOT, mappers. Roda a 96 MHz, monta cada quadro do Atari e o grava na PSRAM do cartucho. Também expõe uma janela de registradores em $2020-$202F para o SNES.
3. **Player (65816, ca65, este chat).** É a "ROM" do SNES: 32 KB, LoROM. Mostra na tela do SNES o quadro que o core deixou na PSRAM, lê o controle e escreve os botões nos registradores do core. Não emula nada do Atari.

Objetivo do projeto: usar o mínimo possível do FPGA e o esquema de controle do sd2snes. Por isso o player faz o que o SNES já faz bem (PPU, DMA, HDMA, joypad) e o FPGA só faz o que o SNES não consegue.

## 2. Por que é assim: o problema do SNES
- O PPU do SNES só aceita escrita na VRAM em force blank ou VBlank. A janela fora da imagem é de uns 38 linhas por quadro (cerca de 6 KB a 2,68 MB/s de DMA, 8 clocks mestres por byte, 1.364 clocks por linha).
- Um quadro Atari de 160 x 224 em tiles 2bpp ocupa 8,96 KB sem compressão, sem contar o mapa; antes de 1:1 e do dicionário, o esticamento 5 para 8 tinha 12 KB por quadro, o que não cabia sem cortar a imagem.
- O Atari troca cores no meio da tela, e o SNES só tem 4 cores por linha com HDMA: por isso cada linha tem uma tabela de 4 cores.
- O PPU não escala fundos por pixel; esticar na horizontal só é possível no FPGA.

## 3. Como o quadro viaja do core ao SNES
- Três buffers de 32 KB na PSRAM, em $380000/$388000/$390000, vistos pelo SNES em $70:8000, $71:8000 e $72:8000. Triple buffering: o core nunca grava no buffer que o SNES está lendo.
- Registrador de leitura R0 (bits 1:0) = número N do buffer completo mais recente. Registrador de escrita 7 ($2027): bit 7 = trava válida, bits 1:0 = buffer travado. O core escolhe o buffer em que vai gravar só na primeira linha do quadro seguinte, nunca N e nunca o travado. Isso eliminou as rajadas de glitch.
- Layout de cada buffer:
  - +$0000 cabeçalho, palavra 0 = N, número de tiles distintos (0 a 512).
  - +$0010 mapa do BG1: 28 linhas x 32 colunas x 2 bytes (1.792 B), número do tile nos bits 9:0.
  - +$0800 lista de tiles distintos, 16 bytes cada (2bpp, 8x8).
  - +$4000 + k*$400 tabelas de cor (k = COLUBK, COLUPF, COLUP0, COLUP1): 225 entradas de 4 bytes [k, k, BGR555 baixo, alto]. A entrada 224 é preta.
  - +$5000 janela: 225 entradas de 2 bytes [esquerda, direita]; entrada 224 = 0,255.
- Dicionário de tiles: o FPGA deduplica os tiles 8x8 do quadro (hash CRC-16 escolhe o candidato e os 16 bytes são comparados com a cópia em BRAM), e o SNES copia só os N tiles distintos mais o mapa. Medido em 1.020 quadros de 6 jogos: máximo de 85 a 90 tiles no 1:1. A DMA fica em 2 a 3 KB por quadro, bem abaixo da janela de 5 a 6 KB.
- 1:1: cada pixel do Atari é uma coluna do SNES. A imagem usa as colunas 48 a 207 (tiles 6 a 25 do mapa); o resto do mapa usa o tile 0 e a janela de cor pinta de preto o que fica fora de [48, 207] (56 nas linhas com barra de HMOVE).
- Enquadramento vertical: o core captura a partir de uma linha absoluta contada do VSYNC (YS0 = 34, a mesma do ALE e do Stella) mais um deslocamento sinalizado do registrador 6. O player escreve 0 nesse registrador.
- Cor por pixel (Passo 23): o core lê as 4 cores da linha uma vez, no pixel 16. Para pixels cuja cor final difere da cor do seu índice mas coincide com outra das 4 cores guardadas, usa o índice dessa cor. Resolve jogos que trocam COLUPF ou COLUP1 no meio da linha (logo da Activision, Boxing).

## 4. O que o player faz, quadro a quadro (arquivo atari_snes7.s)
- O SNES roda em modo overscan de 239 linhas ($2133 = $04). A imagem tem 224 linhas, com 8 linhas pretas em cima e 7 embaixo; essas pretas vêm do HDMA (entrada 224 das tabelas de cor). O OSSC corta o preto.
- Dois IRQs por quadro:
  - **Fase 0, IRQ em V=232:** force blank. Amostra R0 uma vez, grava a trava em $2027 ($80 | N) e usa o banco $70+N como origem do DMA e do HDMA. Define o scroll vertical do BG1 como -(VOFF+1) e faz duas DMAs para a VRAM: o mapa (1.792 bytes de $8010 para $1800) e os N tiles (N x 16 bytes de $8800 para $0000, N lido do cabeçalho; N = 0 pula; N é limitado a 512).
  - **Fase 1, IRQ em V=0:** liga o display, espera o fim da leitura automática do joypad, trata os botões, escreve SWCHA, SWCHB, fire e o registrador 3 no core.
- HDMA indireto, banco de dados = o buffer travado: canais 1 a 4 em modo 3 escrevem as 4 cores da linha em $2121/$2122, e o canal 5 em modo 1 escreve os limites da janela de cor em $2126/$2127. As tabelas de ponteiros ficam na WRAM ($7E:2000 mais $20 por canal), são montadas na reinicialização (BuildAll) e têm dois segmentos de 112 linhas para a imagem, com os segmentos pretos de 8 e 7 linhas.
- $2130 = $40 faz o SNES pintar de preto fora da janela de cor; é assim que saem as barras laterais.

## 5. Controles e registradores
- Pad 1: direcional = joystick (tabela SwchaLut), B ou A = fire, Start = RESET, Select = SELECT, R = pausa, L+R+Select+X = volta ao menu (escreve $81 em $2A00; o firmware reseta o console).
- Escrita (SNES para o core): 0 SWCHA, 1 SWCHB, 2 fire, 3 {run, mapper bits 3:1, pausa bit 4}, 4 INPT, 5 limpa diagnósticos, 6 deslocamento da primeira linha, 7 trava.
- Leitura: $2027 = versão do core (hoje $06), $202D = quadros descartados (satura em 255), $202E/$202F = N do último quadro.
- Mapper: o player lê o byte $FFF0 (se $FFF1 = $A2), faz mapper*2 | 1 e escreve no registrador 3. Valores até 7 cabem.
- Áudio: no reset o S-DSP está mudo e isso cala o áudio do cartucho; o player (SpcUnmute) sobe um programa de 8 bytes ao SPC700 pelo protocolo da ROM de boot ($2140-$2143) que escreve FLG ($6C) = $20 no DSP. Se a ROM de boot não responder, desiste sem travar.

## 6. Como foi construído
- **Divisão de trabalho.** O Code (Claude Code, no WSL) faz o FPGA e o firmware, mede e grava relatórios em arquivos; este chat escreve o player em ca65, testa no emulador e guia o usuário na instalação. O usuário testa no hardware (SNES, sd2snes Mk.II, OSSC e TV de tubo) e fecha o ciclo.
- **Ferramentas do player.** ca65/ld65 com lorom.cfg, script fix_snes_checksum.py, um emulador 65816 próprio em Python (emu65816.py) com testes por versão (test3*.py, test4.py, test5.py, test6.py, test7.py) que simulam a PSRAM de 3 bancos, os registradores do core e o joypad, e verificam as tabelas HDMA, a trava, as DMAs, os controles e o reset.
- **Armadilhas já pagas.** ca65 não acompanha o tamanho de A/X através de jsr/rts (`.a8`/`.a16` precisam ser restaurados); o emulador não tinha o opcode `lda [dp]` (acrescentado); os símbolos precisam ser copiados para o arquivo que o harness lê.
- **Regras de trabalho.** Os originais nunca mudam (clone ~/projetos/sd2snes, HEAD 1b5d9d79). Arquivos novos. Backup antes de gravar no cartão (G: = /mnt/g/sd2snes). Instalação um comando por vez, com cópia e conferência de md5.

## 7. Histórico resumido
- **v3 (várias letras, até v3x):** primeiro player estável, a 30 Hz, com a imagem de 160 de 256 colunas e controles de enquadramento. Fallback antigo: v3t (md5 e1bcce6b…).
- **v4:** HDMA indireto, tabelas de ponteiros, cores por linha, vista de topo ou base, ajustes de posição.
- **v5:** esticamento 5 para 8 no FPGA (256 colunas), triple buffering e trava, enquadramento do Stella no core; mostrava só ~184 linhas visíveis (DMA de 12 KB), com preto no topo.
- **v6:** tile dictionary (Passo 21b), modo de 239 linhas, 224 linhas centradas, ajuste fino escondido (L+Select).
- **v7:** 8 linhas pretas em cima e 7 embaixo; ajustes removidos. Com o bit do Passo 22 (1:1, 160 colunas) acabou a irregularidade de largura dos sprites.
- **Core, em paralelo:** RIOT/timer com 262 linhas (59,92 Hz), enquadramento por linha absoluta, trava de buffer, dicionário, 1:1, regra de cor por pixel (23), atraso de PF e GRP e mapper FE (24).

## 8. Limitações e pendências conhecidas
- O core faz 59,92 Hz e o SNES 60,10 Hz: um quadro repetido a cada ~5,5 s (genlock ainda não feito).
- O firmware escolhe o mapper só pelo tamanho; o Decathlon original (FE) não roda até o firmware passar mapper 5. O hack em F6 roda.
- O clock de 96 MHz fecha com folga de só 0,024 ns, e o caminho do TIA para o gravador de vídeo está no limite; cada alteração de TIA custa varredura de sementes.
- Só cores NTSC (paleta PAL e detecção automática ficariam para depois).
- Imagem de 160 colunas fica estreita na TV; alternativas (512 colunas com 3x) foram medidas e descartadas por DMA e por BRAM.
- A morte por colisão do H.E.R.O. foi explicada por simulação, mas ainda precisa de confirmação no hardware com o bit do Passo 24.
