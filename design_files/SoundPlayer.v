module SoundPlayer(
    CLOCK_50,
    
    /* General purpose DE2 board features */
    KEY,
    SW,
    LEDR,
    LEDG,
    GPIO_0,
    GPIO_1,
    
    /* SD Card physical pins */
    SD_DO,
    SD_DI,
    SD_SCLOCK,
    SD_CS,
    
    /* Audio codec physical pins */
    AUD_XCK,
    AUD_BCLK,
    AUD_DACDAT,
    AUD_DACLRCK,
    
    /* shared I2C bus */
    I2C_SCLK,
    I2C_SDAT
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

output wire AUD_XCK;
output wire AUD_BCLK;
output wire AUD_DACDAT;
output wire AUD_DACLRCK;

output wire I2C_SCLK;
inout  wire I2C_SDAT;

/* Parameters */
`include "globals.v"
`include "SDCard_reader/SDCard_reader_consts.v"
`include "buffer_consts.v"

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

wire ram_wren;
wire [7:0] ram_wr_data;
wire [7:0] ram_rd_data;
wire [RAM_ADDR_BITS-1:0] ram_wr_address;
wire [RAM_ADDR_BITS-1:0] ram_rd_address;

wire buffer_active_sel;
wire [BUFFER_ADDR_BITS-1:0] buffer_wr_address;
wire [BUFFER_ADDR_BITS-1:0] buffer_rd_address;

wire audio_buffer_empty;
wire audio_buffer_empty_ack;
wire audio_buffer_filled;

wire [31:0] wav_info_sampling_rate;
wire [ 7:0] wav_info_audio_channels;

wire player_next_song_req_ack;

/* Internal regs */
reg pause_song = 0;
reg key0_pressed = 0;
reg key12_pressed = 0;
reg player_next_song_req = 0;
reg player_next_song_forward = 0;

/* Internal assignments */
assign rst_n = !(`BUTTON_RST); /* Reset is active low */

/* Logic Analyzer debug routing */
assign GPIO_0[0] = SD_SCLOCK;
assign GPIO_0[1] = SD_DO;
assign GPIO_0[2] = SD_DI;
assign GPIO_0[3] = SD_CS;
assign GPIO_0[4] = SW[1] ? block_read_trigger : audio_buffer_filled;
assign GPIO_0[5] = SW[0] ? audio_buffer_filled : AUD_DACLRCK;
assign GPIO_0[6] = SW[0] ? I2C_SCLK : AUD_BCLK;
assign GPIO_0[7] = SW[0] ? I2C_SDAT : AUD_DACDAT;

/* Status LED */
assign LEDR[3] = buffer_active_sel;
assign LEDR[2] = audio_buffer_filled;
assign LEDR[1] = audio_buffer_empty;
assign LEDR[0] = audio_buffer_empty_ack;

assign LEDG[4] = key12_pressed;
assign LEDG[3] = pause_song;
assign LEDG[2] = !error_no_fat_found & sd_configured; /* no fat found flag valid only if card configured */
assign LEDG[1] = block_read_card_ready;
assign LEDG[0] = sd_configured;

/* Double buffer and RAM address translation */
assign ram_rd_address[BUFFER_ADDR_BITS-1:0] = buffer_rd_address;
assign ram_wr_address[BUFFER_ADDR_BITS-1:0] = buffer_wr_address;
assign ram_rd_address[BUFFER_ADDR_BITS] = buffer_active_sel;
assign ram_wr_address[BUFFER_ADDR_BITS] = !buffer_active_sel;

MAIN_PLL main_pll(
    .inclk0(CLOCK_50),
    .c0(clk) /* Set clk to 200 MHz */
);

Codec codec (
    .clk(clk),
    .rst_n(rst_n),
    .codec_pause_i(pause_song),
    
    /* Audio codec physical pins */
    .codec_aud_xck_o(AUD_XCK),
    .codec_aud_bclk_o(AUD_BCLK),
    .codec_aud_dacdat_o(AUD_DACDAT),
    .codec_aud_daclrck_o(AUD_DACLRCK),
    
    /* shared I2C bus */
    .codec_i2c_sclk_o(I2C_SCLK),
    .codec_i2c_sdat_io(I2C_SDAT),
    
    /* Buffer interface */
    .codec_buffer_addr_o(buffer_rd_address),
    .codec_buffer_sel_o(buffer_active_sel),
    .codec_buffer_data_i(ram_rd_data),
    .codec_buffer_filled_i(audio_buffer_filled),
    .codec_buffer_empty_o(audio_buffer_empty),
    .codec_buffer_empty_ack_i(audio_buffer_empty_ack),
        
    /* WAV info interface */
    .wav_info_sampling_rate_i(wav_info_sampling_rate),
    .wav_info_audio_channels_i(wav_info_audio_channels)
);

RAM_dualport ram_dualport (
	.clock(!clk), /* RAM writes on rising edge if clk not inverted */
	.data(ram_wr_data),
	.rdaddress(ram_rd_address),
	.wraddress(ram_wr_address),
	.wren(ram_wren),
	.q(ram_rd_data)
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
    .error_no_fat_found(error_no_fat_found),
    
    /* Buffer interface */
    .audio_buffer_addr_o(buffer_wr_address),
    .audio_buffer_wren_o(ram_wren),
    .audio_buffer_data_o(ram_wr_data),
    .audio_buffer_filled_o(audio_buffer_filled),
    .audio_buffer_empty_i(audio_buffer_empty),
    .audio_buffer_empty_ack_o(audio_buffer_empty_ack),
    
    /* WAV info interface */
    .wav_info_sampling_rate(wav_info_sampling_rate),
    .wav_info_audio_channels(wav_info_audio_channels),
    
    /* Player ctrl */
    .player_next_song_req_i(player_next_song_req),
    .player_next_song_req_ack_o(player_next_song_req_ack),
    .player_next_song_forward_i(player_next_song_forward)
);

/* Push button KEY0 event */
always @ (posedge clk) begin
    if(!rst_n) begin
        pause_song <= 0;
        key0_pressed <= 0;
    end else begin
        if(`BUTTON_PAUSE && !key0_pressed) begin
            pause_song <= !pause_song;
            key0_pressed <= 1'b1;
        end else if(!`BUTTON_PAUSE) begin
            key0_pressed <= 0;
        end
    end
end

/* Push button KEY1 and KEY2 event */
always @ (posedge clk) begin
    if(!rst_n) begin
        key12_pressed <= 0;
    end else begin
        if((`BUTTON_NEXT || `BUTTON_PREV) && !key12_pressed) begin
            player_next_song_req <= 1'b1;
            player_next_song_forward <= `BUTTON_NEXT;
            key12_pressed <= 1'b1;
        end else begin
            if(!`BUTTON_NEXT && !`BUTTON_PREV)
                key12_pressed <= 0;
            if(player_next_song_req_ack)
                player_next_song_req <= 0;
        end
    end
end

endmodule

