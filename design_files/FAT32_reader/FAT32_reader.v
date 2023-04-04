module FAT32_reader(
    clk, rst_n,
    
    /* Block read interface */
    block_read_trigger,
    block_read_card_ready,
    block_read_continous_mode,
    block_read_block_addr,
    block_read_data_in,
    block_read_data_idx,
    block_read_data_new_flag,
    
    /* Buffer interface */
    audio_buffer_addr_o,
    audio_buffer_wren_o,
    audio_buffer_data_o,
    audio_buffer_filled_o,
    audio_buffer_empty_i,
        
    /* WAV info interface */
    wav_info_sampling_rate,
    wav_info_audio_channels,
    
    /* Status */
    error_no_fat_found
);

/* Parameters */
`include "../globals.v"
`include "FAT32_reader_private.v"
`include "../SDCard_reader/SDCard_reader_consts.v"
`include "../buffer_consts.v"

/* Ports definition */
input clk;
input rst_n;

input block_read_card_ready;
input block_read_data_new_flag;
input [7:0] block_read_data_in;
input [SD_BLOCK_LENGHT_BITS-1:0] block_read_data_idx;
output wire block_read_trigger;
output wire block_read_continous_mode;
output wire [SD_BLOCK_ADDR_BITS-1:0] block_read_block_addr;
output wire error_no_fat_found;

input audio_buffer_empty_i;
output reg [8:0] audio_buffer_data_o = 0;
output reg [BUFFER_ADDR_BITS-1:0] audio_buffer_addr_o = 0;
output reg audio_buffer_wren_o = 0;
output reg audio_buffer_filled_o = 0;

output wire [31:0] wav_info_sampling_rate;
output wire [ 7:0] wav_info_audio_channels;

/* Private regs */
reg [FSM_BITS-1:0] fsm_state = 0;

reg card_req = 0;
reg card_single = 1;
reg [SD_BLOCK_ADDR_BITS-1:0] card_addr = 0;

/* From MBR: */
reg [31:0] fat32_start = 0; /* Partition start */

/* From FAT32's partition boot sector: */
reg [15:0] fat32_bytes_per_sector = 0;
reg [ 7:0] fat32_sectors_per_cluster = 0;
reg [15:0] fat32_reserved_sectors = 0;
reg [ 7:0] fat32_number_of_fats = 0;
reg [31:0] fat32_sectors_per_fat = 0;
reg [31:0] fat32_root_cluster_number = 0;

/* FAT32 directory entry (only entries of root cluster are inspected) */
reg [11:0] dir_entry_idx = 0; /* Pointer to current directory entry of root cluster */

reg [7:0] file_name_ch0 = 0;
reg [7:0] file_ext [3:0]; /* file extension */
reg [7:0] file_attributes = 0;
reg [31:0] file_first_cluster = 0; 
reg [31:0] file_size_bytes = 0;
reg [31:0] file_current_cluster = 0;
reg [SD_BLOCK_LENGHT_BITS-1:0] file_current_cluster_index = 0;

/* Counter used when reading clusters. Counts from 0 to fat32_sectors_per_cluster-1. */
reg [7:0] sector_count = 0;

/* WAV file fields */
reg [ 7:0] wav_file_chunk_id[3:0];
reg [ 7:0] wav_file_format[3:0];
reg [ 7:0] wav_file_subchunk1_id[3:0];
reg [15:0] wav_audio_format = 0;
reg [15:0] wav_num_channels = 0;
reg [31:0] wav_sample_rate = 0;
reg [ 7:0] wav_file_subchunk2_id[3:0];
reg [31:0] wav_file_subchunk2_size = 0;
reg [31:0] wav_byte_counter = 0;

/* Useful variables */
wire [31:0] fat32_fat_region_start;
wire [31:0] fat32_data_region_start;
wire [11:0] dir_entry_idx_max;

/* Private wires */
wire card_ready;
wire card_new_data;
wire [SD_BLOCK_LENGHT_BITS-1:0] card_data_idx;
wire [7:0] card_data;
wire file_good;
wire wav_chunk_ok;
wire wav_sample_rate_ok;
wire wav_channels_ok;
wire wav_data_chunk_ok;
wire wav_audio_format_ok;

/* Private assignments */
assign block_read_trigger = card_req;
assign block_read_continous_mode = !card_single;
assign block_read_block_addr = card_addr;
assign card_ready = block_read_card_ready;
assign card_new_data = block_read_data_new_flag;
assign card_data_idx = block_read_data_idx;
assign card_data = block_read_data_in;
assign error_no_fat_found = (fsm_state == FSM_NO_FAT_FOUND);

assign fat32_fat_region_start = fat32_start + fat32_reserved_sectors;
assign fat32_data_region_start = fat32_fat_region_start + (fat32_sectors_per_fat << highest_bit(fat32_number_of_fats));

assign dir_entry_idx_max = fat32_bytes_per_sector << (highest_bit(fat32_sectors_per_cluster) - DIR_ENTRY_SHIFT);

assign file_good = (file_attributes[FILE_ATTR_SUBDIRECTORY_BIT] == 0) && 
                   (file_ext[0] == "W") && (file_ext[1] == "A") && (file_ext[2] == "V");
                   
assign wav_chunk_ok = (wav_file_chunk_id[0] == "R") && (wav_file_chunk_id[1] == "I") &&
                      (wav_file_chunk_id[2] == "F") && (wav_file_chunk_id[3] == "F") &&
                      (wav_file_format[0] == "W") && (wav_file_format[1] == "A") &&
                      (wav_file_format[2] == "V") && (wav_file_format[3] == "E") &&
                      (wav_file_subchunk1_id[0] == "f") && (wav_file_subchunk1_id[1] == "m") &&
                      (wav_file_subchunk1_id[2] == "t") && (wav_file_subchunk1_id[3] == " ");
assign wav_channels_ok = wav_num_channels == 1; // || wav_num_channels == 2; // TODO: future improvement
assign wav_audio_format_ok = wav_audio_format == 1;
assign wav_sample_rate_ok = wav_sample_rate == 32'd44100;
assign wav_data_chunk_ok = (wav_file_subchunk2_id[0] == "d") && (wav_file_subchunk2_id[1] == "a") &&
                           (wav_file_subchunk2_id[2] == "t") && (wav_file_subchunk2_id[3] == "a");

                   
/* Compute address of a given cluster */
`define CLUSTER_ADDR(cluster) (fat32_data_region_start + (((cluster)-2) << highest_bit(fat32_sectors_per_cluster)))

/* Compute address of fat table's sector of interest = start + cluster * 4 / fat32_bytes_per_sector */
`define FAT_TABLE_ADDR(cluster) (fat32_fat_region_start + ((cluster) >> (highest_bit(fat32_bytes_per_sector) - 5'd2)))

/* Compute address of directory entry = start + entry_index * 32 / fat32_bytes_per_sector */
`define ROOT_ENTRY_ADDR(entry_index) (fat32_data_region_start + ((entry_index) >> (highest_bit(fat32_bytes_per_sector) - DIR_ENTRY_SHIFT)))

/* Macro to read a single FAT sector (which is equal to an SD sector for our purposes) */
`define READ_SINGLE_SECT(sect_addr, next_state) begin card_req <= card_ready; card_addr <= (sect_addr); card_single <= 1'b1; fsm_state <= (card_ready) ? fsm_state : (next_state); end

/* Macro to read a sequetial FAT sector (which is equal to an SD sector for our purposes) */
`define READ_MULTI_SECT(sect_addr, next_state) begin card_req <= 1'b1; card_addr <= (sect_addr); card_single <=1'b0; fsm_state <= (card_ready) ? fsm_state : (next_state); sector_count <= 0; end

always @(posedge clk) begin
    if(!rst_n) begin
        fsm_state <= FSM_READ_MBR_0;
        card_req <= 0;
        card_addr <= 0;
        card_single <= 1'b1;
    end 
    else case (fsm_state)
    
    /* Read MBR */
    FSM_READ_MBR_0: begin
        fsm_state <= (card_ready) ? FSM_READ_MBR_1 : fsm_state;
    end
    FSM_READ_MBR_1: `READ_SINGLE_SECT(0, FSM_READ_MBR_2)
    FSM_READ_MBR_2: begin
        if(card_new_data) begin
            case(card_data_idx)
            MBR_PART_ENTRY+9'h04: if((card_data != MBR_FAT32_CHS_LBA) && (card_data != MBR_FAT32_LBA)) fsm_state <= FSM_NO_FAT_FOUND;
            MBR_PART_ENTRY+9'h08: fat32_start[ 7: 0] <= card_data;
            MBR_PART_ENTRY+9'h09: fat32_start[15: 8] <= card_data;
            MBR_PART_ENTRY+9'h0a: fat32_start[23:16] <= card_data;
            MBR_PART_ENTRY+9'h0b: fat32_start[31:24] <= card_data;
            endcase
        end
        if(card_ready) begin
            fsm_state <= FSM_READ_FAT_0;
        end
    end

    /* Read FAT finite state machine */
    FSM_READ_FAT_0: `READ_SINGLE_SECT(fat32_start, FSM_READ_FAT_1)
    FSM_READ_FAT_1: begin
        if(card_new_data) begin
            case(card_data_idx)
            FAT32_PAR_BLOCK+9'h00: fat32_bytes_per_sector[ 7: 0] <= card_data;
            FAT32_PAR_BLOCK+9'h01: fat32_bytes_per_sector[15: 8] <= card_data;
            FAT32_PAR_BLOCK+9'h02: fat32_sectors_per_cluster[ 7:0] <= card_data;
            FAT32_PAR_BLOCK+9'h03: fat32_reserved_sectors[ 7: 0] <= card_data;
            FAT32_PAR_BLOCK+9'h04: fat32_reserved_sectors[15: 8] <= card_data;
            FAT32_PAR_BLOCK+9'h05: fat32_number_of_fats[ 7: 0] <= card_data;
            FAT32_PAR_BLOCK+9'h19: fat32_sectors_per_fat[ 7: 0] <= card_data;
            FAT32_PAR_BLOCK+9'h1A: fat32_sectors_per_fat[15: 8] <= card_data;
            FAT32_PAR_BLOCK+9'h1B: fat32_sectors_per_fat[23:16] <= card_data;
            FAT32_PAR_BLOCK+9'h1C: fat32_sectors_per_fat[31:24] <= card_data;
            FAT32_PAR_BLOCK+9'h21: fat32_root_cluster_number[ 7: 0] <= card_data;
            FAT32_PAR_BLOCK+9'h22: fat32_root_cluster_number[15: 8] <= card_data;
            FAT32_PAR_BLOCK+9'h23: fat32_root_cluster_number[23:16] <= card_data;
            FAT32_PAR_BLOCK+9'h24: fat32_root_cluster_number[31:24] <= card_data;
            endcase
        end
        if(card_ready) begin
            fsm_state <= FSM_READ_FAT_2;
        end
    end
    FSM_READ_FAT_2: begin
        dir_entry_idx <= 0;
        fsm_state <= FSM_PARSE_FILE_ENTRY_0;
    end
    
    /* Read directory entries */
    FSM_PARSE_FILE_ENTRY_0: `READ_SINGLE_SECT( `ROOT_ENTRY_ADDR(dir_entry_idx), FSM_PARSE_FILE_ENTRY_1)
    FSM_PARSE_FILE_ENTRY_1: begin
        if(card_new_data) begin
            case(card_data_idx)
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h00: file_name_ch0 <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h08: file_ext[0] <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h09: file_ext[1] <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h0A: file_ext[2] <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h0B: file_attributes <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h14: file_first_cluster[23:16] <= card_data; 
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h15: file_first_cluster[31:24] <= card_data; 
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1A: file_first_cluster[ 7: 0] <= card_data; 
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1B: file_first_cluster[15: 8] <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1C: file_size_bytes[ 7: 0] <= card_data; 
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1D: file_size_bytes[15: 8] <= card_data;
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1E: file_size_bytes[23:16] <= card_data; 
            dir_entry_idx * DIR_ENTRY_SIZE + 9'h1F: file_size_bytes[31:24] <= card_data;
            endcase
        end
        if(card_ready) begin
            file_current_cluster = file_first_cluster;
            if(file_name_ch0 == 0) begin /* That was last file entry, return to first */
                dir_entry_idx <= 0;
                fsm_state <= FSM_PARSE_FILE_ENTRY_0;
            end else begin
                dir_entry_idx = (dir_entry_idx != (dir_entry_idx_max - 1'b1)) ? dir_entry_idx + 1'b1: 0;
                fsm_state = (file_good) ? FSM_PARSE_WAV_FILE_0 : FSM_PARSE_FILE_ENTRY_0;
            end
        end
    end
    
    /* Parse WAV file */
    FSM_PARSE_WAV_FILE_0: `READ_MULTI_SECT( `CLUSTER_ADDR(file_first_cluster), FSM_PARSE_WAV_FILE_1)
    FSM_PARSE_WAV_FILE_1: begin
        if(card_new_data) begin
            case(card_data_idx)
            9'h00: wav_file_chunk_id[0] = card_data;
            9'h01: wav_file_chunk_id[1] = card_data;
            9'h02: wav_file_chunk_id[2] = card_data;
            9'h03: wav_file_chunk_id[3] = card_data;
            9'h08: wav_file_format[0] = card_data;
            9'h09: wav_file_format[1] = card_data;
            9'h0A: wav_file_format[2] = card_data;
            9'h0B: wav_file_format[3] = card_data;
            9'h0C: wav_file_subchunk1_id[0] = card_data;
            9'h0D: wav_file_subchunk1_id[1] = card_data;
            9'h0E: wav_file_subchunk1_id[2] = card_data;
            9'h0F: wav_file_subchunk1_id[3] = card_data;
            9'h14: wav_audio_format[ 7:0] = card_data;
            9'h15: wav_audio_format[15:8] = card_data;
            9'h16: wav_num_channels[ 7:0] = card_data;
            9'h17: wav_num_channels[15:8] = card_data;
            9'h18: wav_sample_rate[ 7: 0] = card_data;
            9'h19: wav_sample_rate[15: 8] = card_data;
            9'h1A: wav_sample_rate[23:16] = card_data;
            9'h1B: wav_sample_rate[31:24] = card_data;
            9'h24: wav_file_subchunk2_id[0] = card_data;
            9'h25: wav_file_subchunk2_id[1] = card_data;
            9'h26: wav_file_subchunk2_id[2] = card_data;
            9'h27: wav_file_subchunk2_id[3] = card_data;
            9'h28: wav_file_subchunk2_size[ 7: 0] = card_data;
            9'h29: wav_file_subchunk2_size[15: 8] = card_data;
            9'h2A: wav_file_subchunk2_size[23:16] = card_data;
            9'h2B: begin
                        wav_file_subchunk2_size[31:24] = card_data;
                        wav_byte_counter <= 0;
                        if(wav_chunk_ok && wav_sample_rate_ok && wav_channels_ok && wav_data_chunk_ok && wav_audio_format_ok)
                            fsm_state <= FSM_PARSE_WAV_FILE_2;
                        else
                            fsm_state <= FSM_PARSE_WAV_FILE_7;
                   end
            endcase
        end
    end
    FSM_PARSE_WAV_FILE_2:  begin
        if(card_new_data) begin
            if(wav_byte_counter < wav_file_subchunk2_size) begin
                /* TODO: Put card_data in buffer if empty and signal data to buffer */
                wav_byte_counter = wav_byte_counter + 1'b1;
            end
            
            if(card_data_idx == SD_LAST_BLOCK_BYTE) begin
                sector_count <= sector_count + 1'b1;
                card_req <= (sector_count  + 1'b1) < fat32_sectors_per_cluster;
            end
        end
        
        if(card_ready && (sector_count == fat32_sectors_per_cluster))
            fsm_state <= FSM_PARSE_WAV_FILE_3;
    end
    FSM_PARSE_WAV_FILE_3: begin
        `READ_SINGLE_SECT( `FAT_TABLE_ADDR(file_current_cluster), FSM_PARSE_WAV_FILE_4)
        file_current_cluster_index <= file_current_cluster << 2;
        end
    FSM_PARSE_WAV_FILE_4: begin
        if(card_new_data) begin
            case (card_data_idx)
            file_current_cluster_index + 9'h00: file_current_cluster[ 7: 0] = card_data;
            file_current_cluster_index + 9'h01: file_current_cluster[15: 8] = card_data;
            file_current_cluster_index + 9'h02: file_current_cluster[23:16] = card_data;
            file_current_cluster_index + 9'h03: file_current_cluster[31:24] = card_data;
            endcase
        end
        if(card_ready) begin
            file_current_cluster = file_current_cluster & FAT32_CLUSTER_MASK; /* Clear highest nibble since it must be ignored */
            if((file_current_cluster & FAT32_LAST_CLUSTER_MASK) == FAT32_LAST_CLUSTER_MASK)
                fsm_state <= FSM_PARSE_WAV_FILE_5;
            else
                fsm_state <= FSM_PARSE_WAV_FILE_6;
        end
    end
    FSM_PARSE_WAV_FILE_5: begin /* End of file reached */
        //TODO: fsm_state <= FSM_PARSE_FILE_ENTRY_0; /* Go to next file entry */
    end
    FSM_PARSE_WAV_FILE_6: `READ_MULTI_SECT( `CLUSTER_ADDR(file_current_cluster), FSM_PARSE_WAV_FILE_2) /* Stard reading next cluster */
    FSM_PARSE_WAV_FILE_7: begin /* Error in WAV file header */
        card_single <= 1;
        card_req <= 0;
        fsm_state <= (card_ready) ? FSM_PARSE_FILE_ENTRY_0 : fsm_state; /* Skip this file and go to next file entry */
    end
    endcase
end

function automatic [4:0] highest_bit (input reg [31:0] data);
    reg [5:0] i;
    highest_bit = 0;
    for(i = 0; i < 6'd32; i = i + 6'b1) begin
        if(data[i] == 1'b1)
          highest_bit = i[4:0];
    end
endfunction

endmodule