import 'dart:io';
import 'package:dartx/dartx.dart';

void main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    print('usage: audiobook_man '
        '<mp3 file folder> '
        '[output file name (default: output.mp3)]');
    return;
  }

  final inputFolder = args[0];
  final outputFile = args.length == 2 ? args[1] : 'output.mp3';

  // NOTE: part name wav files from:
  // https://console.cloud.google.com/vertex-ai/generative/speech/text-to-speech

  // execute ffmpeg to concatenate the files in the list into a single mp3
  final ffmpeg = Ffmpeg();
  ffmpeg.concatFolder(inputFolder: inputFolder, outputFile: outputFile);
}

class Ffmpeg {
  final _exe = 'ffmpeg';

  void concatFolder({
    required String inputFolder,
    required String outputFile,
  }) async {
    // create a list of mp3 files from the folder specified by mp3Folder
    final mp3Files =
        Directory(inputFolder).listSync().where((f) => f.path.endsWith('.mp3'));

    // create a temp file to hold the file list using' the OS temp folder
    final tempDir = await Directory.systemTemp.createTemp('audiobook_man');
    final fileList = File('${tempDir.path}/filelist.txt');
    final lines = mp3Files.map((n) =>
        "file ${n.path.replaceAll("'", r"\'").replaceAll(" ", r"\ ")}\n");
    await fileList.writeAsString(lines.sorted().join(''));

    // ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.mp3
    final args = [
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      fileList.path,
      '-c',
      'copy',
      outputFile,
    ];

    try {
      final results = await Process.run(_exe, args);

      if (results.exitCode != 0) {
        throw ProcessException(
          _exe,
          args,
          results.stderr.toString(),
          results.exitCode,
        );
      }
    } finally {
      // delete the temp folder
      await tempDir.delete(recursive: true);
    }
  }
}
