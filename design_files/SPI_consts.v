/* 
 * Spi Prescaler Codes 
 * This file must NOT be compiled alone!
 * For this file, set Properties... -> Type to 'Macro File'
 */

localparam SPI_PSCLR_DIV4     = 0;
localparam SPI_PSCLR_DIV8     = 1;
localparam SPI_PSCLR_DIV16    = 2;
localparam SPI_PSCLR_DIV32    = 3;
localparam SPI_PSCLR_DIV64    = 4;
localparam SPI_PSCLR_DIV128   = 5;
localparam SPI_PSCLR_DIV256   = 6;
localparam SPI_PSCLR_DIV512   = 7;
localparam SPI_PSCLR_DIV1024  = 8;

localparam SPI_PSCLR_MAX        = SPI_PSCLR_DIV1024;
localparam SPI_PSCLR_OPTS_COUNT = 9; /* number of supported values */
localparam SPI_PSCLR_BITS       = $clog2(SPI_PSCLR_OPTS_COUNT);

