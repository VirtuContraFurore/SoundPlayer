module SDCard_cmd_fsm(
    clk, rst_n,
    
    /* SD Command interface */
    cmd_ready,
    cmd_req_idx,
    cmd_response_bytes,
    cmd_block_addr,
    
    /* SPI interface */
    spi_ready,
    spi_req,
    spi_tx_en,
    spi_tx_data,
    spi_rx_data
);

`include "../SPI_consts.v"
`include "SDCard_reader_consts.v"
`include "SDCard_reader_private.v"

/* Ports definition */
input clk;
input rst_n;
input [CMD_BITS-1:0] cmd_req_idx;
input spi_ready;
input [SPI_SIZE-1:0] spi_rx_data;
input [SD_BLOCK_ADDR_BITS-1:0] cmd_block_addr;

output wire cmd_ready;
output wire [CMD_RESP_BITS-1:0] cmd_response_bytes;
output wire [SPI_SIZE-1:0] spi_tx_data;
output reg spi_req = 0;
output reg spi_tx_en = 0;

/* Internal params */

/* Internal regs */
reg pending_request = 0;
reg [CMD_FSM_BITS-1:0] cmd_fsm_state = 0;
reg [CMD_SEND_COUNTER_BITS-1:0] cmd_counter = 0;
reg [CMD_RESP_COUNTER_BITS-1:0] cmd_resp_lenght = 0;
reg [ 7:0] cmd_response [CMD_MAX_RESP_BYTES-1:0];
reg [ 5:0] cmd_index = 0;
reg [31:0] cmd_arg = 0;
reg [ 6:0] cmd_crc = 0;

/* Internal wires */
wire [7:0] card_cmd_packet[5:0];

/* Internal assignments */
assign card_cmd_packet[0] = {1'b0, 1'b1, cmd_index[5:0]};
assign card_cmd_packet[1] = cmd_arg[31:24];
assign card_cmd_packet[2] = cmd_arg[23:16];
assign card_cmd_packet[3] = cmd_arg[15: 8];
assign card_cmd_packet[4] = cmd_arg[ 7: 0];
assign card_cmd_packet[5] = {cmd_crc[6:0], 1'b1};
assign cmd_ready = (cmd_fsm_state == CMD_FSM_IDLE);
assign spi_tx_data = card_cmd_packet[cmd_counter];

genvar i;
generate
for(i = 0; i < CMD_MAX_RESP_BYTES; i = i + 1) begin : my_byte_assignment_1
    assign cmd_response_bytes[8*i+7:8*i] = cmd_response[i];
end
endgenerate

/* Macro used inside the decode block */
`define SDCARD_SEND_CMD(index, param, ret_bytes, crc) begin cmd_index <= index; cmd_arg <= param; cmd_crc <= crc; cmd_resp_lenght <= ret_bytes; pending_request <= 1; end

/* SD Card Commands requests decode */
always @ (posedge clk) begin
    if(cmd_ready) begin
        case(cmd_req_idx)
        NOCMD:   pending_request <= 0;
        CMD0:   `SDCARD_SEND_CMD( 0,              0, 1, 7'h4A) /* Go Idle State */
        CMD8:   `SDCARD_SEND_CMD( 8,   32'h000001AA, 5, 7'h43) /* Send Interface Condition */
        CMD12:  `SDCARD_SEND_CMD(12,              0, 1,     0) /* Stop transmission */
        CMD17:  `SDCARD_SEND_CMD(17, cmd_block_addr, 1,     0) /* Single block read */
        CMD18:  `SDCARD_SEND_CMD(18, cmd_block_addr, 1,     0) /* Multiple block read */
        CMD55:  `SDCARD_SEND_CMD(55,              0, 1,     0) /* Next command is an Application Command (ACMD) */
        CMD58:  `SDCARD_SEND_CMD(58,              0, 5,     0) /* Read OCR */
        ACMD41: `SDCARD_SEND_CMD(41,   32'h40000000, 1,     0) /* Send Operating Condition */
        endcase;
    end else
         pending_request <= 0;
end

//`undef SDCARD_SEND_CMD

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
        cmd_fsm_state <= (pending_request) ? CMD_FSM_SEND_CMD_1 : cmd_fsm_state;
    end
    CMD_FSM_SEND_CMD_1: begin
        spi_tx_en <= 1;
        spi_req   <= 1;
        cmd_fsm_state <= CMD_FSM_SEND_CMD_2;
    end
    CMD_FSM_SEND_CMD_2: begin
        spi_tx_en   <= cmd_counter < CARD_CMD_BYTES;
        if(spi_ready) begin
            cmd_counter   <= (cmd_counter < CARD_CMD_BYTES) ? cmd_counter + 1'b1 : 0;
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
            cmd_counter <= cmd_counter + 1'b1;
            cmd_fsm_state <= (cmd_counter < cmd_resp_lenght - 1) ? CMD_FSM_RECEIVE_CMD_RESP_4 : CMD_FSM_IDLE;;
        end
    end
    CMD_FSM_RECEIVE_CMD_RESP_4: begin
        spi_req <= spi_ready;
        cmd_fsm_state <= (spi_ready) ? cmd_fsm_state : CMD_FSM_RECEIVE_CMD_RESP_3;
    end
    endcase
end

endmodule