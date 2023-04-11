/* 
 * FAT32 reader private constants
 * This file must NOT be compiled alone!
 * For this file, set Properties... -> Type to 'Macro File'
 */

/* Main FSM states */
parameter FSM_READ_MBR_0            = 0;
parameter FSM_READ_MBR_1            = 1;
parameter FSM_READ_MBR_2            = 2;
parameter FSM_NO_FAT_FOUND          = 3;
parameter FSM_READ_FAT_0            = 4;
parameter FSM_READ_FAT_1            = 5;
parameter FSM_READ_FAT_2            = 6;
parameter FSM_PARSE_FILE_ENTRY_0    = 7;
parameter FSM_PARSE_FILE_ENTRY_1    = 8;
parameter FSM_PARSE_WAV_FILE_0      = 9;
parameter FSM_PARSE_WAV_FILE_1      = 10; 
parameter FSM_PARSE_WAV_FILE_2      = 11; 
parameter FSM_PARSE_WAV_FILE_3      = 12; 
parameter FSM_PARSE_WAV_FILE_4      = 13; 
parameter FSM_PARSE_WAV_FILE_5      = 14;
parameter FSM_PARSE_WAV_FILE_6      = 15; 
parameter FSM_PARSE_WAV_FILE_7      = 16;
parameter FSM_PARSE_WAV_FILE_8      = 17;
parameter FSM_WAIT_BUFFER_0         = 18;
parameter FSM_WAIT_BUFFER_1         = 19;
parameter FSM_STATES                = 20; 
parameter FSM_BITS         = $clog2(FSM_STATES);


/* Misc */
parameter MBR_PART_ENTRY = 9'h1BE;
parameter MBR_FAT32_CHS_LBA = 8'h0B;
parameter MBR_FAT32_LBA     = 8'h0C;

parameter FAT32_PAR_BLOCK = 9'h00B;

parameter FAT32_CLUSTER_MASK      = 32'h0fffffff;
parameter FAT32_LAST_CLUSTER_MASK = 32'h0ffffff0;

parameter DIR_ENTRY_SIZE  = 32;
parameter DIR_ENTRY_SHIFT = 5'd5;
parameter FILE_ATTR_SUBDIRECTORY_BIT = 4;
