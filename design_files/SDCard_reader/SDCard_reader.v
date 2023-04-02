`include "../globals.v"

module SDCard_reader(
    clk, rst_n,
    
    /* SD Card physical pins */
    sd_clk,
    sd_do,
    sd_di,
    sd_cs_n,
    
    /* System signals */
    card_configured,
    
    /* Block read interface */
    block_read_trigger,
    block_read_card_ready,
    block_read_continous_mode,
    block_read_block_addr,
    block_read_data_out,
    block_read_data_idx,
    block_read_data_new_flag
    
    /* Debug singnals */
    //debug_bus, debug_ctrl
);

/* Local params */
`include "../SPI_consts.v"
`include "SDCard_reader_consts.v"
`include "SDCard_reader_private.v"

/* Ports definition */
input clk;
input rst_n;
input sd_do;
input block_read_trigger;
input block_read_continous_mode;
input [SD_BLOCK_ADDR_BITS-1:0] block_read_block_addr;

output wire sd_di;
output wire sd_clk;
output wire sd_cs_n;
output wire card_configured;
output wire block_read_card_ready;
output wire [SD_BLOCK_LENGHT_BITS-1:0] block_read_data_idx;
output wire [7:0] block_read_data_out;
output wire block_read_data_new_flag;

/* Internal registers */

/* Internal wires */
wire [SPI_PSCLR_BITS-1:0] spi_prescaler;
wire [SPI_SIZE-1:0] spi_rx_data;
wire [SPI_SIZE-1:0] spi_tx_data;
wire spi_tx_en;
wire spi_busy;
wire spi_ready;
wire spi_req_1;
wire spi_req_2;

wire cmd_ready;
wire [CMD_BITS-1:0] cmd_req_idx;
wire [CMD_RESP_BITS-1:0] cmd_response_bytes;
wire [SD_BLOCK_ADDR_BITS-1:0] cmd_block_addr;

/* Internal assignments */
assign spi_ready = !spi_busy;

/* Istances */
SPI_master #(
    .SPI_PACKET_SIZE(SPI_SIZE)
) spi (
    .clk(clk), .rst_n(rst_n),
    
    /* SPI interface */
    .prescaler(spi_prescaler),
    .tx_en(spi_tx_en),
    .req(spi_req_1 | spi_req_2),
    .busy(spi_busy),
    .data_rx(spi_rx_data),
    .data_tx(spi_tx_data),
    
    /* Connect physical SPI signals */
    .spi_clk(sd_clk),
    .spi_mosi(sd_di),
    .spi_miso(sd_do)
);

SDCard_cmd_fsm cmd_fsm (
    .clk(clk), .rst_n(rst_n),
    
    /* SD Command interface */
    .cmd_ready(cmd_ready),
    .cmd_req_idx(cmd_req_idx),
    .cmd_response_bytes(cmd_response_bytes),
    .cmd_block_addr(cmd_block_addr),
    
    /* SPI interface */
    .spi_ready(spi_ready),
    .spi_req(spi_req_1),
    .spi_tx_en(spi_tx_en),
    .spi_tx_data(spi_tx_data),
    .spi_rx_data(spi_rx_data)
);

SDCard_main_fsm main_fsm (
    .clk(clk), .rst_n(rst_n),
    .sd_cs_n(sd_cs_n),
    
    /* Block read interface */
    .block_read_trigger(block_read_trigger),
    .block_read_continous_mode(block_read_continous_mode),
    .block_read_block_addr(block_read_block_addr),
    .block_read_data_out(block_read_data_out),
    .block_read_data_idx(block_read_data_idx),
    .block_read_data_new_flag(block_read_data_new_flag),
    .block_read_card_ready(block_read_card_ready),
    
    /* SD Command interface */
    .cmd_ready(cmd_ready),
    .cmd_req_idx(cmd_req_idx),
    .cmd_response_bytes(cmd_response_bytes),
    .cmd_block_addr(cmd_block_addr),
    
    /* SPI interface */
    .spi_ready(spi_ready),
    .spi_req(spi_req_2),
    .spi_rx_data(spi_rx_data),
    .spi_prescaler(spi_prescaler),
    
    .card_configured(card_configured)
);

`ifdef DEBUG_SDCARD_READER

`endif

endmodule
