# Especificação do TIA (objetos e contador horizontal) — Passo 33, Fase 2

Esta especificação descreve o funcionamento do chip TIA original a partir de documentação pública, para a
reescrita da parte de objetos do `tia.v` (arquivos `tia_hc.v` e `tia_obj.v`). Não foi consultado nem copiado
código de outros projetos. Onde as fontes divergem ou omitem, o item está marcado **[ABERTO]** e será resolvido
por medida na Fase 4 (testes `pos/` e `re/` do Passo 32c, o ALE e o TIA do MiSTer usado como caixa-preta).

## 0. Fontes e convenção de citação

| Sigla | Fonte | Observação |
|---|---|---|
| **Towers** | Andrew Towers, "Atari 2600 TIA Hardware Notes", v1.0, 6/mar/2003 | texto completo (espelho atarihq.com); a cópia do Retro Isle termina no meio da seção "CPU Clock to Player Pixel Table" |
| **Stella PG** | "Stella Programmer's Guide", Atari, 1979 (PDF do Retro Isle) | páginas impressas 16 a 28 (TIA); a versão atualizada de 1988 não abriu (ver relatório) |
| **TIA Manual** | "TIA (Television Interface Adapter) Manual", Atari (PDF do Retro Isle, 38 págs.) | mesma descrição detalhada do Stella PG, "Detail Description" §1 a §11 |
| **Esquemático** | TIA-1A, 5 folhas, scans de 2002 (AtariAge) | usados só para os [ABERTO]; a folha 1 (contador de HSync, divisor por 3, registradores de movimento, playfield) foi lida em 400 dpi |
| **Diagramas de temporização** | páginas 31 a 36 do PDF do Manual do TIA ("TIA Timing Characteristics": OSC/φ2/lum, escrita, leitura, COMP SYN e ready, RSYNC e HBLANK e ready) | já estão no PDF baixado; as páginas equivalentes do atariarchives.org não foram necessárias (a página do site pede verificação humana) |

Comentário de código: `// FONTE: Towers, "<título da seção>"`, `// FONTE: Stella PG §<n>`,
`// FONTE: esquemático TIA, folha <n>`, `// FONTE: medida, <arquivo do relatório>`.
Linha imposta pelo hardware: `// HW: forma imposta pelo chip original: <motivo>`.

Notação: CLK = relógio de cor (3,58 MHz NTSC); uma linha = 228 CLK; um ciclo de CPU = 3 CLK; "contagem" = um passo do
contador a 1/4 de CLK (4 CLK).

## 1. Relógios

- **Relógio de cor** de 3,58 MHz. Perto de cada contador há um gerador de duas fases que divide o CLK por 4 com dois
  flip-flops e gera, por portas AND, dois pulsos independentes de 1 CLK de largura em 4: **H@1** e **H@2**, defasados de 2 CLK.
  FONTE: Towers, "Polynomial Counters, what the heck is this?".
- Os contadores avançam em dois passos (uma contagem = H@1 depois H@2, ao todo 4 CLK). As decodificações são amostradas
  na contagem seguinte, dentro de 4 CLK. FONTE: Towers, "Horizontal Sync Counter".
- O CPU roda a 1/3 do CLK (um ciclo = 3 CLK). O TIA conta a 1/4 do CLK; por isso um RESPx pode cair em qualquer fase
  entre os dois relógios. FONTE: Towers, "Re-trigger Trick".
- **Nosso projeto:** o TIA recebe `cc_ce` (um pulso por CLK de cor, a cada ~27 ciclos de 96 MHz) e `clk` (96 MHz). As duas
  fases H@1/H@2 viram dois sinais derivados de um contador de fase de 2 bits que conta em `cc_ce`; `pix_stb` continua sendo
  1 pulso por pixel, na mesma posição de hoje.  [ABERTO] a fase exata de H@1/H@2 em relação ao nosso `hcount` (hoje
  `hcount` conta CLK de 0 a 227): medir com a tabela da §7 de `pos/mkpos.py`.

## 2. Contador horizontal (HSync)

FONTE: Towers, "Horizontal Sync Counter"; TIA Manual, Detail Description §2.A ("contador de hardware... total de 228;
blank decodificado como 68 contagens e sync e burst como 16 contagens", ou seja, em CLK).

- Contador polinomial de **6 bits** (registrador de deslocamento com uma porta XNOR na realimentação). Período: **57
  contagens** = 228 CLK. O estado `111111` é ilegal e força reset para `000000` (o chip pode ligar nele).
- **Polinômio (transcrito da tabela do Towers):** a cada contagem o registrador desloca uma posição para a direita e o novo
  bit mais à esquerda é o **XNOR dos dois bits menos significativos**. Sequência a partir de `000000`: `100000`, `110000`,
  `111000`, `111100`, `111110`, `011111`, `101111`, `110111`, ... (63 estados válidos). Conferido: a regra reproduz os 63
  estados da tabela do Towers (verificação em `atari_compare/out/passo33.txt`).
- **Reset de fim de linha:** o estado `010100` (contagem 56) decodifica SHB; o contador volta a `000000` 4 CLK depois (a contagem
  57 é a 0). Estados 57 a 62 (`101010` ... `000001`) não ocorrem em linha normal.
- **Estados decodificados** (contagem; CLK desde o início da linha):

  | Sinal | Estado | Contagem | CLK | Efeito |
  |---|---|---|---|---|
  | SHS | `111100` | 4 | 16 | liga o HSYNC |
  | RHS | `110111` | 8 | 32 | desliga o HSYNC (atrasado 4 CLK) |
  | RCB | `001111` | 12 | 48 | fim do burst de cor |
  | RHB | `011100` | 16 | 64 | libera o HBLANK (travado após 4 CLK) |
  | LRHB | `010111` | 18 | 72 | libera o HBLANK **tardio**, usado no lugar de RHB quando o latch [HMOVE] está ligado |
  | CNT | `101100` | 36 | 144 | centro da tela: inicia a cópia/reflexo do playfield |
  | SHB | `010100` | 56 | 224 | liga o HBLANK e zera o contador |

- Os pixels de playfield começam em RHB (CLK 64), mas o primeiro pixel visível só aparece em CLK 68 por causa do clock
  de saída; nossa convenção: pixel visível 0 = `hcount` 68. FONTE: Towers, "Horizontal Sync Counter".
- **HBLANK com HMOVE:** o latch [HMOVE] adia o fim do HBLANK em exatamente 8 CLK (2 contagens) usando LRHB. O latch é
  limpo quando o contador de HSync dá a volta. FONTE: Towers, "Playing with the HMOVE registers".
- **RSYNC:** zera o relógio de duas fases do contador de HSync na borda de subida de H@1; um ciclo H@1–H@2 depois, o
  contador também vai a `000000` e liga o HBLANK (Towers). **Esquemático, folha 1 (TIA-1A, "Sync counter – playfield + motion
  registers", scan de 400 dpi, legível):** o gerador "DIVIDE BY THREE" (relógio φ0 do CPU, saída CLKφ) tem uma entrada de reset
  `RESφ0` ligada ao pad `RSYN` por uma porta; o contador de HSync tem as linhas `RSYNL`/`RSYND` vindas do mesmo pad e o par de
  flip-flops "F1" que gera HΦ1/HΦ2. Ou seja, RSYNC reinicia **tanto** o divisor por 3 do CPU **quanto** o relógio de duas fases e
  o contador de HSync. **[ABERTO]** a relação de fase exata entre HΦ1/HΦ2 e o divisor por 3 (precisa de rastreio porta a porta, não
  feito) e o atraso do reset; decidir por medida se algum jogo da coleção usa RSYNC. Nosso `tia.v` não implementa RSYNC.
- **WSYNC:** o CPU fica retido (RDY = 0) até o início da próxima linha. FONTE: Stella PG, "Microprocessor Synchronization"
  (TIA Manual §2.D; seção só localizada no sumário, o texto ainda não foi relido). Instante de liberação: manter o comportamento atual (`wsync` limpo em `hcount` 227 → 0), validado
  contra o ALE em todos os jogos. **[ABERTO]** a relação exata com a fase H@1/H@2.

## 3. Contadores de posição dos objetos (P0, P1, M0, M1, BL)

FONTE: Towers, "Player 0 and Player 1 Horizontal Position Counters", "Missile ... Position Counters", "Ball ... Counter";
Stella PG §4 ("Horizontal Position Counters", p. 20–21).

- **Um contador polinomial de 6 bits por objeto**, idêntico ao do HSync (mesmo polinômio), com período de **40 contagens =
  160 CLK** (de `000000` ao estado `101101`, contagem 39, de onde volta a `000000`). Estado `111111` = reset (ilegal).
- **Quando conta:** só recebe CLK durante a parte visível da linha (HBLANK desligado): exatamente 160 CLK por linha, exceto
  durante o HMOVE. Durante os outros 68 CLK fica parado na fase exata de 1/4 em que estava. O relógio dos objetos
  ([MOTCK]) é o CLK invertido (em oposição de fase). FONTE: Towers, "Player 0 and Player 1 Horizontal Position Counters".
  Consequência: um reset em qualquer pixel visível faz a cópia principal aparecer nesse mesmo pixel nas linhas seguintes.
- **Reset por RESPx / RESMx / RESBL:** zera o contador **e** o relógio de duas fases associado (4 CLK para zerar). FONTE: Stella
  PG §4.A ("Todos os contadores podem ser zerados a qualquer momento... Se o reset ocorrer no apagamento horizontal, o objeto
  aparece à esquerda"), Towers, "Re-triggering after exactly 18, 33, 66 or 162 cycles".
- **RESPx e RESMx NÃO geram sinal START**: a cópia principal só aparece depois que o contador completa a volta (160 CLK
  depois), isto é, **na linha seguinte**. **RESBL gera START** (a bola desenha imediatamente a cada reset). FONTE: Towers,
  "Player Position Counters" e "Ball Horizontal Position Counter". Confirma a medida do Passo 32c (re1b/re).
- **Atraso de início:** decodificar o START leva 4 CLK; travar mais 1 CLK: total 9 CLK após o RESPx. Com os 4 CLK do
  playfield, a posição visível fica **5 pixels à direita** do pixel do reset (o "5" mágico). Para os **players** há 1 CLK
  a mais no travamento do START (por isso a posição mais à esquerda de um RESP0 é o pixel 1, não o 0). Mísseis e bola
  usam as mesmas decodificações sem esse CLK extra. FONTE: Towers, "Player 0 and Player 1 Horizontal Position Counters" e
  "CPU Clock to Player Pixel Table".
- **Decodificações de START dos players** (estado do contador → contagem → CLK após o reset):

  | Cópia | Estado | Contagem | CLK | NUSIZ[2:0] que a habilita |
  |---|---|---|---|---|
  | próxima ("close") | `111000` | 3 | 12 | 001, 011 |
  | média ("medium") | `101111` | 7 | 28 | 010, 011, 110 |
  | distante ("far") | `111001` | 15 | 60 | 100, 110 |
  | principal ("main") | `101101` | 39 | 156 | sempre (e reseta o contador) |

  Os START das cópias passam por um bloco que exige um ciclo completo do relógio de duas fases: se o contador e o relógio
  forem zerados durante essa decodificação, o START é perdido ou atrasado até 3 CLK.
- **Mísseis:** mesmas decodificações e mesmo NUSIZ[2:0] que o player correspondente (mesmo número de cópias); ignoram as
  larguras de escala do player (uma só cópia nos modos de player esticado). FONTE: Towers, "Missile ... Position Counters";
  Stella PG §4.C–D.
- **Bola:** só a decodificação de volta (contagem 39); sem cópias. FONTE: Stella PG §4.B.
- **Tabela de validação CPU → pixel** (Towers, "CPU Clock to Player Pixel Table"): reset no ciclo de CPU 23 (CLK 69, pixel
  visível 1) coloca a cópia principal em 6, a "close" em 22, a "medium" em 38 e a "far" em 70; a cada ciclo de CPU a mais
  as posições avançam 3 pixels. Resets antes do fim do HBLANK zeram o contador mas ele só volta a contar quando o HBLANK
  termina: gráfico no pixel 1 do playfield. **[ABERTO]** a correspondência entre "ciclo de CPU do RESP" da tabela e o
  `hcount` da escrita no nosso core (o `tia.v` atual usa `hs = hcount + 1` e posição = `hs - 68 + 5`, que bate com o ALE em
  71 de 71 estrobos); resolver por medida com `pos/mkpos.py`.

## 4. Gráficos dos objetos

### Players (FONTE: Towers "Player 0 and Player 1 Graphics Scan Counters"; Stella PG §6.C)
- **Contador de varredura** de 3 bits (binário, "ripple"), **nunca resetado**: depois do START conta de 0 a 7. Só conta
  na parte visível (mesmo [MOTCK]); por isso um player que termina depois da borda direita continua no início da linha seguinte
  ("sprite wrapping"). Um HMOVE pode "engolir" o gráfico que dá a volta (§5).
- **Largura (NUSIZ[2:0]):** o relógio do contador de varredura é mascarado: 1 pulso a cada 1 CLK (normal), a cada 2
  (NUSIZ 101, duplo = 16 CLK) ou a cada 4 (NUSIZ 111, quádruplo = 32 CLK). O modo duplo usa as duas fases ORadas; o
  quádruplo usa H@2. O NUSIZ é lido a cada CLK de gráfico (pode ser trocado durante o desenho).
- **Reflexão (REFPx):** lido a cada pixel; inverte os bits do endereço de origem (D7→D0 ou D0→D7). Pode trocar durante o desenho.
- **Registradores:** GRPx tem dois registradores de 8 bits ("novo" e "velho"). Escrever GRP0 altera o "novo" de P0 e copia o
  "novo" de P1 para o "velho" de P1; escrever GRP1 altera o "novo" de P1 e copia o "novo" de P0 para o "velho" de P0 e o
  "novo" de ENABL para o "velho". Escrita imediata. VDELPx (lido a cada pixel) escolhe "novo" (0) ou "velho" (1).
  FONTE: Towers (texto acima); Stella PG §6.D.
- Primeiro pixel do player: +1 CLK em relação aos demais objetos (§3).

### Mísseis (FONTE: Stella PG §6.B; Towers "Notes on the Ball/Missile width enclockifier")
- Um bit de habilitação (ENAMx), desenhado só quando o START chega, com largura de **1, 2, 4 ou 8 CLK** por NUSIZ[5:4].
- Largura: a primeira metade do Enable vem de (1) um pulso de 1 CLK das duas fases se D4 e D5 = 0; (2) uma linha de 2 CLK
  em 4 se D4 = 1; (3) o próprio D5 (START dura 4 CLK) = 4 CLK; a segunda metade (cópia atrasada do START, 4 CLK) entra
  quando D4 e D5 = 1 (8 CLK).
- **RESMPx:** coloca o míssil sobre o player e desliga a saída serial do míssil enquanto o bit estiver em 1. FONTE: Stella PG
  §4.D. O reset do contador do míssil ocorre quando o contador de varredura do player está em `%100` (meio do desenho) **e**
  a cópia principal está sendo desenhada (latch [FSTOB], limpo quando o contador do player dá a volta e setado quando o START
  de uma cópia "close/medium/far" é decodificado). FONTE: Towers, "Missile ... Position Counters".

### Bola (FONTE: Stella PG §6.E; Towers "Ball Horizontal Position Counter")
- Largura 1, 2, 4 ou 8 CLK por CTRLPF[5:4], pelo mesmo arranjo de portas dos mísseis.
- **VDELBL:** escolhe "novo" (0) ou "velho" (1) valor de ENABL a cada CLK; escrever ENABL altera o "novo"; escrever GRP1 copia
  o "novo" para o "velho". Escrita e VDELBL com efeito imediato.
- RESBL gera START (a bola reinicia o desenho a cada reset; pode ser acionada várias vezes na mesma linha).

## 5. HMOVE

FONTE: Towers, "Playing with the HMOVE registers", "Graphics Scan Counters during HMOVE", "HMOVE during the visible
scanline"; Stella PG §5.

- **Valores HMxx:** 4 bits, +7 (esquerda) a −8 (direita), complemento de dois (Stella PG §5.A); só valem quando HMOVE é
  endereçado, e valem todos juntos. Os registradores podem ser zerados juntos por HMCLR.
- **Mecanismo (clock stuffing):** com o HMOVE dado logo após o início do HBLANK, o latch [HMOVE] adia o fim do HBLANK em 8 CLK
  (LRHB). Para mover menos de 8 pixels à direita, o TIA manda 0 a 15 pulsos de CLK extras para o contador de posição de cada
  objeto durante o HBLANK; cada pulso extra come 1/4 de contagem e move o objeto 1 pixel à esquerda.
- **Contador de movimento:** um contador binário de 4 bits **começa em 15 e decrementa a cada 4 CLK até 0** durante o
  HMOVE, ligado em paralelo a comparadores (XOR por bit) nos 5 registradores HMxx. No início do HMOVE, um latch por objeto
  marca "falta movimento à esquerda"; enquanto o comparador de um objeto não achar igualdade de **nenhum** dos 4 bits com
  o estado do contador, o latch envia a cada H@1 um CLK extra ("stuffed") ao objeto; ao achar igualdade, o latch é limpo.
  O bit D7 de HMxx é comparado invertido (por isso a faixa +7 a −8 vira uma contagem 0 a 15 de movimento para a esquerda).
- **Temporização:** 3 CLK (até 6) após o STA HMOVE para decodificar [SEC], mais 4 CLK para ligar os latches; a primeira
  comparação (contra 15) é amostrada 15 CLK após o início do STA HMOVE e a cada 4 CLK; o primeiro decremento ocorre no CLK 17 e
  a cada 4 CLK. A operação leva no máximo 4·16 = 64 CLK; recomendação do Stella PG: não alterar HMxx por pelo menos 24
  ciclos de CPU depois do HMOVE.
- **Escrita em HMxx durante o HMOVE** (truque do Cosmic Ark): se o contador ainda não chegou ao valor de HMxx, um valor
  maior (na contagem 0 a 15) vale normalmente; se já chegou, o valor novo não tem efeito; um valor que compartilhe pelo
  menos um bit com **todos** os estados restantes do contador impede a condição de parada: o objeto anda 15 pixels e o latch
  não é limpo, enviando um CLK extra a cada 4 CLK (em área visível ou não) até outro HMOVE; HMCLR não limpa esses latches.
- **HMOVE no ciclo 74 da linha — FECHADO em 2026-10-20 por decisão do responsável (valor nominal; HM74 = 1).** O Towers descreve ESTE caso diretamente (seção "Playing with the HMOVE
  registers", parágrafo que começa em "Also of note, the HMOVE latch used to extend the HBlank time is cleared when the HSync
  counter wraps around"). Texto exato do trecho decisivo: "(...) the CLK stuffing will still take place during the HBlank and the
  HSYNC latch will be set just before the counter wraps around. It will then be cleared again immediately (and therefore ignored)
  when the counter wraps, preventing the HMOVE comb effect. Since the extended HBlank is needed to move all objects right 8
  pixels, this has the limitation that objects can only be moved left, and the normal HMOVE numbering no longer applies. Instead
  the HMOVE value is interpreted as (8 + value) pixels to the left, ie: -8 = 0, -4 = 4, 0 = 8, 4 = 12, 7 = 15 (...) This means that
  all objects will be moved 8 pixels left unless you set their HMxx value to -8 for zero movement. I've recently found a post in
  the Stella mailing list archives that gave these results by exhaustive testing, posted by Brad Mott". O "(8 + valor)" NÃO foi
  deduzido por nós: é afirmação do Towers, que cita testes exaustivos (em hardware, de outra pessoa).
  Testemunhas medidas (ROMs hmove_m0, hmove_m1, hmove_bl, hmove_late = P0; `out/passo33/fase3/log_r2`): o ALE, o Stella atual e o
  TIA do MiSTer dão os TRÊS o mesmo resultado, o valor nominal (`value` pixels, 7 para HMxx = $70), e discordam do texto do Towers
  (15).
  DECISÃO (2026-10-20): vale o consenso das três testemunhas, confirmado pelo jogo Daring Do versus the Everfree Forest (com HM74 = 0
  a imagem difere da referência OK do P31 em 960 px; com o valor nominal, HM74 = 1, a diferença some: 0 px, rodada b). `tia_hc` passa a usar `HM74 = 1` como
  padrão: o HBLANK visto pelos contadores dos objetos é estendido em 8 CLK na linha seguinte, sem a barra visível. `HM74 = 0` (literal
  do Towers) fica no código só para reproduzir rodadas antigas da bancada.
  ERRO DE LEITURA NOSSO: tomei a frase do Towers ("8 + valor pixels para a esquerda") como regra absoluta e a coloquei como padrão,
  apesar de as três testemunhas e depois um jogo real discordarem. Não sabemos de qual referência a frase fala; [HIPOTESE] ela mede o
  deslocamento contra a posição sem HMOVE, enquanto o valor nominal das testemunhas já inclui o HBLANK estendido do HMOVE normal.
  Isso não foi verificado com o console. ROM de teste: `tools/tia_tests/rom/hmove_late.a26` (instante C = 74, última linha de teste).
- **Barra do HMOVE (comb):** o HBLANK estendido esconde os primeiros 8 pixels do playfield/objetos da linha.
- **Contador de varredura × HMOVE:** HMOVE de 8 pixels à direita (−8) não manda pulsos ao player; qualquer outro valor
  "engole" tantos pixels quanto o valor (0 a 15) do movimento; HMOVE com valor 0 consome todo o gráfico de player normal que
  deu a volta (8 CLK extras); player duplo precisa de 16 pulsos e quádruplo de 32 para ser engolido por inteiro.
- **HMOVE na parte visível da linha:** Towers considera que os pulsos extras "tapam" os pulsos normais, só movendo para a
  direita 1 pixel a cada 4 CLK; **[ABERTO]** (o texto diz "not sure how universal"): decidir por medida contra o ALE e o TIA
  do MiSTer em caixa-preta.

## 6. Playfield, prioridades e colisões

Manter o comportamento atual do nosso `tia.v` (validado), só documentar (pedido do Passo 33):
- Playfield: PF0/PF1/PF2 com 20 bits de 4 pixels cada, metade direita repetida ou refletida (CTRLPF[0]); escrita aplicada
  na próxima célula de 4 pixels (medida do Passo 24); modo placar (CTRLPF[1]).
- Prioridades (Stella PG §8.5): normal P0/M0 > P1/M1 > PF/BL > BK; com PFP (CTRLPF[2]): PF/BL > P0/M0 > P1/M1 > BK;
  mísseis têm a cor e a prioridade do player correspondente e a bola a do playfield. Modo placar: o playfield toma a cor do
  player 0 na metade esquerda e a do player 1 na direita.
- **[ABERTO] placar + prioridade juntos** e **placar sem prioridade (ordem do PF em relação a P1/M1/BL):** o Stella PG
  (§8.5.C) e o Towers não cobrem a combinação. As medidas do Passo 32c (`out/passo32c.txt`, itens D1 e D1b) mostram o TIA
  do MiSTer e o Stella atual com a regra "prioridade desliga o placar" e, sem prioridade, o PF por cima de P1/M1/bola; o ALE
  difere no caso placar + prioridade. Fica fora desta reescrita (continua como candidato C1/C1b do Passo 32c).
- Colisões: 15 travas CXxx, zeradas por CXCLR; mantidas como no `tia.v`. **[ABERTO]** se registram durante o VBLANK e a
  barra do HMOVE (Passo 32c, D9).

## 7. Casos de canto conhecidos e ROM de teste

| Caso | Fonte do comportamento | ROM de teste |
|---|---|---|
| RESPx no HBLANK (posição 3; gráfico no pixel 1 do playfield) | Towers "CPU Clock to Player Pixel Table" | `pos/pos_P0.a26` (e P1, M0, M1, BL) |
| RESPx no meio da linha: posição nova só na linha seguinte; um segundo RESP na mesma linha cancela a cópia principal | Towers "The Re-trigger Trick" | `pos/re1b_P0.a26`, `pos/re_P0.a26` |
| RESBL desenha imediatamente (START) | Towers "Ball Horizontal Position Counter" | **[ABERTO]** criar `pos/rebl.a26` |
| Cópias "close/medium/far" a cada RESP e re-disparo (18, 33, 66, 162 ciclos) | Towers "Re-triggering after exactly 18..." | **[ABERTO]** criar `pos/re_nusiz.a26` (NUSIZ 011 + RESP duplo) |
| HMOVE fora do início da linha e no ciclo 74 | Towers "Playing with the HMOVE registers" | `tools/tia_tests/rom/hmove_m0.a26` (M0), `hmove_m1`, `hmove_bl`, `hmove_late` (P0): o objeto é recolocado antes de CADA instante C = 4..74; o ciclo 74 é [ABERTO] (§5) |
| RESPx / RESBL dentro do HBLANK estendido do HMOVE (tabela de posições) | Passo 32c, itens 2.4 | `pos/pos_*_hm.a26` (ALE e nosso diferem na bola) |
| NUSIZ trocado no meio da linha | Towers "Graphics Scan Counters" (relido a cada CLK) | **[ABERTO]** criar `pos/nusiz_mid.a26` |
| Escrita em HMxx durante o HMOVE (Cosmic Ark) | Towers (texto) | **[ABERTO]** sem ROM de jogo; testar só se houver ROM da coleção que use |
| Jogos de referência | Robot Tank (RESP0/RESP1 por linha), Space Shuttle (RESP repetido), Pole Position, Outlaw (cowboys na borda), Crackpots, Decathlon (RESBL após HMOVE) | coleção |

## 8. Plano de mapeamento para o Verilog

| Bloco | Arquivo | Conteúdo |
|---|---|---|
| Contador horizontal | `tia_hc.v` | contador polinomial de 6 bits, fase H@1/H@2, decodificações da §2, `hcount` equivalente, HBLANK/HSYNC, `wsync` |
| Objetos | `tia_obj.v` | 5 contadores polinomiais (§3), START/cópias por NUSIZ, contador de varredura de 3 bits (players), largura de míssil/bola, RESMP, VDEL, HMOVE por pulsos extras (§5) |
| Playfield, prioridade, colisões, cor, interface de CPU | `tia.v` (inalterado) | como hoje; saída `pix_src`/`pix_col`, `pix_stb`, barra do HMOVE |

O `tia.v` do Passo 31 continua atrás de `` `ifdef TIA_P31 `` até o fim da validação.

## 9. Lista dos itens [ABERTO]

1. Fase H@1/H@2 e relação com `hcount` e com a fase de 3 CLK do CPU (§1, §2).
2. RSYNC (§2).
3. Relação "ciclo de CPU do RESP" × `hcount` da escrita (§3) — por medida, `pos/mkpos.py`.
4. Placar × prioridade, ordem do PF em modo placar (§6) — fora do escopo, ver Passo 32c.
5. Colisões em VBLANK/barra (§6).
6. HMOVE durante a área visível (§5) e HMOVE no ciclo 74 (parâmetro HM74, §5 e §10).
8. RESMPx com player duplo/quádruplo (§10, item 4).
7. Casos de canto sem ROM de teste ainda (§7).

## 10. Constantes e regras medidas na Fase 3 (todas com a testemunha que as confirma)

Referência: ALE (Stella antigo), Stella atual (commit 2c3d702) e TIA do MiSTer no GHDL como caixa-preta; ROMs em `tools/tia_tests`.
1. START → pixel: míssil e bola 3 CLK; **player: o START alcança o contador de varredura no FIM da contagem de 4 CLK em que subiu**
   (4 CLK quando nada interfere), não 4 CLK fixos. Um RESPx entre o START e o fim da contagem re-faseia o relógio de duas fases
   e o START espera o novo fim de contagem; um START que está no fim da contagem quando o reset cai ainda chega ao gráfico.
   Confirmado por ALE, Stella e MiSTer em `resp_double_n3`; em `resp_midline` e `res_p0_*_b` (strobe perto do fim da linha) o MiSTer
   difere do ALE e do Stella e o modelo novo acompanha os dois últimos. FONTE: Towers, "Player 0 and Player 1 Horizontal Position Counters" (START latch com o relógio
   de duas fases) + medida.
2. Player duplo / quádruplo: START com +1 CLK de atraso (ALE, Stella, MiSTer).
3. **REFPx chega à inversão de endereço 1 CLK depois** de GRPx / VDELPx (pl_mid_0: ALE, Stella, MiSTer).
4. RESMPx com player duplo / quádruplo: o míssil cai em 6 / 10 pixels depois do primeiro pixel do player (4 no player normal).
   Stella atual e MiSTer concordam; o ALE (Stella antigo) diz 7 / 15. [ABERTO: console]. O Towers só diz "contador de varredura em
   %100".
5. HMOVE na parte visível da linha: pulso extra que cai na parte visível coincide com um pulso normal (OR). Com as ROMs que recolocam
   o objeto a cada instante (hmove_*), ALE, Stella e MiSTer concordam em 35 de 36 instantes; o instante restante (strobe em hc 47,
   ciclo 15–16) é MiSTer (= modelo novo) contra ALE e Stella. [ABERTO].
6. Observação sobre a ROM antiga hmove_late (P0 colocado UMA vez): os 25 "desacordos" que ela mostrava entre ALE/Stella e MiSTer
   vinham da própria ROM (o movimento se acumulava entre os instantes, e as testemunhas acumulam de modo diferente na barra de
   8 pixels). A ROM foi refeita (hmove_obj.s) e o desacordo sumiu.

## 11. Casos achados em jogos reais (rodada d, 2026-10-20) e o que cada um diz

Método: a sequência de escritas do jogo foi reduzida a uma ROM de canto (tools/tia_tests/gp_*, hm_stuck, resmp_short, powerup, res_c3, d3_resm,
gp_replay4) e rodada nas testemunhas. O TIA do MiSTer também foi alimentado com o traço COMPLETO do jogo (de zero), sem recortar.
1. **RESP0 dentro do HBLANK estendido + HMOVE na linha seguinte** (Grand Prix, Night Grand Prix, Ram Defender): o player cai 2 pixels mais à
   direita no modelo novo que no P31/ALE. Stella atual, MiSTer e modelo novo concordam (gp_replay4, ROM `gp_replay4.a26`); ALE e P31 discordam.
   Towers, "Playing with the HMOVE registers": "the position counters will now resume counting 8 CLK later than they would have without the
   HMOVE"; e na seção do RESP no HBLANK: "hitting RESP0 before HBLANK has finished will reset the counter immediately, but it will only
   start counting again when HBLANK goes off". O Towers não trata o RESP durante os pulsos extras; [ABERTO: console].
2. **Trava de movimento do HMOVE (HMCLR/HMxx ~20 ciclos depois do HMOVE, Cosmic Ark)** (Ghoul, também Apong): Towers diz que o latch "continue[s] to
   send an additional clock signal every 4 CLK (during visible and non-visible parts of the scanline) until another HMOVE operation clears the
   latch. The HMCLR command does not reset these latches" e que "a HMCLR 20 cycles in has the same effect". Stella e MiSTer implementam
   (hm_stuck: o objeto anda 17 pixels por linha); ALE e P31 não. O modelo novo acompanha, com 1 pixel a mais que Stella=MiSTer (hm_stuck) e,
   quando um segundo HMOVE reinicia o contador (hm_stuck_re), Stella (152) e MiSTer (155) discordam entre si e do modelo novo (0). [ABERTO].
3. **RESMPx solto sem o centro do player ter passado** (Attack Of The Mighty Aliens): o míssil só vai para o centro do player se o centro passa
   com RESMPx = 1 (resmp_short: Stella e MiSTer deixam o míssil onde estava; ALE e P31 o levam ao player ao soltar). Modelo novo = Stella e MiSTer.
   O Towers não cobre o RESMP. [ABERTO: console].
4. **Objeto nunca resetado** (Mortal Kurling!, bola ligada sem RESBL): o estado do contador ao ligar não está definido em nenhuma fonte; cada
   modelo escolhe o seu (powerup.s: ALE e P31 pixel 0; Stella 1 a 2 e MiSTer 0 a 2 pixels depois). O modelo novo passou a ligar com a fase de 4 CLK (PUPH) que põe
   o objeto em pixel 0 como o P31/ALE: míssil/bola 2 CLK, player 3 CLK.

## 12. Régua de validação (mudada em 2026-10-20, decisão do responsável)

Até a rodada f a referência dos jogos era o ALE (Stella antigo) e o P31 contava como "OK" quando igual a ele. **A partir de 2026-10-20:**

1. **OK = igual ao consenso do Stella atual (commit 2c3d702) e do TIA do MiSTer** (GHDL, caixa-preta). O ALE só desempata quando os dois discordam.
2. Fica aceito que o TIA novo acompanhe Stella atual + MiSTer contra ALE + P31 nos casos Grand Prix, Night Grand Prix, Ram Defender (RESP0 durante o HBLANK
   estendido) e Attack Of The Mighty Aliens (RESMP gated pelo centro do player, RESM sem START): são divergências do ALE antigo, não erros do modelo novo.
3. Critério de integração: **nenhuma ROM piora na régua nova** (classe contra o Stella sobe, ou, na mesma classe, mais pixels contra o Stella e contra o ALE).
4. Mecânica: quadros 10/60/300 do Stella com o mesmo roteiro do ALE e do core (60 quadros parados, RESET nos quadros 61 a 68, depois o quadro 68 + n, fase -1..+1);
   comparação por CÓDIGO de cor do TIA (a paleta não entra; `regua/stl.py`, `regua/coll_regua.py`, `regua/reclass.py`, `regua/cmp_regua.py`). O núcleo libretro do Stella
   roda sem RAM nem registradores aleatórios na partida e sem mistura de quadros (fósforo), para o quadro ser reproduzível. Como Stella e ALE discordam entre si em muitos
   jogos inteiros, a comparação direta P31 x novo (pixel a pixel nos três quadros) separa o que o objeto novo muda do que as duas referências já discordavam.
