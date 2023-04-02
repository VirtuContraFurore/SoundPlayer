`include "globals.v"

module SDCard_reader(
    /* SD Card physical pins */
    sd_do, sd_di, sd_clk, sd_cs_n,
    
    /* System signals */
    clk, rst_n, card_configured,
    sd_card_ready, read_block, block_addr,
    data_out, data_idx, data_rdy, continous_read,
    
    r0_d
`ifdef DEBUG_SDCARD_READER
    , cmd_fsm_d, spi_busy_d, spi_req_d, cmd_counter_d, cmd_index_d, spi_tx_output_d, packet_0_d, 
`endif
);


/* Local params */
`include "SPI_consts.v"
`include "SDCard_const.v"
localparam SPI_SIZE = 4'd8;
localparam CARD_CMD_BYTES = 6; /* Lenght of SD command in bytes */
localparam CARD_BLOCKLEN_BYTES = 512; /* Block lenght in bytes*/

/* Ports definition */
input clk;
input rst_n;
input sd_do;
input [31:0] block_addr;
input read_block;
input continous_read;

output wire sd_di;
output wire sd_clk;
output wire sd_card_ready;
output reg [7:0] data_out = 0;
output reg [11:0] data_idx = 0;
output reg data_rdy = 0;
output reg sd_cs_n = 1;
output reg card_configured = 0;

/* Internal registers */
reg [SPI_PSCLR_BITS-1:0] spi_clk_prescaler = SPI_PSCLR_DIV8;
reg spi_tx_en = 0;
reg spi_req = 0;
reg spi_req1 = 0;
reg [SPI_SIZE-1:0] spi_tx_data = 0;
reg [FSM_BITS-1:0] fsm_state = 0;
reg [FSM_BITS-1:0] linked_state = 0;
reg [CMD_FSM_BITS-1:0] cmd_fsm_state = 0;
reg [5:0]  cmd_index = 0;
reg [31:0] cmd_arg = 0;
reg [6:0]  cmd_crc = 0;
reg [8:0]  cmd_response[4:0];
reg [11:0] cmd_counter = 0;
reg [11:0] cmd_resp_lenght = 0;
reg send_cmd_req = 0;
reg [CMD_BITS-1:0] cmd = NOCMD;
reg [12:0] pulse_counter = 0;
reg [31:0] block_addr_;
reg [11:0] byte_counter;
reg continous_read_;

/* Internal wires */
wire [SPI_SIZE-1:0] spi_rx_data;
wire spi_busy;
wire spi_ready;
wire [SPI_SIZE-1:0] card_cmd_packet[5:0];
wire cmd_executing;
wire spi_req_or;
wire cmd_ready;
wire [7:0] R0;

/* Master SPI instance */
SPI_master #(
    .SPI_PACKET_SIZE(SPI_SIZE)
) spi (
    .clk(clk), .rst_n(rst_n),
    .prescaler(spi_clk_prescaler),
    .tx_en(spi_tx_en), .req(spi_req_or), .busy(spi_busy),
    .data_rx(spi_rx_data), .data_tx(spi_tx_data),
    
    /* Connect SD SPI signals */
    .spi_clk(sd_clk),
    .spi_mosi(sd_di),
    .spi_miso(sd_do)
);

/* Internal assignments */
assign card_cmd_packet[0] = {1'b0, 1'b1, cmd_index[5:0]};
assign card_cmd_packet[1] = cmd_arg[31:24];
assign card_cmd_packet[2] = cmd_arg[23:16];
assign card_cmd_packet[3] = cmd_arg[15: 8];
assign card_cmd_packet[4] = cmd_arg[ 7: 0];
assign card_cmd_packet[5] = {cmd_crc[6:0], 1'b1};
assign cmd_ready = (cmd_fsm_state == CMD_FSM_IDLE);
assign spi_ready = !spi_busy;
assign sd_card_ready = (fsm_state == FSM_CARD_READY);
assign spi_req_or = spi_req | spi_req1;
assign R0 = cmd_response[0];

/* Defines */
`define SEND_CMD(command, next_state) begin cmd <= command; linked_state <= next_state; fsm_state <= FSM_RUN_CMD_0; end
`define SDCARD_SEND_CMD(index, param, ret_bytes, crc) begin cmd_index <= index; cmd_arg <= param; cmd_crc <= crc; cmd_resp_lenght <= ret_bytes; send_cmd_req <= 1; end
`ifdef DEBUG_SDCARD_READER
`define STARTUP_PRESCALER SPI_PSCLR_DIV4
`else
`define STARTUP_PRESCALER SPI_PSCLR_DIV256
`endif

/* Main Finite State Machine */
always @ (posedge clk) begin
    if(!rst_n) begin
        fsm_state <= FSM_CARD_NOT_READY;
        cmd <= NOCMD;
        card_configured <= 0;
    end
    else case(fsm_state)
    FSM_CARD_NOT_READY: begin
        cmd <= NOCMD;
        card_configured <= 0;
        spi_clk_prescaler <= `STARTUP_PRESCALER; /* Start with 198 kHz clock */
        fsm_state <= FSM_CONFIGURING_CARD_1;
    end
    FSM_CONFIGURING_CARD_1: begin
        sd_cs_n <= 1;
        spi_req1 <=1;
        pulse_counter <= 0;
        if(!spi_ready)
            fsm_state <= FSM_CONFIGURING_CARD_2;
    end
    FSM_CONFIGURING_CARD_2: begin
        spi_req1 <= pulse_counter < 9;
        pulse_counter <= (spi_ready) ? pulse_counter + 1 : pulse_counter;
        if(pulse_counter == 10) begin
            fsm_state <= FSM_CONFIGURING_CARD_3;
            sd_cs_n <= 0;
        end
    end
    FSM_CONFIGURING_CARD_3: `SEND_CMD(CMD0,  FSM_CONFIGURING_CARD_4)
    FSM_CONFIGURING_CARD_4: `SEND_CMD(CMD8,  FSM_CONFIGURING_CARD_5)
    FSM_CONFIGURING_CARD_5: `SEND_CMD(CMD58, FSM_CONFIGURING_CARD_6)
    FSM_CONFIGURING_CARD_6: `SEND_CMD(CMD55, FSM_CONFIGURING_CARD_7)
    FSM_CONFIGURING_CARD_7: `SEND_CMD(ACMD41, FSM_CONFIGURING_CARD_8)
    FSM_CONFIGURING_CARD_8:  fsm_state <= (R0[0] == 0) ? FSM_CONFIGURING_CARD_9 : FSM_CONFIGURING_CARD_6;
    FSM_CONFIGURING_CARD_9: `SEND_CMD(CMD58, FSM_CONFIGURING_CARD_10)
    FSM_CONFIGURING_CARD_10: begin 
        spi_clk_prescaler <= SPI_PSCLR_DIV8;
        card_configured <= 1;
        fsm_state <= FSM_CARD_READY;
    end
    FSM_CARD_READY: begin
        data_rdy <= 0;
        if(read_block) begin
            block_addr_ <= block_addr;
            byte_counter <= 0;
            continous_read_ <= continous_read;
            if(continous_read)
                `SEND_CMD(CMD18, FSM_CARD_BUSY_0)
            else 
                `SEND_CMD(CMD17, FSM_CARD_BUSY_0)   
        end;
    end
    FSM_CARD_BUSY_0: fsm_state <= (R0[0] == 0) ? FSM_CARD_BUSY_1 : FSM_CARD_NOT_READY;
    FSM_CARD_BUSY_1: begin
        spi_req1 <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_2;
    end
    FSM_CARD_BUSY_2: begin
        if(spi_ready)
            fsm_state <= (spi_rx_data == 8'hff) ? FSM_CARD_BUSY_1 : FSM_CARD_BUSY_3;
    end
    FSM_CARD_BUSY_3: begin
        data_rdy <= 0;
        spi_req1 <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_4;
    end
    FSM_CARD_BUSY_4: begin
        if(spi_ready) begin
            data_out <= spi_rx_data;
            data_idx <= byte_counter;
            data_rdy <= 1'b1;
            byte_counter <= byte_counter + 1;
            if (byte_counter + 1 < CARD_BLOCKLEN_BYTES) begin
                fsm_state <= FSM_CARD_BUSY_3;
            end else 
                fsm_state <= (continous_read_) ? ((read_block) ? FSM_CARD_BUSY_1 : FSM_CARD_BUSY_5) : FSM_CARD_READY;
        end
    end
    FSM_CARD_BUSY_5: `SEND_CMD(CMD12, FSM_CARD_BUSY_6)
    FSM_CARD_BUSY_6: begin
        spi_req1 <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_7;
    end
    FSM_CARD_BUSY_7: begin
        if(spi_ready)
            fsm_state <= (spi_rx_data == 8'h00) ? FSM_CARD_BUSY_6 : FSM_CARD_READY;
    end
    FSM_RUN_CMD_0: begin
        if(!cmd_ready) begin
            fsm_state <= FSM_RUN_CMD_1;
            cmd <= NOCMD;
        end
    end
    FSM_RUN_CMD_1: begin
        if(cmd_ready)
            fsm_state <= linked_state;
    end
    endcase
end

/* SDCard Commands Finite State Machine */
always @ (posedge clk) begin
    if(!rst_n) begin
        cmd_fsm_state <= CMD_FSM_IDLE;
    end
    else case(cmd_fsm_state)
    CMD_FSM_IDLE: begin
        cmd_counter <= 0;
        spi_req     <= 0;
        spi_tx_en   <= 0;
        cmd_fsm_state <= (send_cmd_req) ? CMD_FSM_SEND_CMD_1 : cmd_fsm_state;
    end
    CMD_FSM_SEND_CMD_1: begin
        spi_tx_data <= card_cmd_packet[0];
        spi_tx_en <= 1;
        spi_req <= 1;
        cmd_fsm_state <= CMD_FSM_SEND_CMD_2;
    end
    CMD_FSM_SEND_CMD_2: begin
        spi_tx_en   <= cmd_counter < CARD_CMD_BYTES;
        spi_tx_data <= card_cmd_packet[cmd_counter];
        if(spi_ready) begin
            cmd_counter   <= (cmd_counter < CARD_CMD_BYTES) ? cmd_counter + 1 : 0;
            cmd_fsm_state <= (cmd_counter < CARD_CMD_BYTES) ? cmd_fsm_state : CMD_FSM_RECEIVE_CMD_RESP_2;
        end
    end
    CMD_FSM_RECEIVE_CMD_RESP_1: begin
        spi_req <= spi_ready;
        cmd_fsm_state <= (spi_ready) ? cmd_fsm_state : CMD_FSM_RECEIVE_CMD_RESP_2;
    end
    CMD_FSM_RECEIVE_CMD_RESP_2: begin
       spi_req <= 0;
       cmd_counter <= 0;
       if(spi_ready)
            cmd_fsm_state <= (spi_rx_data == 8'hff) ? CMD_FSM_RECEIVE_CMD_RESP_1 : CMD_FSM_RECEIVE_CMD_RESP_3;
    end
    CMD_FSM_RECEIVE_CMD_RESP_3: begin
        if(spi_ready) begin
            cmd_response[cmd_counter] <= spi_rx_data;
            cmd_counter <= cmd_counter + 1;
            cmd_fsm_state <= ((cmd_counter + 1) < cmd_resp_lenght) ? CMD_FSM_RECEIVE_CMD_RESP_4 : CMD_FSM_IDLE;;
        end
    end
    CMD_FSM_RECEIVE_CMD_RESP_4: begin
        spi_req <= spi_ready;
        cmd_fsm_state <= (spi_ready) ? cmd_fsm_state : CMD_FSM_RECEIVE_CMD_RESP_3;
    end
    endcase
end

/* SD Card Commands request */
always @ (posedge clk) begin
    if(cmd_ready) begin
        case(cmd)
        NOCMD:  send_cmd_req <= 0;
        CMD0:   `SDCARD_SEND_CMD( 0,            0, 1, 7'h4A) /* Go Idle State */
        CMD8:   `SDCARD_SEND_CMD( 8, 32'h000001AA, 5, 7'h43) /* Send Interface Condition */
        CMD12:  `SDCARD_SEND_CMD(12,            0, 1,     0) /* Stop transmission */
        CMD17:  `SDCARD_SEND_CMD(17,  block_addr_, 1,     0) /* Single block read */
        CMD18:  `SDCARD_SEND_CMD(18,  block_addr_, 1,     0) /* Multiple block read */
        CMD55:  `SDCARD_SEND_CMD(55,            0, 1,     0) /* Next command is an Application Command (ACMD) */
        CMD58:  `SDCARD_SEND_CMD(58,            0, 5,     0) /* Read OCR */
        ACMD41: `SDCARD_SEND_CMD(41, 32'h40000000, 1,     0) /* Send Operating Condition */
        endcase;
    end else
        send_cmd_req <= 0;
end

`ifdef DEBUG_SDCARD_READER
output [CMD_FSM_BITS-1:0] cmd_fsm_d;
output [11:0] cmd_counter_d;
output spi_busy_d;
output spi_req_d;
output [5:0] cmd_index_d;
output [7:0] spi_tx_output_d;
output [7:0] packet_0_d;

assign cmd_fsm_d = cmd_fsm_state;
assign spi_busy_d = spi_busy;
assign spi_req_d = spi_req;
assign cmd_counter_d = cmd_counter;
assign cmd_index_d = cmd_index;
assign spi_tx_output_d = spi_tx_data;
assign packet_0_d = card_cmd_packet[0];
`endif

output [7:0] r0_d;
assign r0_d = R0;

endmodule
