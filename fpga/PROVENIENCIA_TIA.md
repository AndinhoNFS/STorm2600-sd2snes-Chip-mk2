# Proveniência do TIA próprio (Passo 33)

Registro das linhas de `tia_hc.v` e `tia_obj.v` cuja forma é imposta pelo hardware do chip original. As regras de
comportamento vêm de documentação pública (ver `docs/tia_spec.md`); cada regra implementada tem, no próprio código, um
comentário `FONTE:` ou `HW:`. Esta lista cobre só as ocorrências em que, ao comparar com o TIA VHDL do MiSTer (usado como
caixa-preta e lido apenas na comparação final), uma linha nossa ficou igual ou quase igual a uma linha de lá.

Critério: a coincidência é aceitável quando vem da função (o mesmo fato do chip escrito da forma mais direta) e não de escolhas
arbitrárias (nomes, ordem do código, comentários, estrutura de processos).

| # | Nosso arquivo:linha | Regra implementada | Fonte pública | Onde a coincidência foi notada | Por que outra forma seria inviável ou artificial |
|---|---|---|---|---|---|
| 1 | `tia_hc.v:50` (função `pnext`) | passo do contador polinomial de 6 bits: o novo bit da esquerda é o XNOR dos dois bits menos significativos, deslocamento à direita | Towers, "Polynomial Counters, what the heck is this?" e a tabela de estados de "Horizontal Sync Counter" | `Atari2600_MiSTer/rtl/TIA/TIA.vhd`, entidade `lfsr6` (a atribuição do deslocamento, em torno da linha 56) | o polinômio está gravado no silício; qualquer implementação que reproduza a tabela de 63 estados do Towers tem de fazer exatamente isso. Conferido: a regra gera a tabela inteira do Towers |
| 2 | `tia_obj.v:47` (função `pnext`) | idem, para os contadores de objeto | idem | idem | os contadores de posição dos objetos são o mesmo circuito do contador de HSync (Towers: "The TIA uses the same polynomial counter circuit for all of its horizontal counters") |
| 3 | `tia_hc.v:59-62` (`ST_RHB`, `ST_LRHB`, `ST_SHB`, `ST_ERR`) | estados decodificados do contador horizontal: 011100 (fim do HBLANK), 010111 (fim tardio), 010100 (início do HBLANK e volta a zero), 111111 (ilegal) | Towers, "Horizontal Sync Counter" (tabela de decodificações) | `TIA.vhd`, processo `h_decode` (casos `"011100"`, `"010111"`, `"010100"`) | os valores são os estados do polinômio nas contagens 16, 18 e 56 da tabela do Towers; não há outro valor para o mesmo evento |
| 4 | `tia_obj.v:80-83` (`d_main`, `d_close`, `d_med`, `d_far`) | estados de START dos objetos: 101101 (volta principal) e 111000, 101111, 111001 (cópias "close", "medium", "far") com os NUSIZ que os habilitam (001/011, 011/010/110, 100/110) | Towers, "Player 0 and Player 1 Horizontal Position Counters" (tabela) e "Re-trigger Trick" | `TIA.vhd`, entidades `player` e `missile` (a condição de `start`, linhas em torno de 276-301 e 377-411) | os estados e os conjuntos de NUSIZ são os da tabela do Towers e do Stella Programmer's Guide §4.C; a tabela de NUSIZ tem 8 valores definidos pelo hardware |
| 5 | `tia_obj.v:118` (`d_main` zera o contador, `111111` também) | o decode de volta faz o contador voltar a 000000; o estado ilegal também | Towers, "Polynomial Counters, what the heck is this?" ("the next decoder line is the 'wrap-around' value... self-reset to 000000") | `TIA.vhd`, `lfsr6` / `lfsr_rst` (reset em 101101 e 111111) | é a descrição textual das duas primeiras linhas de decodificação de todo contador do chip |

Linhas renumeradas em 2026-10-20 (Fase 3, etapa 3). Entradas novas desta etapa: nenhuma regra nova de forma imposta pelo chip; as
constantes e regras acrescentadas (START do player alinhado ao fim da contagem, atraso de REFPx, tempo do RESMP em player duplo e
quádruplo, parâmetros HM74 e HMVIS do HMOVE; HM74 = 1 por decisão de 2026-10-20: valor nominal no ciclo 74, contra a leitura literal "8 + valor" do Towers, que não é usada) vêm de medida (`// FONTE: medida, ...` no código) e não de forma do silício.
Ocorrências adicionais serão acrescentadas se a comparação textual final (Fase 3, item 5 do pedido) apontar trechos coincidentes.

Rodada d (2026-10-20): nenhuma regra nova de forma imposta pelo chip. `tia_obj.v`: parâmetro PUPH (fase do relógio de 4 CLK ao ligar, objeto nunca resetado) vem de medida (`FONTE: medida`, powerup.s); `tia_hc.v`: HM74 = 1 por decisão do responsável (valor nominal no ciclo 74), ver docs/tia_spec.md §5 e §11.

## Comparação textual final (2026-10-20, pedido do Passo 33, item 5)

Ferramenta: `atari_compare/out/passo33/textual/tokcmp.py` (tokens em minúsculas, sem comentários; duas visões: literal e normalizada, com todo
identificador trocado por ID e todo número por NUM e operadores Verilog/VHDL equivalentes unificados). Referência: VHDL do TIA do MiSTer
(`rtl/TIA/TIA.vhd`, `Common.vhd`, `NTSCLookups.vhd`, commit 59411dc) lido só para esta comparação.

- `tia_hc.v` e `tia_obj.v` x TIA do MiSTer, **visão literal, trechos de 6 tokens ou mais: nenhum**. Com 4 a 5 tokens só aparece sintaxe de linguagem
  (`clk ) begin if (`, `) begin if (`), sem conteúdo de hardware.
- Visão normalizada (12 tokens ou mais): 9 trechos, todos de forma genérica de linguagem, sem regra do chip: listas de atribuições de reset
  (`x <= 0; y <= 0; ...`, `tia_hc.v:89, 129, 133`, `tia_obj.v:108, 288`) e `if (a == K) x <= K; else ...` (`tia_hc.v:142-143`, `tia_obj.v:126, 262-263, 293-294`).
  Não há coincidência de nomes, de estados do polinômio nem de estrutura de processos além do que a linguagem impõe; nenhum trecho a reescrever.
- Os estados do polinômio, o passo XNOR e os decodes de START (linhas 1 a 5 da tabela acima) não aparecem como trecho comum nem na visão normalizada, porque
  os identificadores e a estrutura são outros; ficam registrados acima por prudência.

## `a26_i2s.v` (reescrito em 2026-10-20, GPL-2.0-or-later)

Escrito a partir da especificação do barramento I2S (Philips, 1986, rev. 1996) e das razões de relógio já usadas pela placa (MCLK = clkin/8, LRCK = MCLK/64,
SCLK = 32 x LRCK); não parte do `dac.v` do sd2snes. Prova de equivalência: `tb_a26_i2s_eq.v` roda o módulo novo e o do Passo 31
(`experimental/a26_i2s_p31_old.v`, GPL-2.0-only, só como referência do banco de ensaio) lado a lado: **0 diferenças em 400.000 clocks em todos os quatro
pinos, desde o primeiro clock**, com 1.563 bordas de LRCK e amostras trocadas em instantes arbitrários; `tb_a26_i2s.v` (autoverificável) também passa.
Comparação textual contra `sd2snes_base/dac.v` (`textual/i2s_vs_dac.txt`): sobra só o que a interface e a linguagem impõem.

| # | Nosso arquivo | Regra | Fonte pública | Coincidência notada | Por que outra forma seria inviável |
|---|---|---|---|---|---|
| 6 | `a26_i2s.v`, lista de portas (`clkin`, `sample`, `sdout`, `mclk_out`, `lrck_out`, `sclk_out`) | interface do módulo | pinagem da placa (`a26_top.v` as liga por nome) | `dac.v`, linhas 35-39 | os nomes são a interface já ligada em `a26_top.v` e na pinagem; trocá-los quebraria o projeto sem ganho |
| 7 | `a26_i2s.v`, `assign mclk_out = ~d_mclk[2]; lrck_out = d_lrck[2]; sclk_out = d_sclk[1]` | atrasos de 3, 3 e 2 clkin e MCLK invertido nos pinos | medida da temporização nos pinos do Passo 31 (a placa é ligada assim) | `dac.v`, linhas 95-97 | a forma de onda tem de ser idêntica à já medida; a expressão mais direta de "sinal atrasado de N clocks" é um registrador de deslocamento e um bit |
| 8 | `a26_i2s.v`, divisões `phase[2]`, `phase[3]`, `phase[8]` | MCLK, SCLK e LRCK a clkin/8, /16 e /256 | razões acima (I2S: SCK = 32 x WS para palavras de 16 bits em cada metade) | `dac.v`, mesmos bits do contador | os bits de um contador binário livre são a forma direta de dividir o relógio por potências de 2 |
