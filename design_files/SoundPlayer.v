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

`include "SDCard_reader/SDCard_reader_consts.v"

/* Internal wires */
wire clk;
wire rst_n; 

wire sd_configured;

wire block_read_trigger;
wire block_read_card_ready;
wire block_read_continous_mode;
wire [SD_BLOCK_ADDR_BITS-1:0] block_read_block_addr;
wire [7:0] block_read_data_out;
wire [SD_BLOCK_LENGHT_BITS-1:0] block_read_data_idx;
wire block_read_data_new_flag;

wire error_no_fat_found;

/* Internal assignments */
assign rst_n = KEY[3];

assign GPIO_0[0] = SD_SCLOCK;
assign GPIO_0[1] = SD_DO;
assign GPIO_0[2] = SD_DI;
assign GPIO_0[3] = SD_CS;
assign GPIO_0[4] = block_read_trigger;

assign LEDG[2] = sd_configured & !error_no_fat_found; /* no fat found valid only if card configured */
assign LEDG[1] = block_read_card_ready;
assign LEDG[0] = sd_configured;

//assign block_read_trigger = !KEY[2];
//assign block_read_continous_mode = SW[0];
//assign block_read_block_addr = 32'h00000000;

MAIN_PLL main_pll(
    .inclk0(CLOCK_50),
    .c0(clk)
);

SDCard_reader sd_card (
    .clk(clk),
    .rst_n(rst_n),
    
    .card_configured(sd_configured),
    
    /* SD Card physical interface */
    .sd_do(SD_DO),
    .sd_di(SD_DI),
    .sd_clk(SD_SCLOCK),
    .sd_cs_n(SD_CS),
    
    /* Block read interface */
    .block_read_trigger(block_read_trigger),
    .block_read_card_ready(block_read_card_ready),
    .block_read_continous_mode(block_read_continous_mode),
    .block_read_block_addr(block_read_block_addr),
    .block_read_data_out(block_read_data_out),
    .block_read_data_idx(block_read_data_idx),
    .block_read_data_new_flag(block_read_data_new_flag)
);

FAT32_reader fat32_reader (
    .clk(clk),
    .rst_n(rst_n),
    
    /* Block read interface */
    .block_read_trigger(block_read_trigger),
    .block_read_card_ready(block_read_card_ready),
    .block_read_continous_mode(block_read_continous_mode),
    .block_read_block_addr(block_read_block_addr),
    .block_read_data_in(block_read_data_out),
    .block_read_data_idx(block_read_data_idx),
    .block_read_data_new_flag(block_read_data_new_flag),
    
    /* Status */
    .error_no_fat_found(error_no_fat_found)
);

endmodule

