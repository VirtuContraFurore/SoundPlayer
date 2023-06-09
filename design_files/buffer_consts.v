/* 
 * Buffer constants
 * This file must NOT be compiled alone!
 * For this file, set Properties... -> Type to 'Macro File'
 */
 
parameter RAM_SIZE_BYTES    = 16384;
parameter BUFFER_SIZE_BYTES = (RAM_SIZE_BYTES/2);

parameter RAM_ADDR_BITS    = $clog2(RAM_SIZE_BYTES);
parameter BUFFER_ADDR_BITS = $clog2(BUFFER_SIZE_BYTES);

parameter RAM_READ_WAIT_STATES = 1;
parameter RAM_READ_WAIT_STATES_BITS = $clog2(RAM_READ_WAIT_STATES+1);
