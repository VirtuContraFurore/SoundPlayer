module I2S_master #(
    parameter LEADING_BITS  = 1,
    parameter DATA_BITS     = 16,
    parameter TRAILING_BITS = 15
)(
    clk, rst_n,
    
    /* Audio codec physical pins */
    codec_aud_xck_o,
    codec_aud_bclk_o,
    codec_aud_dacdat_o,
    codec_aud_daclrck_o,
    
    /* Control signals */
    i2s_sample_data_L_i,
    i2s_sample_data_R_i,
    i2s_send_i,
    i2s_done_o
);

/* Params */
`include "../globals.v"
`include "../buffer_consts.v"

localparam XCK_CNT_BITS = $clog2(`CODEC_MCLK_DIV);  /* CODEC_MCLK_DIV is the division factor used to obtain MCLK from main clock */
localparam XCK_CNT_TOP  = `CODEC_MCLK_DIV - 1;
localparam XCK_CNT_HALF = `CODEC_MCLK_DIV/2;

localparam LAST_BIT = DATA_BITS-1;
localparam BCLK_TICKS_PER_SAMPLE = LEADING_BITS + DATA_BITS + TRAILING_BITS;

localparam BCLK_CNT_DIV  = `CODEC_MCLK_FREQ_HZ/`CODEC_FSAMPL_HZ/(BCLK_TICKS_PER_SAMPLE*2);
localparam BCLK_CNT_BITS = $clog2(BCLK_CNT_DIV);
localparam BCLK_CNT_TOP  = BCLK_CNT_DIV - 1;
localparam BCLK_CNT_HALF = BCLK_CNT_DIV/2;

localparam BCLK_TICKS_BITS = $clog2(BCLK_TICKS_PER_SAMPLE); /* Number of BCLK cycles to transmit 1 sample (left or right channel) */

localparam FSM_IDLE   = 0;
localparam FSM_SEND   = 1;
localparam FSM_STATES = 2;
localparam FSM_STATE_BITS = $clog2(FSM_STATES);

/* Ports definition */
input clk;
input rst_n;

output reg codec_aud_xck_o;
output reg codec_aud_bclk_o;
output wire codec_aud_dacdat_o;
output reg codec_aud_daclrck_o;

input [DATA_BITS-1:0] i2s_sample_data_L_i;
input [DATA_BITS-1:0] i2s_sample_data_R_i;
input i2s_send_i;
output wire i2s_done_o;

/* Private regs */
reg [XCK_CNT_BITS-1:0]    xck_counter = 0;
reg [BCLK_CNT_BITS-1:0]   bclk_counter = 0;
reg [BCLK_TICKS_BITS-1:0] bclk_ticks = 0;
reg [DATA_BITS-1:0] sample_L;
reg [DATA_BITS-1:0] sample_R; 
reg [BCLK_TICKS_BITS-1:0] data_bit;

reg [FSM_STATE_BITS-1:0] fsm_state;

/* Private wires */
wire [DATA_BITS-1:0] sample;
wire end_of_sample;

/* Private assignments */
assign i2s_done_o = fsm_state == FSM_IDLE;
assign sample = (codec_aud_daclrck_o) ? sample_L : sample_R;
assign codec_aud_dacdat_o = sample[data_bit];
assign end_of_sample = (bclk_ticks == (BCLK_TICKS_PER_SAMPLE-1))
                        && (bclk_counter == BCLK_CNT_TOP)
                        && (xck_counter == XCK_CNT_TOP);

/* Obtaining data_bit from blck_cycles */                      
always begin
    if(bclk_ticks < LEADING_BITS)
        data_bit <= DATA_BITS - 1;
    else if(bclk_ticks < LEADING_BITS + DATA_BITS - 1)
        data_bit <= LEADING_BITS + DATA_BITS - 1 - bclk_ticks;
    else
        data_bit <= 0;
end
                        
/* Main FSM */
always @ (posedge clk) begin
    if(!rst_n) begin
        fsm_state <= FSM_IDLE;
        codec_aud_daclrck_o <= 0;
    end else case(fsm_state)
        FSM_IDLE: begin
            if(i2s_send_i) begin
                fsm_state <= FSM_SEND;
                sample_L <= i2s_sample_data_L_i;
                sample_R <= i2s_sample_data_R_i;
                codec_aud_daclrck_o <= 0;
            end
        end
        FSM_SEND: begin
            codec_aud_daclrck_o <= codec_aud_daclrck_o ^ end_of_sample;
            
            if(codec_aud_daclrck_o & end_of_sample) begin            
                if(i2s_send_i) begin
                    sample_L <= i2s_sample_data_L_i;
                    sample_R <= i2s_sample_data_R_i;
                end
                
                fsm_state <= (i2s_send_i) ? fsm_state : FSM_IDLE;
            end
        end
    endcase
end

/* XCK and BCK clock generation */
always @ (posedge clk) begin
    if(!rst_n) begin
        xck_counter <= 0;
        bclk_counter <= 0;
        bclk_ticks <= 0;
        codec_aud_xck_o <= 0;
        codec_aud_bclk_o <= 0;
    end else begin
        xck_counter <= (xck_counter < XCK_CNT_TOP)  ? xck_counter + 1'b1 : 0;
        codec_aud_xck_o <= (xck_counter < XCK_CNT_TOP) && (xck_counter > (XCK_CNT_HALF-2)); 
 
        if(!i2s_done_o && xck_counter == XCK_CNT_TOP) begin
            bclk_counter     <= (bclk_counter < BCLK_CNT_TOP)  ? bclk_counter + 1'b1 : 0;
            codec_aud_bclk_o <= (bclk_counter < BCLK_CNT_TOP) && (bclk_counter > (BCLK_CNT_HALF-2));
            
            if(bclk_counter == BCLK_CNT_TOP)
                bclk_ticks <= bclk_ticks + 1'b1;
        end
    end
end 

endmodule