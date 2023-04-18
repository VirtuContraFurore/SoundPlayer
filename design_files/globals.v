/* Project configuration file */
`ifndef GLOBALS_INCLUDED
`define GLOBALS_INCLUDED

/* MAIN FREQ FROM PLL */
`define MAIN_CLK_FREQ_MHZ       100

/* SDCARD SPI PRESCALER SELECTION */
`define SDCARD_MISSION_MODE_PSCLR   SPI_PSCLR_DIV16
`define STARTUP_PRESCALER           SPI_PSCLR_DIV512 

/* I2C MASTER FREQ */
`define I2C_IF_FREQ_KHZ         20

/* Codec Main Clock (MCLK) generation */
`define CODEC_MCLK_FREQ_HZ      16_934_400
`define CODEC_MCLK_DIV          6          
`define CODEC_FSAMPL_HZ         44_100
/* Note: MAIN_CLK / MCLK_DIV must be close to 16.9344 MHz */

/* Button mapping */
`define BUTTON_RST      (!KEY[3])
`define BUTTON_NEXT     (!KEY[0])
`define BUTTON_PAUSE    (!KEY[1])
`define BUTTON_PREV     (!KEY[2])

/* 
 * Restart song if previous button is pressed after a given number of seconds 
 * otherwise, if button is pressed within the given number of seconds goes to previous song
 */
`define RESTART_SONG_AFTER_SECS 5

`endif

