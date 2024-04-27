CLI that uses ffmpeg to tailer a folder of mp3s for use on a mp3 player for swimming. It does this by doing the following:

- Concatenates a folder of mp3s into a single mp3 (done)
- Splits the mp3 into multiple mp3s of 20-minute parts each (pending)
- Prepends each chunk with an audio indicator of the part, e.g. "Part 20" (pending)
- Adds a silence to the end of each chunk (pending)
