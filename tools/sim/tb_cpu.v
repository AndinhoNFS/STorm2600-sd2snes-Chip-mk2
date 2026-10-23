// tb_cpu.v -- (diagnosis 3) does a cartridge run at all?  a26_core alone, ROM answers at once.
//   +rom=<hex> +mapper=<n> +out=<prefix> +ncc=<colour clocks to run> +rst0/+rst1=<VSYNC count while RESET is held>
// <out>.tr: "O <pc> <opcode> <bank> <field>" for every opcode fetch;  "V <field> <lines since the last VSYNC fall> <colour clocks>"
// at every VSYNC fall;  "X <kind> <pc> <addr>" for a write into the cartridge area (kind W) or a read of TIA $xE/$xF (kind T)
`timescale 1ns / 1ps
module tb_cpu;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;
  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp, fn;
  integer sc_i = 0, mapper_i, ncc, tfd, cc = 0, field = 0, lines = 0, ccf = 0, rst0, rst1;
  wire [14:0] rom_addr;
  wire        rom_rd;
  reg  [7:0]  rom_data;
  reg         rom_ack = 0;
  always @(posedge clk) begin rom_ack <= rom_rd; rom_data <= rom[rom_addr]; end
  wire        pix_stb, pix_vis, vsync, vblank, cpu_rdy, cpu_sync, rom_miss, rom_miss_ev;
  wire [7:0]  pix_x, hcount;
  wire [1:0]  pix_src;
  wire [6:0]  pix_col, colubk, colupf, colup0, colup1;
  wire [4:0]  aud_mix;
  wire [15:0] cpu_ab;
  a26_core #(.CC_INC(25'd8388608)) core (
    .clk(clk), .rst(rst), .mapper(mapper_i[2:0]), .sc_en(sc_i[0]),
    .swcha_in(8'hFF), .swchb_in((field >= rst0 && field < rst1) ? 8'h3E : 8'h3F), .fire0(1'b1), .fire1(1'b1), .inpt(4'h0), .pause(1'b0),
    .rom_addr(rom_addr), .rom_rd(rom_rd), .rom_data(rom_data), .rom_ack(rom_ack),
    .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src), .pix_col(pix_col),
    .hcount(hcount), .vsync(vsync), .vblank(vblank),
    .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
    .aud_mix(aud_mix), .cpu_rdy(cpu_rdy), .cpu_ab(cpu_ab), .cpu_sync(cpu_sync),
    .rom_miss(rom_miss), .diag_clr(1'b0), .rom_miss_ev(rom_miss_ev));
  reg vs_d = 0;
  reg [15:0] pc_last = 0;
  always @(posedge clk) begin
    vs_d <= vsync;
    if (core.cc_ce) begin
      cc = cc + 1; ccf = ccf + 1;
      if (hcount == 8'd227) lines = lines + 1;
      if (cc >= ncc) begin $fclose(tfd); $finish; end
    end
    if (vs_d && !vsync) begin $fwrite(tfd, "V %0d %0d %0d\n", field, lines, ccf); field = field + 1; lines = 0; ccf = 0; end
    if (core.cpu_ce && cpu_sync) begin pc_last <= cpu_ab; $fwrite(tfd, "O %04x %02x %0d %0d\n", cpu_ab, core.cpu_din, core.bank, field); end
    if (core.cpu_ce && core.cpu_we && core.rom_cs) $fwrite(tfd, "X W %04x %04x\n", pc_last, cpu_ab);
    if (core.cpu_ce && !core.cpu_we && core.tia_cs && cpu_ab[3:0] >= 4'hE) $fwrite(tfd, "X T %04x %04x\n", pc_last, cpu_ab);
  end
  initial begin
    if (!$value$plusargs("rom=%s", romfile)) begin $display("no +rom"); $finish; end
    if (!$value$plusargs("out=%s", outp)) outp = "cpu";
    if (!$value$plusargs("mapper=%d", mapper_i)) mapper_i = 1;
    if (!$value$plusargs("sc=%d", sc_i)) sc_i = 0;                 // Superchip RAM (F8 / F6)
    if (!$value$plusargs("ncc=%d", ncc)) ncc = 59736 * 60;
    if (!$value$plusargs("rst0=%d", rst0)) rst0 = -1;
    if (!$value$plusargs("rst1=%d", rst1)) rst1 = -1;
    $sformat(fn, "%0s.tr", outp);
    tfd = $fopen(fn, "w");
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
