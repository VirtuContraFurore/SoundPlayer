#!/bin/bash

# Usage: ./convert_audio_file.sh ./input_file.mp3

CHANNELS=1
SAMPLING_RATE=44100
ffmpeg -i $1 -flags +bitexact -map_metadata -1 -ar $SAMPLING_RATE -ac $CHANNELS output.wav
