/* 
 * SD Card reader public constants
 * This file must NOT be compiled alone!
 * For this file, set Properties... -> Type to 'Macro File'
 */

localparam SD_BLOCK_ADDR_BITS    = 32;
localparam SD_BLOCK_LENGHT_BYTES = 512;
localparam SD_LAST_BLOCK_BYTE    = SD_BLOCK_LENGHT_BYTES-1;
localparam SD_BLOCK_LENGHT_BITS  = $clog2(SD_BLOCK_LENGHT_BYTES);