`include "globals.v"

module SPI_master #(
    parameter SPI_PACKET_SIZE = 4'd8,  /* SPI packet SPI_PACKET_SIZE */
    parameter SPI_MOSI_IDLE = 1'd1,    /* MOSI idle logic level */
    parameter SPI_CPOL = 1'd0,         /* Clock idle level */
    parameter SPI_CPHA = 1'd0          /* Clock phasing, please refer to https://en.wikipedia.org/wiki/Serial_Peripheral_Interface */
)(
    /* SPI physical signals */
    spi_mosi, spi_miso, spi_clk,

    /* Control signals */
    clk, rst_n,  prescaler, tx_en, req, busy,
    
    /* Input and output data registers */
    data_rx, data_tx

    /* Debug signals */
`ifdef DEBUG_SPI_MASTER
    , _spi_rising_edge, _spi_clock_counter, _spi_done, _spi_sub_counter, _spi_fsm
`endif
);

/* Include shared constants */
`include "SPI_consts.v"

/* Local params */
localparam FSM_STATES = 2;
localparam FSM_IDLE   = 0;
localparam FSM_START  = 1;
localparam FSM_BITS                = $clog2(FSM_STATES);
localparam CLOCK_COUNTER_RELOAD    = 2*SPI_PACKET_SIZE-1;
localparam COUNTER_BITS            = $clog2(CLOCK_COUNTER_RELOAD);
localparam BITCOUNTER_BITS         = COUNTER_BITS-1;
localparam SUB_COUNTER_BITS        = $clog2(1<<(SPI_PSCLR_MAX+2)-1);

/* Ports definition */
input clk;
input rst_n;
input spi_miso;
input req;
input tx_en;
input [SPI_PACKET_SIZE-1:0] data_tx;
input [SPI_PSCLR_BITS-1:0] prescaler;

output wire spi_mosi;
output wire spi_clk;
output wire busy;
output wire [SPI_PACKET_SIZE-1:0] data_rx;

/* Internal registers */
reg spi_rising_edge;
reg tx_en_;
reg spi_clk_en;
reg rx_buf_sel;

reg [SPI_PACKET_SIZE-1:0]  tx_buffer;
reg [SPI_PACKET_SIZE-1:0]  rx_buffer[1:0];
reg [FSM_BITS-1:0]         state;
reg [SPI_PSCLR_BITS-1:0]   prescaler_;
reg [COUNTER_BITS-1:0]     clock_counter;
reg [SUB_COUNTER_BITS-1:0] sub_counter;

/* Internal wires */
wire [BITCOUNTER_BITS-1:0]  bit_counter;
wire [SUB_COUNTER_BITS-1:0] sub_counter_cap;
wire done;

/* Internal assignments */
assign spi_mosi = (spi_clk_en & tx_en_) ? tx_buffer[bit_counter] : SPI_MOSI_IDLE;
assign spi_clk = SPI_CPOL ^ (spi_clk_en && (SPI_CPHA ^ !clock_counter[0]));
assign data_rx = rx_buffer[rx_buf_sel];

assign busy = !(state == FSM_IDLE);
assign done = (clock_counter == 0) && (sub_counter == sub_counter_cap);

assign bit_counter[BITCOUNTER_BITS-1:0] = clock_counter[COUNTER_BITS-1:1];
assign sub_counter_cap = decode_prescaler(prescaler_);

/* Main FSM block */
always @ (posedge clk) begin
    if(!rst_n) begin
        state <= FSM_IDLE;
        tx_en_ <= 0;
        spi_clk_en <= 0;
        prescaler_ <= 0;
        rx_buf_sel <= 0;
        rx_buffer[0] <= 0;
        rx_buffer[1] <= 0;
    end 
    else case(state)
    FSM_IDLE: begin
        if(req) begin
            tx_en_ <= tx_en;
            tx_buffer <= data_tx;
            prescaler_ <= prescaler;
            spi_clk_en <= 1;
            state <= FSM_START;
        end
    end
    FSM_START: begin				
        if(spi_rising_edge)
            rx_buffer[!rx_buf_sel][bit_counter] <= spi_miso;
        if(done) begin
            spi_clk_en <= 0;
            rx_buf_sel <= rx_buf_sel ^ 1'd1;
            state <= FSM_IDLE;
        end
    end
    endcase
end

/* This block generates spi clock end spi edge signals */
always @ (posedge clk) begin
    if (spi_clk_en) begin
        sub_counter <= (sub_counter < sub_counter_cap) ? sub_counter + 1'd1 : 1'd0;

        if ((sub_counter == sub_counter_cap) & !done)
            clock_counter <= clock_counter - 1'd1;

        spi_rising_edge  <= (sub_counter + 1'd1 == sub_counter_cap) ?  clock_counter[0] : 1'd0;
    end
    else begin /* resetting both counters */
        clock_counter <= CLOCK_COUNTER_RELOAD[COUNTER_BITS-1:0];
        sub_counter <= 0;
        spi_rising_edge <= 0;
    end
end

/* Prescaler selection table */
function [SUB_COUNTER_BITS-1:0] decode_prescaler(input [SPI_PSCLR_BITS-1:0] prescaler);
    case (prescaler)
    SPI_PSCLR_DIV4:      decode_prescaler = 1; 
    SPI_PSCLR_DIV8:      decode_prescaler = 3; 
    SPI_PSCLR_DIV16:     decode_prescaler = 7; 
    SPI_PSCLR_DIV32:     decode_prescaler = 15; 
    SPI_PSCLR_DIV64:     decode_prescaler = 31; 
    SPI_PSCLR_DIV128:    decode_prescaler = 63; 
    SPI_PSCLR_DIV256:    decode_prescaler = 127; 
    SPI_PSCLR_DIV512:    decode_prescaler = 255;
    SPI_PSCLR_DIV1024:   decode_prescaler = 511;
    default:             decode_prescaler = 511;
    endcase
endfunction

/* Route out internal signals for debugging & validation */
`ifdef DEBUG_SPI_MASTER
output wire _spi_rising_edge;
output wire [COUNTER_BITS-1:0] _spi_clock_counter;
output wire [SUB_COUNTER_BITS-1:0] _spi_sub_counter;
output wire _spi_done;
output wire [FSM_BITS-1:0] _spi_fsm;

assign _spi_rising_edge = spi_rising_edge;
assign _spi_clock_counter = clock_counter;
assign _spi_done = done;
assign _spi_sub_counter = sub_counter;
assign _spi_fsm = state;
`endif

endmodule
