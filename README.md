# SoundPlayer
Altera DE2 Sound Player project.
Plays wav file in a FAT32 formatted SD Card. Supports only 16 bit 44100 Hz WAV files.

## Project file strutcure
Open this project with Quartus II software.

root  
├── design_files  
│   ├── Codec  
│   ├── FAT32_reader  
│   └── SDCard_reader  
├── releases  
│   └── v1  
├── validation_files  
│   ├── SDCard_reader  
│   └── SPI_master  
├── convert_audio_file.sh  
└── DE2_pin_assignments_modified.csv  

- `design_files` is a folder and contains Verilog source code
- `validation_files` is a folder and contains test benches and test waveform patterns
- `releases` is a folder and contains stable releases of program files to flash fpga's memory and/or on-board eeprom
- `convert_audio_file.sh` is a bash script to convert generic audio file to WAV pcm16s 44.1 kHz format
- `DE2_pin_assignments_modified.csv` is a csv file which contains the pin mapping of the fpga to the DE2 board resources
