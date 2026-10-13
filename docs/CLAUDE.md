# Atari 2600 no sd2snes Mk.II (XC3S400, Spartan-3, ISE 14.7)

Objetivo: rodar Atari 2600 no SNES via sd2snes Mk.II usando o mínimo do FPGA.
Core escrito do zero (sem copiar o core do fork nem do MiSTer): m6507, riot6532,
tia, tia_audio, a26_core, a26_vidwr, a26_tdict, a26_mem, a26_regs, a26_top, a26_i2s.

## Regras
- NUNCA editar ~/projetos/sd2snes (clone git original). Só ler.
- Tudo novo vai em arquivos novos. Mostrar diff antes de aplicar mudanças no shell.
- Compilar do shell só em cópia limpa (sd2snes_pristine, feita com git archive).
- XST do ISE rejeita nomes que diferem só por maiúscula no mesmo módulo.
- Nada é considerado verificado até passar no iverilog.

## Testes (rodar tudo após qualquer mudança)
iverilog -g2005 -o tb_tia  tb_tia.v tia.v && vvp tb_tia
iverilog -g2005 -o tb_core tb_a26_core.v a26_core.v m6507.v riot6532.v tia.v tia_audio.v && vvp tb_core
iverilog -g2005 -o tb_vidwr tb_a26_vidwr.v a26_vidwr.v a26_tdict.v && vvp tb_vidwr
iverilog -g2005 -o tb_tdict tb_a26_tdict.v a26_tdict.v && vvp tb_tdict
iverilog -g2005 -o tb_mem tb_a26_mem.v a26_mem.v slot_model.v && vvp tb_mem
iverilog -g2005 -o tb_sys tb_a26_sys.v a26_regs.v a26_mem.v slot_model.v a26_core.v a26_vidwr.v a26_tdict.v m6507.v riot6532.v tia.v tia_audio.v && vvp tb_sys
iverilog -g2005 -o tb_top tb_a26_top.v a26_top.v a26_regs.v a26_mem.v slot_model.v a26_core.v a26_vidwr.v a26_tdict.v m6507.v riot6532.v tia.v tia_audio.v && vvp tb_top
iverilog -g2005 -o tb_i2s tb_a26_i2s.v a26_i2s.v && vvp tb_i2s
(m6507: tb_m6507_cycles.v e tb_m6507_func.v com func_test.hex; riot: tb_riot.v; áudio: tb_tia_audio.v)

## Shell
make_atari_shell.py gera verilog/sd2snes_atari/ dentro de uma cópia limpa do sd2snes
(troca dma->a26_top e dac->a26_i2s no main.v, stubs para sfxdma srtc rtc msu ctx bsx cheat,
Makefile, ucf.extra, .xise). Pasta pristine:
"<pasta-do-projeto>/Projeto_Atari2600/sd2snes_pristine"
Build (na VM CentOS, ~/pristine/verilog/sd2snes_atari): source /opt/Xilinx/14.7/ISE_DS/settings64.sh; make mk2
VM vê a mesma pasta em /mnt/hgfs/ProjetoAtari/Projeto_Atari2600

## Números medidos
- Shell original (HEAD 1b5d9d79): 5753 LUTs, 16/16 BRAM, timing de 96 MHz fecha por 0.013 ns.
- Core Atari isolado (XST): 2319 LUTs, 1 BRAM. CPU m6507 = 1257 LUTs (candidato a reescrita).
- Meta: shell podado + core ~4900 LUTs (~68%).
- Shell Atari (build de 2026-10-12, passo 23: cor trocada no meio da linha; semente 10, -bp desligado):
  4982 LUTs (69%), 2889 slices (80%), 2205 FFs, 16/16 BRAM, o clock de 96 MHz fecha por +0,034 ns,
  0 erros (map, par, DRC do bitgen). main.bit md5 22effaaeb650d582bc3c7275268e3ba7;
  fpga_atari.bit md5 5ba5631572bb6352c2239557e13ff12d (120604 bytes). Na VM: fpga_atari_v12.bit, main_v12.bit.
  Sementes do passo 23 (sweep12.out e sweep12b.out na VM): 6 (-1,294), 7 (-1,208), 8 (-0,368),
  9 (-0,586), 10 (+0,034). O caminho que falha é o novo, pix_col (u_tia) -> comparadores ->
  fb_wdata (vid), 9 níveis de lógica a 96 MHz (trce da semente 8: sweep12/t8/t8.twr na VM).
  Passo 22 (bak_v11/fpga_atari_v11.bit, largura 1:1, sem a regra de cor): semente 6, +0,031 ns,
  4982 LUTs, 2885 slices, 2208 FFs; main.bit md5 6b1d83b88c55f9f91c06d90532eef87d;
  fpga_atari.bit md5 c4e5d085512ad4f7a4b35b9ee6310823.
  Passo 21b (bak_v10/fpga_atari_v10.bit, esticado 5 -> 8): 4969 LUTs, semente 6, +0,010 ns,
  fpga_atari.bit md5 806c5e44ad4e94c38af70efb55654ed1.
  ATENÇÃO: desde o passo 21b o ISE chama a restrição de 96 MHz de TS_snes_a26_clkin1 (antes TS_CLK21);
  é a mesma PERIOD de 96,04 MHz derivada do DCM, só o nome da rede mudou. O script de varredura
  (sweep11.sh na VM) julga por "All constraints were met", não pelo nome.
  Sementes do passo 21b: 7 (-0,346), 8 (-0,237), 2 (-0,702), 3 (-0,722), 4 (-0,802), 5 (-0,562),
  6 (+0,010). A semente 1 já fez o map do ISE abortar (FATAL_ERROR:Place).
- Passo 20 (fpga_atari_v9.bit, sem dicionário): 4355 LUTs, 10/16 BRAM, semente 7, +0,026 ns.

## Estado
Simulação: tudo passa. Build do shell no ISE fecha timing e gera main.bit e fpga_atari.bit
(utils/rle compilado em ~/pristine/utils na VM).
O gerador make_atari_shell.py grava no .xise: semente de placement 10 (PLACER_SEED, map/par -t)
e -bp desligado ("Map Slice Logic into Unused Block RAMs" = false); o ucf.extra tem as
exceções multiciclo TS_a26_slow, TS_a26_vid, TS_a26_riot e TS_a26_rom.
- ROM em block RAM (a26_mem.v): após cada reset do SNES o carregador copia 16 KB de 0x300000
  (PSRAM) para o BRAM; o core só roda com run & loaded (reg 11 de leitura, bit 4). Com a leitura ao vivo
  pelo slot da PSRAM, o hardware mostrava misses contínuos (causa não medida). F4 (32 KB) faz alias: só 16 KB cabem.
  O rom_ack sai 16 clocks após o rom_rd de propósito (ACK_DLY): é o que valida o TS_a26_rom.
- A margem é de 0,034 ns e não sobra BRAM: qualquer mudança em fonte exige nova varredura de sementes.
- Frame buffer: TRÊS buffers de 32 KB em PSRAM $380000, $388000, $390000 ($70:8000, $71:8000,
  $72:8000 no SNES); fb_waddr = {buffer[1:0], offset[13:0]} em palavras. Por buffer:
  cabeçalho em +$0000 (palavra 0 = nº de tiles distintos, resto 0); mapa de 28 x 32 entradas
  de 16 bits em +$0010 (nº do tile nos bits 9:0); lista dos tiles distintos em +$0800, 16 bytes
  cada, até 512; tabelas de HDMA por linha em BGR555 (ROM de 128 cores em a26_vidwr.v, cópia
  em a26_bgr555.hex): canal k em +$4000 + k*$400, 4 bytes por linha (k, k, cor), entrada 224
  preta; janela em +$5000, 2 bytes por linha (esquerda 48, ou 56 com a barra do HMOVE; direita
  207), entrada 224 = 0, 255. Resumo em LAYOUT_BUFFER.txt (aqui e em ~/projetos/atari_deploy).
- Dicionário de tiles (a26_tdict.v, instância snes_a26/dict, entre a26_vidwr e a26_mem; roda a
  96 MHz, FORA dos grupos multiciclo do ucf.extra: toda saída de BRAM passa por mais um
  registrador). O a26_vidwr continua emitindo as palavras de tile ({buffer, 0, r, c, linha});
  o dicionário as guarda num buffer de 2 linhas de tiles (1 BRAM) e, ao fim de cada linha de
  tiles (ev_row), procura cada tile: CRC-16 das 8 palavras -> tabela de hash de 1024 entradas
  (1 BRAM) -> comparação EXATA palavra a palavra com a cópia do dicionário (4 BRAM, 512
  tiles). Tile 0 = zero sempre; números por ordem de primeira aparição. Fim de quadro (ev_end):
  última linha parcial, mapa zerado nas linhas sem captura, cabeçalho, limpeza do hash, espera
  o a26_mem esvaziar (wr_idle) e só então eng_ack; o a26_vidwr publica no pixel seguinte.
  Mais de 512 tiles (ou linha de tiles atropelada): eng_ovf, quadro descartado (R0/R1 não
  mudam, reg 13 de leitura conta). Se a janela do quadro seguinte começa com o anterior ainda
  pendente, esse quadro seguinte é pulado inteiro (também conta no reg 13).
  As palavras do dicionário só entram na FIFO do a26_mem com ela abaixo da metade (fifo_low);
  as palavras de tabela do a26_vidwr têm prioridade. Leitura: reg 13 = descartes, reg 14/15 =
  nº de tiles do último quadro, versão (reg 7) = 5 (4 no passo 22, 3 no 21b).
  Medido com a largura 1:1 e a regra de cor (passo 23): no máximo 90 tiles distintos por quadro
  em seis jogos (106 no arranque do Enduro); ~/projetos/atari_compare/out/tiles/report.txt.
- Largura 1:1 (passo 22): 1 pixel do Atari = 1 coluna do SNES, sem esticar. Os 160 pixels ficam
  nas colunas 48..207: tiles 6..25 do mapa de 32 colunas (pixels 8(c-6)..8(c-6)+7); os tiles
  0..5 e 26..31 são gravados como zero pelo a26_vidwr (12 palavras zero por linha), então o
  a26_tdict não mudou e o mapa traz 0 nessas colunas. Janela: esquerda 48 (56 na linha com a
  barra do HMOVE), direita 207; entrada 224 = 0, 255. O formato do buffer é o do passo 21b
  (o player v7, atari_snes7.bin md5 c89e847b..., não muda).
- Cor trocada no meio da linha (passo 23, regra do item 5 de atari_compare/out/cor_meio_da_linha.txt):
  as 4 cores da linha continuam amostradas uma vez, no pixel 16. Do pixel 17 em diante o
  a26_vidwr compara a cor final de cada pixel visível (pix_col, 7 bits, sai do tia.v pelo
  a26_core; antes não era ligada) com as 4 guardadas (cl; clv = cl já é desta linha): se a cor
  guardada da fonte do pixel não é mais a final, o pixel recebe o MENOR índice cuja cor guardada
  é igual à final; se nenhuma é, fica com a fonte. Corrige a metade direita do playfield na
  faixa do logo do Enduro e do Frostbite (colunas 124..139, linhas 196..202 e 192..198 do
  buffer) e o placar da direita do Boxing (linhas 5..11). Limites: troca para uma cor fora das
  4 guardadas e qualquer troca antes do pixel 17 continuam perdidas. Formato do buffer, tabelas
  e player v7 iguais; só o conteúdo dos tiles muda. Versão (reg 7) = 5.
  Medido (1.020 quadros, seis jogos, parado e jogando): pixels com cor errada 9520 / 2307 / 9520
  (Enduro / Boxing / Frostbite, parado; 9520 / 2132 / 9520 jogando) -> 0; nenhum pixel certo
  virou errado; N máximo 63->64 e 89->90 (Enduro), 73->75 e 76->76 (Boxing), 78->77 e 76->75
  (Frostbite), os outros iguais; 0 descartes. Relatório: atari_compare/out/passo23.txt.
  O arco-íris da esquerda (começa na coluna 20 no core e no ALE) NÃO foi mexido: espera a
  referência da coluna 13.
- Três buffers com trava: R0 = bits 1:0 = N (buffer com o quadro completo mais recente), os
  demais bits 0. Reg 7 de escrita = trava (bit 7 válida, bits 1:0 = buffer). Ao fim do quadro
  N = W; o novo W só é escolhido na primeira linha gravada do quadro seguinte: diferente de N
  e do travado, de preferência diferente do N anterior. Os bits miss/FIFO/ROM carregada, que
  eram de R0, estão no reg 11 de leitura; reg 12 = leitura da trava.
- Enquadramento por linha absoluta: a janela são 224 linhas a partir da linha YS = YS0 + reg 6,
  contadas do fim do VSYNC (linha 0 = a linha em que o VSYNC desce, como no Stella; o VSYNC é
  olhado só nos pixels 0 e 159). YS0 = 34 (parâmetro de a26_vidwr): a linha 0 do buffer é a
  linha 0 da tela do ALE em River Raid, Enduro, Pitfall, Boxing e Frostbite; no Pac-Man o ALE
  usa YStart 33 para o md5 conhecido e fica 1 linha diferente. Linhas com VBLANK ligado saem
  pretas (tiles 0, cores $0000, janela 48..207). R2 = linhas gravadas (224 = janela completa).
  Reg 6 = deslocamento com sinal, 8 bits, limitado a -16..+47, lido no reg 10; vale a partir
  do quadro seguinte e volta a 0 no reset do SNES.
- Escritas do a26_vidwr por linha: 20 palavras de tile (pixels 7, 15 .. 159) e 12 palavras
  zero (pixels 5, 13 .. 93), todas para o dicionário; 9 de tabela (pixels 19, 35 .. 147) e,
  nas linhas 0..8, uma palavra da entrada 224 (pixel 155). FIFO de 16 em a26_mem; não estoura e nenhum quadro é descartado com o slot
  da PSRAM 6x (nem 8x) mais lento: tb_a26_sys com -Ptb_a26_sys.SLOT_LAT=90 e, com jogos, o
  sim/tb_full.v do atari_compare (a26_top inteiro na razão real de clock).
- RIOT: o primeiro decremento do timer vem no ciclo seguinte à escrita (modelo do Stella).
  Antes vinha um intervalo depois e os jogos geravam 264 linhas; agora 262 (59736 colour
  clocks = 16688 us = 59,92 Hz) nos seis jogos de ~/projetos/atari_compare.
- ucf.extra cita por nome snes_a26/vid/fb_wr, vsync_d e pub_pend: esses registradores precisam
  continuar existindo em a26_vidwr.v. O que muda em a26_vidwr só muda em pix_stb (exceção
  multiciclo); vsync, pub_pend e a trava só passam por poucas portas antes de um registrador.
- TIA: jogadores com NUSIZ 5 (duplo) e 7 (quádruplo) começam 1 pixel depois dos de largura
  normal; medido contra o ALE em ~/projetos/atari_compare/out/nusiz/report.txt.
- Janela $2020: reg 3 = run (bit 0), mapper (bits 3:1), pausa (bit 4: segura o colour clock,
  sem reset); reg 6 = deslocamento vertical; reg 7 = trava (ver acima).
- a26_vidwr amostra as 4 cores da linha no pixel 16 (jogos gravam COLUPx até o pixel 7).
- Comparação com emulador: ~/projetos/atari_compare (ALE x núcleo no Verilator). Com
  hs = hcount + 1 os sprites batem com o emulador; hs = hcount os deixa 1 px à esquerda.
- TIA: RESPx/RESMx/RESBL usam hs = hcount + 1 (o clock em que o strobe passa a valer);
  com hs = hcount - 2 os sprites saíam 3 pixels à esquerda do playfield no hardware.
- Diagnóstico na janela $2020: escrita no reg 5 zera rom_miss/contador/latência; leitura do
  reg 8 = ciclos de CPU com miss (deve ficar 0), reg 9 = latência máxima das leituras do
  carregador, em clocks de 96 MHz (a latência real do slot da PSRAM).
- O make mk2 pode refazer a síntese mesmo sem mudança (make -n mostra rm -f main.ngc);
  para só regerar o fpga_atari.bit, rodar ../../utils/rle main.bit fpga_atari.bit.
Fontes anteriores ao passo 20 em bak_v8/, ao passo 21b em bak_v9/, ao passo 22 em bak_v10/ (com o bit do 21b),
ao passo 23 em bak_v11/ (com o bit do 22). bak_v12_pre/ = os fontes do passo 23 como estavam antes da síntese
(iguais aos atuais, salvo PLACER_SEED 6 -> 10 no make_atari_shell.py e estas notas).
O bit do passo 23 não foi testado em hardware aqui.
Pendente: player 65816 no SNES (para o layout com dicionário), firmware ARM (.a26, mapper, bitstream), validação com jogos
reais, opcodes não documentados.

## Build na VM por SSH
- Acesso: `ssh storm-ise147 '<comando>'` (chave já configurada, sem senha).
- Rodar o build: ssh storm-ise147 'bash -lc "source /opt/Xilinx/14.7/ISE_DS/settings64.sh && cd ~/pristine/verilog/sd2snes_atari && make mk2 > build.log 2>&1; grep -n \"^ERROR\" build.log | head -30"'
- Trazer arquivos para a VM: copiar com scp para ~/pristine/verilog/sd2snes_atari/ (a_26_*.v, main.v, stubs).
- Só mexer em ~/pristine/verilog/sd2snes_atari na VM. Não tocar em sd2snes_base nem em outras pastas.
- O build leva 5 a 10 minutos: rodar em segundo plano e consultar o build.log.
