#!/bin/bash

# Usage: ./convert_audio_file.sh ./input_file.mp3 ./output_file.wav

CHANNELS=2
SAMPLING_RATE=44100
ffmpeg -i $1 -flags +bitexact -map_metadata -1 -ar $SAMPLING_RATE -ac $CHANNELS $2
