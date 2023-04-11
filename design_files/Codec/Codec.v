module Codec (
    clk, rst_n,
    
    /* Audio codec physical pins */
    codec_aud_xck_o,
    codec_aud_bclk_o,
    codec_aud_dacdat_o,
    codec_aud_daclrck_o,
    
    /* shared I2C bus */
    codec_i2c_sclk_o,
    codec_i2c_sdat_io,
    
    /* Buffer interface */
    codec_buffer_addr_o,
    codec_buffer_sel_o,
    codec_buffer_data_i,
    codec_buffer_filled_i,
    codec_buffer_empty_ack_i,
    codec_buffer_empty_o,
        
    /* WAV info interface */
    wav_info_sampling_rate_i,
    wav_info_audio_channels_i
);

/* Params */
`include "../buffer_consts.v"
localparam DAC_BITS = 16;

localparam FSM_WAIT_BUFFER_0    = 0;
localparam FSM_WAIT_BUFFER_1    = 1;
localparam FSM_CONSUMING_BUFFER = 2;
localparam FSM_WAIT_I2S         = 3;
localparam FSM_STATES           = 4;
localparam FSM_STATE_BITS       = $clog2(FSM_STATES);

/* Ports definition */
input clk;
input rst_n;

output wire codec_aud_xck_o;
output wire codec_aud_bclk_o;
output wire codec_aud_dacdat_o;
output wire codec_aud_daclrck_o;

output wire codec_i2c_sclk_o;
inout wire codec_i2c_sdat_io;

input codec_buffer_filled_i;
input codec_buffer_empty_ack_i;
input [7:0] codec_buffer_data_i;
output reg [BUFFER_ADDR_BITS-1:0] codec_buffer_addr_o;
output reg codec_buffer_sel_o;
output reg codec_buffer_empty_o;

input wire [7:0] wav_info_audio_channels_i;
input wire [31:0] wav_info_sampling_rate_i;

/* Private wires */
wire i2s_done;
wire sample_cnt_top;
wire buffer_is_over;
wire swap_buffers;

/* Private regs */
reg i2s_send = 0;
reg [DAC_BITS-1:0] data_R = 0;
reg [DAC_BITS-1:0] data_L = 0;
reg [1:0] sample_cnt = 0;
reg [FSM_STATE_BITS-1:0] fsm_state = 0;

/* Private assignments */
assign sample_cnt_top = (2 * wav_info_audio_channels_i) - 1;
assign buffer_is_over = codec_buffer_addr_o == BUFFER_SIZE_BYTES-1;
assign swap_buffers   = buffer_is_over && codec_buffer_filled_i;

/* Private instances */
Codec_config conf (
    .clk(clk),
    .rst_n(rst_n),
    .i2c_sclk(codec_i2c_sclk_o),
    .i2c_sdat(codec_i2c_sdat_io)
);

I2S_master #(
    .LEADING_BITS(1),
    .DATA_BITS(DAC_BITS),
    .TRAILING_BITS(15)
) i2s (
    .clk(clk), 
    .rst_n(rst_n),
    
    /* Audio codec physical pins */
    .codec_aud_xck_o(codec_aud_xck_o),
    .codec_aud_bclk_o(codec_aud_bclk_o),
    .codec_aud_dacdat_o(codec_aud_dacdat_o),
    .codec_aud_daclrck_o(codec_aud_daclrck_o),
    
    /* Control signals */
    .i2s_sample_data_L_i(data_L),
    .i2s_sample_data_R_i(data_R),
    .i2s_send_i(i2s_send),
    .i2s_done_o(i2s_done)
);

/* Main FSM */
always @ (posedge clk) begin
    if(!rst_n) begin
        codec_buffer_sel_o <= 0;
        codec_buffer_empty_o <= 0;
        codec_buffer_addr_o <= 0;
        fsm_state <= FSM_WAIT_BUFFER_0;
    end else case(fsm_state)
        FSM_WAIT_BUFFER_0: begin
            codec_buffer_empty_o <= !codec_buffer_empty_ack_i;
            fsm_state <= (codec_buffer_empty_ack_i) ? FSM_WAIT_BUFFER_1 : fsm_state;
        end
        FSM_WAIT_BUFFER_1: begin
            if(i2s_done)
                i2s_send <= 0;
            if(codec_buffer_filled_i) begin
                codec_buffer_sel_o <= codec_buffer_sel_o ^ 1;
                codec_buffer_empty_o <= 1'b1;
                codec_buffer_addr_o <= 0; 
                sample_cnt <= 0;
                fsm_state <= FSM_CONSUMING_BUFFER;
            end
        end
        FSM_CONSUMING_BUFFER: begin
            codec_buffer_empty_o <= !codec_buffer_empty_ack_i & (swap_buffers | codec_buffer_empty_o);
            codec_buffer_sel_o   <= codec_buffer_sel_o ^ swap_buffers;
          
            codec_buffer_addr_o <= codec_buffer_addr_o + 1'b1;
            sample_cnt          <= (sample_cnt < sample_cnt_top) ? sample_cnt + 1'b1 : 0;
            
            i2s_send <= i2s_send | (sample_cnt == sample_cnt_top);
            
            case(sample_cnt)
                0: begin data_L[ 7:0] <= codec_buffer_data_i; data_R[ 7:0] <= codec_buffer_data_i; end
                1: begin data_L[15:8] <= codec_buffer_data_i; data_R[15:8] <= codec_buffer_data_i; end
                2: data_R[ 7:0] <= codec_buffer_data_i;
                3: data_R[15:8] <= codec_buffer_data_i;
            endcase
            
            if(sample_cnt == sample_cnt_top) begin                    
                if(buffer_is_over && !codec_buffer_filled_i)
                    fsm_state <= FSM_WAIT_BUFFER_1;
                else
                    fsm_state <= (!i2s_done) ? FSM_WAIT_I2S : fsm_state;
            end
        end
        FSM_WAIT_I2S: begin
            if(codec_buffer_empty_ack_i)
                codec_buffer_empty_o <= 0;

            fsm_state <= (i2s_done) ? FSM_CONSUMING_BUFFER : fsm_state;
        end
    endcase
end


endmodule