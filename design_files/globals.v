/* Project configuration file */
`ifndef GLOBALS_INCLUDED
`define GLOBALS_INCLUDED

/* Uncomment ignored config */
//`define DEBUG_SPI_MASTER
//`define DEBUG_SDCARD_READER

/* Main clock is 200 MHz -> DIV8 = 25 MHz */
`define SDCARD_MISSION_MODE_PSCLR SPI_PSCLR_DIV8
`define STARTUP_PRESCALER         SPI_PSCLR_DIV1024

`endif

