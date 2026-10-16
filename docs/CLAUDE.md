# Atari 2600 no sd2snes Mk.II (XC3S400, Spartan-3, ISE 14.7)

Objetivo: rodar Atari 2600 no SNES via sd2snes Mk.II usando o mínimo do FPGA.
Core escrito do zero (sem copiar o core do fork nem do MiSTer): m6507, riot6532,
tia, tia_audio, a26_core, a26_vidwr, a26_tdict, a26_mem, a26_regs, a26_top, a26_i2s.

## Regras
- NUNCA editar sd2snes (clone git original). Só ler.
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
Build (na VM CentOS, sd2snes_atari (na VM de build)): source /opt/Xilinx/14.7/ISE_DS/settings64.sh; make mk2
VM vê a mesma pasta em <pasta compartilhada com a VM>

## Números medidos
- Shell original (HEAD 1b5d9d79): 5753 LUTs, 16/16 BRAM, timing de 96 MHz fecha por 0.013 ns.
- Core Atari isolado (XST): 2319 LUTs, 1 BRAM. CPU m6507 = 1257 LUTs (candidato a reescrita).
- Meta: shell podado + core ~4900 LUTs (~68%).
- Shell Atari (build de 2026-10-14, passo 26: só a bola, versão $07; semente 7, -bp desligado):
  4965 LUTs, 2897 slices, 2235 FFs, 16/16 BRAM, 96 MHz fecha por +0,065 ns (hold +0,433), 0 erros, DRC 0 erros.
  main.bit md5 65e255cc360ef326dc6843b76becc88f; fpga_atari.bit md5 7d19e73ad27b7a03e51e2fe0947b663a
  (120807 bytes). Na VM: fpga_atari_v14.bit, main_v14.bit, sweep15/ (17 -0,168; 10 -0,226; 6 -0,517; 7 +0,065).
  As falhas da semente 17 eram da lógica base do sd2snes (SNES_ADDRr -> r2100_bright, MCU_DINr).
  O writer B (alocação das cores) deu -2,614 (17) e -1,536 ns (10), sweep14: caminho pix_src (u_tia) ->
  fb_wdata (vid), 11,946 ns em 9 níveis. core -> vid NÃO é relaxado no ucf.extra: toda lógica nova entre
  as saídas do TIA e os registradores do vid tem de caber em 1 clock de 96 MHz.
- Shell Atari do passo 24 (build de 2026-10-13: atraso de escrita de PF e de GRP, mapper FE; semente 17, -bp desligado):
  5003 LUTs (69%), 2875 slices (80%), 2260 FFs, 16/16 BRAM, o clock de 96 MHz fecha por +0,024 ns,
  0 erros (map, par, DRC do bitgen). main.bit md5 8c96f945c0c50d2401c6d67940c35ab8;
  fpga_atari.bit md5 473215f082acd657de7f586d61e5d214 (121293 bytes). Na VM: fpga_atari_v13.bit, main_v13.bit.
  Sementes do passo 24 (sweep13.out na VM): 10 (-0,071), 6 (-0,781), 7 (-0,452), 8 (-0,016), 9 (-0,322),
  11 (-0,314), 12 (-0,510), 13 (-0,095), 14 (-0,661), 15 (-0,252), 16 (-0,328), 17 (+0,024): 12 sementes.
  O caminho que falha continua o do passo 23, pix_src/pix_col (u_tia) -> fb_wdata (vid), 9 níveis
  (trce da semente 16: sweep13/t16/t16.twr); nada do passo 24 aparece entre os piores.
  ATENÇÃO, XST: um sinal precisa estar declarado ANTES do primeiro uso (o iverilog aceita depois).
  Passo 23 (bak_v12/fpga_atari_v12.bit, sem os atrasos e sem FE): semente 10, +0,034 ns, 4982 LUTs,
  2889 slices, 2205 FFs; main.bit md5 22effaaeb650d582bc3c7275268e3ba7;
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
(utils/rle compilado em utils/ do sd2snes (na VM de build) na VM).
O gerador make_atari_shell.py grava no .xise: semente de placement 17 (PLACER_SEED, map/par -t)
e -bp desligado ("Map Slice Logic into Unused Block RAMs" = false); o ucf.extra tem as
exceções multiciclo TS_a26_slow, TS_a26_vid, TS_a26_riot e TS_a26_rom.
- ROM em block RAM (a26_mem.v): após cada reset do SNES o carregador copia 16 KB de 0x300000
  (PSRAM) para o BRAM; o core só roda com run & loaded (reg 11 de leitura, bit 4). Com a leitura ao vivo
  pelo slot da PSRAM, o hardware mostrava misses contínuos (causa não medida). F4 (32 KB) faz alias: só 16 KB cabem.
  O rom_ack sai 16 clocks após o rom_rd de propósito (ACK_DLY): é o que valida o TS_a26_rom.
- A margem é de 0,024 ns e não sobra BRAM: qualquer mudança em fonte exige nova varredura de sementes.
- Frame buffer: TRÊS buffers de 32 KB em PSRAM $380000, $388000, $390000 ($70:8000, $71:8000,
  $72:8000 no SNES); fb_waddr = {buffer[1:0], offset[13:0]} em palavras. Por buffer:
  cabeçalho em +$0000 (palavra 0 = nº de tiles distintos, resto 0); mapa de 28 x 32 entradas
  de 16 bits em +$0010 (nº do tile nos bits 9:0); lista dos tiles distintos em +$0800, 16 bytes
  cada, até 512; tabelas de HDMA por linha em BGR555 (ROM de 128 cores em a26_vidwr.v, cópia
  em a26_bgr555.hex): canal k em +$4000 + k*$400, 4 bytes por linha (k, k, cor), entrada 224
  preta; janela em +$5000, 2 bytes por linha (esquerda 48, ou 56 com a barra do HMOVE; direita
  207), entrada 224 = 0, 255. Resumo em LAYOUT_BUFFER.txt (aqui e em atari_deploy).
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
  nº de tiles do último quadro, versão (reg 7) = 6 (5 no passo 23, 4 no 22, 3 no 21b).
  Medido com a largura 1:1 e a regra de cor (passo 23): no máximo 90 tiles distintos por quadro
  em seis jogos (106 no arranque do Enduro); atari_compare/out/tiles/report.txt.
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
  e player v7 iguais; só o conteúdo dos tiles muda. Versão (reg 7) = 5 naquele passo.
  Medido (1.020 quadros, seis jogos, parado e jogando): pixels com cor errada 9520 / 2307 / 9520
  (Enduro / Boxing / Frostbite, parado; 9520 / 2132 / 9520 jogando) -> 0; nenhum pixel certo
  virou errado; N máximo 63->64 e 89->90 (Enduro), 73->75 e 76->76 (Boxing), 78->77 e 76->75
  (Frostbite), os outros iguais; 0 descartes. Relatório: atari_compare/out/passo23.txt.
  O arco-íris da esquerda (começa na coluna 20 no core e no ALE) NÃO foi mexido: espera a
  referência da coluna 13.
- Passo 24 (Diagnóstico 3, atari_compare/out/diag3.txt e passo24.txt), três mudanças, só no core:
  (1) tia.v, PF0/PF1/PF2: a escrita que cai no clock h só vale no primeiro clock múltiplo de 4 que
      seja >= h + 3 (início de uma célula de 4 pixels), como no ALE e no MiSTer. Um pendente POR
      registrador (pfw_pend/pfw_skip/pfw_v0..2): escritas em ciclos consecutivos não se atropelam.
      Corrige o par de pixels do H.E.R.O. (linhas 59/98, colunas 142..143) e a lacuna da barra de
      oxigênio do Seaquest (colunas 76..79).
  (2) tia.v, GRP0/GRP1: valem um clock de cor depois (gw_pend/gw_v0/gw_v1); as cópias de VDEL
      (dgrp0/dgrp1/denabl) são tiradas nesse mesmo momento.
  (3) a26_core.v, mapper 5 = FE (Activision, 8 KB): o ciclo seguinte a um acesso a $01FE traz no
      barramento o byte alto do destino do JSR / do retorno do RTS; D5 = 1 seleciona os primeiros
      4 KB, D5 = 0 os segundos; parte dos primeiros 4 KB (fe_arm, fe_bus). Igual ao MiSTer.
      O firmware do passo 25 passa o mapper 5 (ver abaixo); o player v7 o repassa sem mudança.
  Versão (reg 7) = 6. Formato do buffer, tabelas e registradores iguais.
  Testes novos: tb_tia.v (atraso de PF nas quatro fases de h % 4, atraso de GRP; falham no tia.v
  do passo 23) e tb_a26_top.v (run_fe). O tb_tia antigo passou sem espaçar escritas.
  Medido contra o ALE (8 jogos, parado e tiro+direita, 85 quadros): 1004 pixels corrigidos, 0
  pixels certos viraram errados; H.E.R.O. 340 + 170 -> 0; barra do Seaquest 20 -> 0; os outros
  seis jogos não mudam em nenhum pixel. 1.020 quadros de cor: saída idêntica à do passo 23.
  Pitfall x ALE: os 13.384 pixels NÃO são defeito: o ALE aperta o joystick para cima 1 quadro
  logo depois do RESET (ação de início do jogo); com isso no testbench (+joy0=68 +joy1=69
  +joyv=239 em sim/tb_d3.v) dá 0 pixels nos 85 quadros.
  Decathlon x ALE não serve de referência: o ALE para num opcode ilegal ($92) e fica com RAM e
  tela congeladas; no core o original (mapper 5) e a conversão F6 ficam com a RAM igual.
  Não modelado e medido no Decathlon: RESBL 9 clocks depois de HMOVE na mesma linha sai 1 pixel
  à esquerda do ALE (HMOVE é aplicado de uma vez). Bits 5..0 das leituras do TIA continuam 0.
  (Errata do Diagnóstico 4: o ALE só congelava por causa do alias pitfall.bin; com riverraid.bin
  ele roda o Decathlon original como FE e serve de referência. Ver out/diag4.txt.)
- Passo 25 (só firmware, atari_fw; relatório atari_compare/out/passo25.txt): a26_decide()
  em src/atari.c dá A26_BS_FE = 5 a um .a26 de 8 KB com uma das 5 assinaturas de
  CartDetector::isProbablyFE do Stella e sem "STA $1FF9"/"STA $FFF9" duas vezes (o "!f8" do Stella),
  depois das recusas 3F/UA e sem indício de Superchip; só com CONFIG_MK2 (A26_HAVE_FE em atari.h).
  O resto não muda. O byte vai como antes para $7FF0 do player (magic $A2 em $7FF1); o player v7
  escreve mapper*2|1 no reg 3. Coleção do usuário (5.317 .a26): 13 mudam de F8 para FE (Decathlon
  x3, Robot Tank e 3 hacks, Thwocker x2 — com cópias do cartão), todos FE também no Stella.
  Firmware novo: atari_fw/firmware_p25.img e atari_deploy/firmware_p25.img (md5 f9634a74…,
  113323 B); o anterior (8b1ee64b…) em atari_fw/backup_antes_do_25/. Build: make CONFIG=config-mk2
  CONFIG_CFGWARE=<arquivo de 11 bytes "placeholder"> (o fpga_mini.bit não existe na árvore; o
  cfgware.h do build anterior tem esse conteúdo). Só os 4 bytes de versão do cabeçalho mudam entre
  dois builds do mesmo fonte (hash do horário, genhdr sem -v).
  Console (usuário, 2026-10-14, com o bit do passo 24 e o player v7): o Decathlon original abre com o
  firmware_p25.img; sobram 2-3 pixels da bola (defeito A do Diagnóstico 4, item A do passo 26).
  Robot Tank e Thwocker passam a FE mas NÃO foram testados no console (só simulação).
  Repositório: firmware/mk2_atari.patch (5 arquivos contra 1b5d9d79) e sdcard/sd2snes/firmware.img.
- Passo 26 (relatório atari_compare/out/passo26.txt), versão (reg 7) = 7:
  (A) tia.v, RESBL no HBLANK: posição 3 se hmove_blank (HMOVE já dado nesse HBLANK), senão 2. Crackpots e
      Decathlon com 0 pixels x ALE na bola; outros 9 jogos sem mudança. Teste novo em tb_tia.v.
  (B) a26_vidwr.v com alocação das 4 cores por linha (protótipo E do diagnóstico 4): 0 pixels de cor errada
      nos 11 jogos em simulação, mas não fecha o timing (ver acima). NÃO está no bit: guardado em
      proto_p26B/ (writer + tb_a26_vidwr.v com modelo da alocação e quadro 50 com cor nova no meio da linha).
      Para fechar: registrar o pixel do TIA no pix_stb e processar num strobe atrasado >= 13 clk (relaxado).
  Barras POWER (H.E.R.O.) e OXYGEN (Seaquest): no RTL a linha inteira tem o mesmo índice (sai cinza); no
  console a parte vermelha (gasta) aparece e encolhe, mas a cor da parte que resta não. O hardware grava
  índices que a simulação não grava; item aberto: ler a PSRAM no console.
  Console (usuário, 2026-10-14) com o bit 7d19e73a ($07): Crackpots e Decathlon OK (item A confirmado).
- Passo 27 (relatório atari_compare/out/passo27.txt), versão (reg 7) = 8: uma paleta nova, canal
  round(c*31/255). A paleta antiga (= snes/palette_ntsc.inc) desbotava os claros ($4E quase branco). Só trocar
  a ROM piorou o timing (-1,2 a -2,4 ns): a ROM entra no mux do fb_wdata. Solução: tbw = palavra de cor do
  próximo slot registrada um pixel antes. Bit: semente 13, +0,012 ns, md5 db232e03c9e9e91921511ff01b9c7efc
  (VM fpga_atari_v15.bit). Variante com a palavra inteira do slot pré-calculada em proto_p27_tbw2/ (passa nos
  testes; síntese interrompida, não usada no bit). Não testado no console.
- Passo 28 (relatório atari_compare/out/passo28.txt), versão (reg 7) = 9: 4 paletas. Escrita reg 8 ($2028)
  bits 1:0 = 0 Color-1 (padrão), 1 Color-2, 2 Color-3, 3 Black/White (os 8 cinzas de Color-1 por c[2:0]).
  a26_regs r_pal -> a26_vidwr pal_f, travado no f_start junto com yofs_r (troca no meio do quadro só vale no
  seguinte); função pal_bgr(pal_f, tb_c) só no registrador tbw (grupo a26_slow_vid, 125 ns). Tabelas em
  a26_pal4.hex (paleta p em 128*p + c); a26_bgr555.hex = Color-1. Nomes das paletas: só Color-1/2/3 e
  Black/White, sem nomes de origem no código, docs ou tela. Passo 28b: Color-2 $00 = $0000 (era #101010), igual
  ao apagamento. Bit 28b: semente 9, +0,114 ns, 5232 LUTs, 3005 slices, md5 3cead098fd77f98321fb0a34b06913c6
  (VM fpga_atari_v16b.bit; o do 28 = 6d3cf916..., fpga_atari_v16.bit). O player v7 não escreve $2028. Não testado no console.
- Passo 29 (relatório atari_compare/out/passo29.txt; teste da coleção em atari_compare/out/colecao/), versão 10 ($0A):
  m6507 com os opcodes não documentados (antes NOP de 1 byte; validado contra o ALE com ROM de teste:
  out/colecao/proto/illrom.py) e leitura do TIA com D5..D0 = último byte do barramento (a26_core last_bus;
  bus.a26). tb_a26_sys/top esperam INPT4 = $8C. Bit: semente 11, +0,021 ns, 5519 LUTs, 3136 slices (87%),
  md5 ff0b729d1dba3ef668935af413f321c5 (VM fpga_atari_v17.bit). Não testado no console.
  NÃO aplicado: RIOT um ciclo antes (out/colecao/proto/riot6532.v: 67/80 leituras = ALE, mas nenhum jogo mudou).
- Passo 31 (relatórios atari_compare/out/passo30_B.txt e passo31.txt), versão 11 ($0B): a26_vidwr com a alocação
  das 4 cores por linha (item B do Passo 26) num strobe atrasado: cx/cvis/csrc/ccol/cvb registrados no pix_stb,
  dsh = pix_stb atrasado DLY = 13 clk e vsh = VSYNC atrasado (SHREG_EXTRACT = "NO"; no ucf.extra, a26_fast, gerado
  pelo make_atari_shell.py). Cores da linha escritas na linha seguinte (clp). Corrige a cor trocada no meio da linha
  em linhas com até 4 cores: na coleção 349 ROMs a mais ficam OK (Checkers e H.E.R.O. OK; Seaquest sem erro do
  gravador). Bit: semente 13 (PLACER_SEED do script), +0,013 ns, 5587 LUTs, 3155 slices (88%), 2337 FFs,
  md5 5bbcf7b2be8815e326de021119af63bf (VM fpga_atari_v18.bit; feito em exp30a/, refeito em rep31/ a partir do
  make_atari_shell.py: igual menos os 5 bytes da hora no cabeçalho; tail -c +101 | md5sum = d713e40a...).
  Usado com o player v13 (atari_deploy/atari_snes13.bin, 8735f54a...: X paleta, Y nível).
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
  clocks = 16688 us = 59,92 Hz) nos seis jogos de atari_compare.
- ucf.extra cita por nome snes_a26/vid/fb_wr, vsync_d, pub_pend, dsh* e vsh*: esses registradores precisam
  continuar existindo em a26_vidwr.v. O que muda em a26_vidwr só muda no strobe atrasado dstb (exceção
  multiciclo); vsync, pub_pend e a trava só passam por poucas portas antes de um registrador.
- TIA: jogadores com NUSIZ 5 (duplo) e 7 (quádruplo) começam 1 pixel depois dos de largura
  normal; medido contra o ALE em atari_compare/out/nusiz/report.txt.
- Janela $2020: reg 3 = run (bit 0), mapper (bits 3:1), pausa (bit 4: segura o colour clock,
  sem reset); reg 6 = deslocamento vertical; reg 7 = trava (ver acima).
- a26_vidwr: até o Passo 29 amostrava as 4 cores da linha no pixel 16; desde o Passo 31 aloca os 4 índices
  conforme as cores chegam (ver Passo 31).
- Comparação com emulador: atari_compare (ALE x núcleo no Verilator). Com
  hs = hcount + 1 os sprites batem com o emulador; hs = hcount os deixa 1 px à esquerda.
- TIA: RESPx/RESMx/RESBL usam hs = hcount + 1 (o clock em que o strobe passa a valer);
  com hs = hcount - 2 os sprites saíam 3 pixels à esquerda do playfield no hardware.
- Diagnóstico na janela $2020: escrita no reg 5 zera rom_miss/contador/latência; leitura do
  reg 8 = ciclos de CPU com miss (deve ficar 0), reg 9 = latência máxima das leituras do
  carregador, em clocks de 96 MHz (a latência real do slot da PSRAM).
- O make mk2 pode refazer a síntese mesmo sem mudança (make -n mostra rm -f main.ngc);
  para só regerar o fpga_atari.bit, rodar ../../utils/rle main.bit fpga_atari.bit.
Fontes anteriores ao passo 20 em bak_v8/, ao passo 21b em bak_v9/, ao passo 22 em bak_v10/ (com o bit do 21b),
ao passo 23 em bak_v11/ (com o bit do 22), ao passo 26 em bak_v13/ (com o bit do 24), ao passo 24 em bak_v12/ (com o bit do 23) e em bak_v13_pre/ (os mesmos
fontes, sem o bit). bak_v12_pre/ = os fontes do passo 23 antes da síntese dele.
Depois: bak_v14/ = passo 26 (antes do 27), bak_v15/ = 27, bak_v16/ = 28, bak_v17/ = 28b, bak_v18/ = 29
(antes do 31), cada um com o bit correspondente e MD5SUMS.txt.
O bit do passo 23 foi testado em hardware pelo usuário (H.E.R.O., Seaquest, Decathlon: Diagnóstico 3).
O bit do passo 24 e o firmware do passo 25 foram usados no console pelo usuário em 2026-10-14: Decathlon
original abre (2-3 pixels da bola sobram); barras POWER (H.E.R.O.) e OXYGEN (Seaquest): o efeito da barra
existe (a parte vermelha, gasta, aparece e encolhe), mas a cor da parte que resta (amarela/branca) não aparece.
Pendente: player 65816 no SNES (para o layout com dicionário), firmware ARM (.a26, mapper, bitstream), validação com jogos
reais, opcodes não documentados.

## Build na VM por SSH
- Acesso: `ssh <VM de build> '<comando>'` (chave já configurada, sem senha).
- Rodar o build: ssh <VM de build> 'bash -lc "source /opt/Xilinx/14.7/ISE_DS/settings64.sh && cd sd2snes_atari (na VM de build) && make mk2 > build.log 2>&1; grep -n \"^ERROR\" build.log | head -30"'
- Trazer arquivos para a VM: copiar com scp para sd2snes_atari (na VM de build)/ (a_26_*.v, main.v, stubs).
- Só mexer em sd2snes_atari (na VM de build) na VM. Não tocar em sd2snes_base nem em outras pastas.
- O build leva 5 a 10 minutos: rodar em segundo plano e consultar o build.log.
