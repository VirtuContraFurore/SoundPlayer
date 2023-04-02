module SoundPlayer(
    CLOCK_50,
    KEY, SW,
    LEDR, LEDG,
    GPIO_0, GPIO_1,
    SD_DO, SD_DI, SD_SCLOCK, SD_CS
);

/* Ports definition */
input CLOCK_50;
input [3:0] KEY;
input [17:0] SW;
input SD_DO;

inout wire [35:0] GPIO_0;
inout wire [35:0] GPIO_1;

output wire SD_DI;
output wire SD_SCLOCK;
output wire SD_CS;
output [17:0] LEDR;
output [7:0] LEDG;

/* Internal wires */
wire global_rst_n; 
wire sd_ready;
wire sd_data_rdy;
wire clk;
wire [7:0] sd_data_out;
wire [11:0] sd_data_idx;
wire sd_read_block;
reg sd_continous_read = 1;
reg [31:0] sd_block_addr = 0;

/* Internal assignments */
assign GPIO_0[0] = SD_SCLOCK;
assign GPIO_0[1] = SD_DO;
assign GPIO_0[2] = SD_DI;
assign GPIO_0[3] = SD_CS;
assign clk = CLOCK_50;
assign sd_read_block = !KEY[2];
assign global_rst_n = KEY[3];
assign LEDG[1] = sd_ready;

SDCard_reader sd_card (
    .clk(clk),
    .rst_n(global_rst_n),
    .card_configured(LEDG[0]),
    .sd_do(SD_DO),
    .sd_di(SD_DI),
    .sd_clk(SD_SCLOCK),
    .sd_cs_n(SD_CS),
    .sd_card_ready(sd_ready),
    .read_block(sd_read_block), 
    .block_addr(sd_block_addr),
    .data_out(sd_data_out),
    .data_idx(sd_data_idx),
    .data_rdy(sd_data_rdy),
    .continous_read(1),
    .r0_d(LEDR[7:0])
);

endmodule

