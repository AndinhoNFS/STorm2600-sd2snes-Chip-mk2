# fpga/experimental/p26B: alocação das 4 cores por linha (Passo 26, item B)

**Não está no bitstream.** Os arquivos desta pasta não entram na síntese; o
`fpga/a26_vidwr.v` em uso continua o do Passo 24.

| Arquivo | Conteúdo |
|---|---|
| `a26_vidwr.v` | gravador do quadro com a alocação das cores |
| `tb_a26_vidwr.v` | testbench com o modelo da alocação e o quadro 50 (cor nova no meio da linha) |

## O que faz

No Passo 24 o gravador lê as 4 cores da linha (COLUBK, COLUPF, COLUP0, COLUP1)
uma vez, no pixel 16. Um jogo que troca uma cor depois disso por uma cor nova
perde essa cor: é o tabuleiro do Checkers e a cor das barras do H.E.R.O. e do
Seaquest.

Aqui os 4 índices da linha começam livres. Cada pixel visível pega o índice que
já tem a sua cor final (o da própria fonte primeiro), senão o da própria fonte
se estiver livre, senão o menor índice livre. As palavras de cor de uma linha
são gravadas durante a linha seguinte. O formato do buffer não muda, e o player
v7 serve.

## Resultado

- **Simulação:** 0 pixels de cor errada nos 11 jogos medidos (Pitfall, River
  Raid, Pac-Man, Enduro, Boxing, Frostbite, H.E.R.O., Seaquest, Checkers,
  Crackpots e Decathlon), parado e jogando. N máximo de tiles igual ou menor,
  nenhum quadro descartado. O testbench passa:
  `iverilog -g2005 -o tb tb_a26_vidwr.v a26_vidwr.v ../../a26_tdict.v && vvp tb`
  (o `a26_bgr555.hex` de `fpga/` precisa estar no diretório corrente).
- **Timing:** NÃO fecha. O clock de 96 MHz deu -2,614 ns (semente 17) e
  -1,536 ns (semente 10). O caminho pior vai de `pix_src` (TIA) a `fb_wdata`
  (gravador): 11,946 ns em 9 níveis de lógica, para um período de 10,4 ns.

## Por que não fecha e o que fazer

As restrições de timing não relaxam o caminho do TIA até o gravador: o gravador
lê as saídas do TIA 1 clock depois que elas mudam, e a decisão do índice passa a
caber inteira nesse clock.

Proposta (não feita): o gravador guarda o pixel do TIA num registrador no
`pix_stb` e o processa num strobe atrasado de ~13 clocks. Os pixels vêm a cada
~27 clocks, então toda a decisão cabe num caminho relaxado de 125 ns. Isso muda
o `tb_a26_vidwr.v`, que hoje dá um strobe a cada 4 clocks, e as restrições
(o atraso entra no grupo rápido).
