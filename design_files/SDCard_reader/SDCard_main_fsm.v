module SDCard_main_fsm(
    clk, rst_n, sd_cs_n,
    
    /* Block read interface */
    block_read_trigger,
    block_read_continous_mode,
    block_read_block_addr,
    block_read_data_out,
    block_read_data_idx,
    block_read_data_new_flag,
    block_read_card_ready,
    
    /* SD Command interface */
    cmd_ready,
    cmd_req_idx,
    cmd_response_bytes,
    cmd_block_addr,
    
    /* SPI interface */
    spi_ready,
    spi_req,
    spi_rx_data,
    spi_prescaler,
    
    card_configured
);

`include "../SPI_consts.v"
`include "SDCard_reader_consts.v"
`include "SDCard_reader_private.v"

/* Ports definition */
input clk;
input rst_n;
input block_read_trigger;
input block_read_continous_mode;
input [SD_BLOCK_ADDR_BITS-1:0] block_read_block_addr;
input cmd_ready;
input spi_ready;
input [SPI_SIZE-1:0] spi_rx_data;
input [CMD_RESP_BITS-1:0] cmd_response_bytes;

output wire block_read_card_ready;
output reg sd_cs_n = 1;
output reg spi_req = 0;
output reg [CMD_BITS-1:0] cmd_req_idx = NOCMD;
output reg [SD_BLOCK_LENGHT_BITS-1:0] block_read_data_idx = 0;
output reg [SD_BLOCK_ADDR_BITS-1:0] cmd_block_addr = 0;
output reg [7:0] block_read_data_out;
output reg card_configured = 0;
output reg block_read_data_new_flag = 0;
output reg [SPI_PSCLR_BITS-1:0] spi_prescaler = 0;

/* Internal params */
localparam RESET_CYCLES = RESET_PULSES/8;
localparam RESET_CYCLES_BITS = $clog2(RESET_CYCLES+1);

/* Internal regs */
reg [FSM_BITS-1:0] fsm_state = 0;
reg [FSM_BITS-1:0] linked_state = 0;
reg [RESET_CYCLES_BITS-1:0] pulse_counter = 0;
reg [SD_BLOCK_LENGHT_BITS-1:0] byte_counter = 0;
reg continous_read_flag = 0;

/* Internal wires */
wire [7:0] R0;

/* Internal assignments */
assign block_read_card_ready = (fsm_state == FSM_CARD_READY);
assign R0 = cmd_response_bytes[7:0];

/* Macro used inside the state machine */
`define SEND_CMD(command, next_state) begin cmd_req_idx <= (command); linked_state <= (next_state); fsm_state <= FSM_RUN_CMD_0; end

/* Macro to select init prescaler */
`ifdef DEBUG_SDCARD_READER
`define STARTUP_PRESCALER SPI_PSCLR_DIV4
`else
`define STARTUP_PRESCALER SPI_PSCLR_DIV256
`endif

/* Main Finite State Machine */
always @ (posedge clk) begin
    if(!rst_n) begin
        fsm_state <= FSM_CARD_NOT_READY;
        cmd_req_idx <= NOCMD;
        card_configured <= 0;
    end
    else case(fsm_state)
    FSM_CARD_NOT_READY: begin
        cmd_req_idx <= NOCMD;
        card_configured <= 0;
        spi_prescaler <= `STARTUP_PRESCALER; /* Start with 198 kHz clock */
        fsm_state <= FSM_CONFIGURING_CARD_1;
    end
    
    /* Card setup and configuration */
    FSM_CONFIGURING_CARD_1: begin
        sd_cs_n <= 1;
        spi_req <=1;
        pulse_counter <= 0;
        if(!spi_ready)
            fsm_state <= FSM_CONFIGURING_CARD_2;
    end
    FSM_CONFIGURING_CARD_2: begin /* send 80 clock pulses with CS deasserted */
        spi_req <= pulse_counter < RESET_CYCLES-1;
        pulse_counter <= (spi_ready) ? pulse_counter + 1'b1 : pulse_counter;
        if(pulse_counter == RESET_CYCLES) begin
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
        spi_prescaler <= `SDCARD_MISSION_MODE_PSCLR;
        card_configured <= 1;
        fsm_state <= FSM_CARD_READY;
    end
    
    /* Card waits for block read requests */
    FSM_CARD_READY: begin
        block_read_data_new_flag <= 0;
        block_read_data_idx <= 0;
        byte_counter <= 0;  
        if(block_read_trigger) begin
            cmd_block_addr <= block_read_block_addr;
            continous_read_flag <= block_read_continous_mode;
            `SEND_CMD((block_read_continous_mode ? CMD18 : CMD17), FSM_CARD_BUSY_0)   
        end;
    end
    
    /* Executes single or continous block read */
    FSM_CARD_BUSY_0: fsm_state <= (R0[0] == 0) ? FSM_CARD_BUSY_1 : FSM_CARD_NOT_READY;
    FSM_CARD_BUSY_1: begin
        spi_req <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_2;
    end
    FSM_CARD_BUSY_2: begin
        if(spi_ready)
            fsm_state <= (spi_rx_data == 8'hff) ? FSM_CARD_BUSY_1 : FSM_CARD_BUSY_3;
    end
    FSM_CARD_BUSY_3: begin
        block_read_data_new_flag <= 0;
        spi_req <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_4;
    end
    FSM_CARD_BUSY_4: begin
        if(spi_ready) begin
            block_read_data_out <= spi_rx_data;
            block_read_data_idx <= byte_counter;
            block_read_data_new_flag <= 1'b1;
            byte_counter <= byte_counter + 1'b1;
            fsm_state <= (byte_counter != (SD_BLOCK_LENGHT_BYTES-1)) ? FSM_CARD_BUSY_3 : FSM_CARD_BUSY_CRC_1;
        end
    end
    FSM_CARD_BUSY_CRC_1: begin /* eat 2 crc bytes */
        block_read_data_new_flag <= 0;
        spi_req <= 1;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_CRC_2;
    end
    FSM_CARD_BUSY_CRC_2: begin 
        fsm_state <= (!spi_ready) ? fsm_state : FSM_CARD_BUSY_CRC_3;
    end
    FSM_CARD_BUSY_CRC_3: begin
        spi_req <= 0;
        if(spi_ready) begin
            fsm_state <= (!continous_read_flag) ? FSM_CARD_READY : ((block_read_trigger) ? FSM_CARD_BUSY_1 : FSM_CARD_BUSY_STOP_1);
        end
    end
    FSM_CARD_BUSY_STOP_1: `SEND_CMD(CMD12, FSM_CARD_BUSY_STOP_2) /* stops multiple block read */
    FSM_CARD_BUSY_STOP_2: begin
        spi_req <= spi_ready;
        fsm_state <= (spi_ready) ? fsm_state : FSM_CARD_BUSY_STOP_3;
    end
    FSM_CARD_BUSY_STOP_3: begin /* waits for non zero response, see R1b response type */
        if(spi_ready)
            fsm_state <= (spi_rx_data == 8'h00) ? FSM_CARD_BUSY_STOP_2 : FSM_CARD_READY;
    end
    
    /* Run command and wait end of command execution */
    FSM_RUN_CMD_0: begin
        if(!cmd_ready) begin
            fsm_state <= FSM_RUN_CMD_1;
            cmd_req_idx <= NOCMD;
        end
    end
    FSM_RUN_CMD_1: begin
        if(cmd_ready)
            fsm_state <= linked_state;
    end
    endcase
end

//`undef SEND_CMD
//`undef STARTUP_PRESCALER

endmodule
