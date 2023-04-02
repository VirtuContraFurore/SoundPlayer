/* 
 * SD Card reader constants
 * This file must NOT be compiled alone!
 * For this file, set Properties... -> Type to 'Macro File'
 */

/* Main FSM States */
localparam FSM_CARD_NOT_READY      = 0;
localparam FSM_CONFIGURING_CARD_1  = 1;
localparam FSM_CONFIGURING_CARD_2  = 2;
localparam FSM_CONFIGURING_CARD_3  = 3;
localparam FSM_CONFIGURING_CARD_4  = 4;
localparam FSM_CONFIGURING_CARD_5  = 5;
localparam FSM_CONFIGURING_CARD_6  = 6;
localparam FSM_CONFIGURING_CARD_7  = 7;
localparam FSM_CONFIGURING_CARD_8  = 8;
localparam FSM_CONFIGURING_CARD_9  = 9;
localparam FSM_CONFIGURING_CARD_10 = 10;
localparam FSM_RUN_CMD_0           = 11;
localparam FSM_RUN_CMD_1           = 12;
localparam FSM_CARD_READY          = 13;
localparam FSM_CARD_BUSY_0         = 14;
localparam FSM_CARD_BUSY_1         = 15;
localparam FSM_CARD_BUSY_2         = 16;
localparam FSM_CARD_BUSY_3         = 17;
localparam FSM_CARD_BUSY_4         = 18;
localparam FSM_CARD_BUSY_CRC_1     = 19;
localparam FSM_CARD_BUSY_CRC_2     = 20;
localparam FSM_CARD_BUSY_CRC_3     = 21;
localparam FSM_CARD_BUSY_STOP_1    = 22;
localparam FSM_CARD_BUSY_STOP_2    = 23;
localparam FSM_CARD_BUSY_STOP_3    = 24;
localparam FSM_STATES              = 25; /* number of states */
localparam FSM_BITS                = $clog2(FSM_STATES);

/* Command exec FSM States */
localparam CMD_FSM_IDLE               = 0;
localparam CMD_FSM_SEND_CMD_1         = 1;
localparam CMD_FSM_SEND_CMD_2         = 2;
localparam CMD_FSM_RECEIVE_CMD_RESP_1 = 3;
localparam CMD_FSM_RECEIVE_CMD_RESP_2 = 4;
localparam CMD_FSM_RECEIVE_CMD_RESP_3 = 5;
localparam CMD_FSM_RECEIVE_CMD_RESP_4 = 6;
localparam CMD_FSM_STATES             = 7; /* number of states */
localparam CMD_FSM_BITS               = $clog2(CMD_FSM_STATES);

/* Commands list */
localparam NOCMD     = 0;
localparam CMD0      = 1;
localparam CMD8      = 2;
localparam CMD12     = 3;
localparam CMD17     = 4;
localparam CMD18     = 5;
localparam CMD55     = 6;
localparam CMD58     = 7;
localparam ACMD41    = 8;
localparam CMD_COUNT = 9; /* number of cmd */
localparam CMD_BITS  = $clog2(CMD_COUNT);

/* Other params */
localparam BLOCK_ADDR_BITS = 32;
localparam BLOCK_LENGHT_BYTES = 512;
localparam BLOCK_LENGHT_BITS = $clog2(BLOCK_LENGHT_BYTES);
localparam SPI_SIZE = 4'd8;
localparam CARD_CMD_BYTES = 6; /* Lenght of SD command in bytes */
localparam CARD_BLOCKLEN_BYTES = 512; /* Block lenght in bytes*/
localparam CMD_MAX_RESP_BYTES = 5;
localparam CMD_RESP_BITS = CMD_MAX_RESP_BYTES*8;
localparam CMD_SEND_COUNTER_BITS = $clog2(CARD_CMD_BYTES);
localparam CMD_RESP_COUNTER_BITS = $clog2(CMD_MAX_RESP_BYTES);

