/* Project configuration file */
`ifndef GLOBALS_INCLUDED
`define GLOBALS_INCLUDED

/* MAIN FREQ FROM PLL */
`define MAIN_CLK_FREQ_MHZ       200

/* SDCARD SPI PRESCALER SELECTION */
`define SDCARD_MISSION_MODE_PSCLR   SPI_PSCLR_DIV8    /* Main clock is 200 MHz -> DIV8 = 25 MHz */
`define STARTUP_PRESCALER           SPI_PSCLR_DIV1024 

/* I2C MASTER FREQ */
`define I2C_IF_FREQ_KHZ         20

/* Codec Main Clock (MCLK) generation */
`define CODEC_MCLK_FREQ_HZ      16_934_400
`define CODEC_MCLK_DIV          12          /*  If main clock is 203.2 MHz -> 203.2/12 = 12.933*/
`define CODEC_FSAMPL_HZ         44_100

/* Uncomment ignored config */
//`define DEBUG_SPI_MASTER
//`define DEBUG_SDCARD_READER

`endif

