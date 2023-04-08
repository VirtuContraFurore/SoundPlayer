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
    codec_buffer_empty_o,
        
    /* WAV info interface */
    wav_info_sampling_rate_i,
    wav_info_audio_channels_i
);

/* Params */
`include "../buffer_consts.v"

/* Ports definition */
input clk;
input rst_n;

output wire codec_aud_xck_o;
output wire codec_aud_bclk_o;
output wire codec_aud_dacdat_o;
output wire codec_aud_daclrck_o;

output wire codec_i2c_sclk_o;
inout wire codec_i2c_sdat_io;

output wire [BUFFER_ADDR_BITS-1:0] codec_buffer_addr_o;
output wire codec_buffer_sel_o;
input wire [7:0] codec_buffer_data_i;
input wire codec_buffer_filled_i;
output wire codec_buffer_empty_o;

input wire [7:0] wav_info_audio_channels_i;
input wire [31:0] wav_info_sampling_rate_i;

/* Private wires */

/* Private regs */

/* Private instances */

endmodule