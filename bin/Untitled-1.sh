#!/bin/bash

# Set the desired bitrate for the MP3 files (e.g., 64k)
bitrate="64k"

# Loop through the numbers 01 to 60
for i in $(seq -f "%02g" 1 60); do
  # Set the input WAV file name
  input_file="part_${i}.wav"
  
  # Set the output MP3 file name
  output_file="part_${i}.mp3"
  
  # Convert the WAV file to MP3 using ffmpeg
  ffmpeg -i "$input_file" -acodec libmp3lame -b:a "$bitrate" "$output_file"
  
  echo "Converted $input_file to $output_file"
done