# SoundPlayer
Altera DE2 Sound Player project.
Plays wav file in a FAT32 formatted SD Card. Supports only 16 bit 44100 Hz WAV files.

## Project file strutcure
Open this project with Quartus II software.

`root`  
├── `design_files`  
│   ├── Codec  
│   ├── FAT32_reader  
│   └── SDCard_reader  
├── `releases`  
│   └── v1  
└── `validation_files`  
    ├── output_files  
    ├── SDCard_reader  
    └── SPI_master  

- `design_files` contains Verilog source code
- `validation_files` contains test benches and test waveform patterns
- `releases` contains program files to flash fpga's memory and/or on-board eeprom
