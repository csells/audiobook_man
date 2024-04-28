#!/bin/bash

# Loop through the numbers 01 to 60
for i in $(seq -f "%02g" 1 60); do
  # Set the input WAV file name
  input_file="part_${i}.wav"
  
  # Set the output MP3 file name
  output_file="part_${i}.mp3"
  
  # Convert the WAV file to MP3
  # NOTE: not using this for files 2-60 because some of the resulting
  # MP3 files don't work correctly w/o silence prepended. see below.
  # ffmpeg -i "$input_file" -acodec libmp3lame -b:a 64k "$output_file"

  # Convert the WAV file to MP3 and prepend silence using ffmpeg
  # NOTE: need 1.5 seconds for all of the resulant MP3 files to have the right
  # "frame padding" for ffmpeg to work correctly. don't know why.
  # NOTE: part 26, 36 and 46 needs 1.4 seconds of silence prepended to work
  # correctly. the rest seem to work well with 1.5 seconds of silence prepended.
  # wtf???
  if [[ "$input_file" == *"part26"* || "$input_file" == *"part36"* || "$input_file" == *"part46"* ]]; then
    ffmpeg -i "$input_file" -af "adelay=1.4s:all=true" "$output_file"
  elif [[ "$input_file" == *"part01"* ]]; then
    ffmpeg -i "$input_file" -af "adelay=0s:all=true" "$output_file"
  else
    ffmpeg -i "$input_file" -af "adelay=1.5s:all=true" "$output_file"
  fi

  echo "Converted $input_file to $output_file"
done