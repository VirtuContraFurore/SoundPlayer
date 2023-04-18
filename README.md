# SoundPlayer
Altera DE2 Sound Player project for the course of Digital Systems Design (9 ects) held at the University of Pisa (Italy).
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
- `DE2_pin_assignments_modified.csv` is a csv file which contains the pin mapping of the fpga to the DE2 board resources (can be loaeded into Quartus II to ease pin assignment)

## Verilog files not to be compiled
Since Verilog does not allow preprocessor-defined costant to be local, there are some verilog files which contains only `localparam` statements.
Those files are shared files meant to be included inside each module that needs to access constant values.
If QuartusII tries to compile those files will throw errors because `localparam` cannot be used outside module declaration.  
There are two possible solutions:
- change file extension to something else than `.v` so that QuartusII does not try to compile them  
- explicitly tell QuartusII that some files are used to contain custom stuff rather than Verilog source files to be compiled  

We have chosen the latter approch. Hence, some files are marked as 'Macro Files', meaning that they should not be compiled alone as a stand alone Verilog module.

## Authors
- Luca Ceragioli
- Marco Ferrini
