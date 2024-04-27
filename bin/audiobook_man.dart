import 'dart:io';
import 'package:dartx/dartx.dart';

void main(List<String> args) async {
  if (args.length != 1) {
    print('usage: audiobook_man <mp3 file folder>');
    return;
  }

  final mp3Folder = args[0];

  // NOTE: part name wav files from:
  // https://console.cloud.google.com/vertex-ai/generative/speech/text-to-speech

  // ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.mp3

  // create a list of mp3 files from the folder specified by mp3Folder
  final mp3Files =
      Directory(mp3Folder).listSync().where((f) => f.path.endsWith('.mp3'));

  // create a temp file to hold the file list using' the OS temp folder
  final tempDir = await Directory.systemTemp.createTemp('audiobook_man');
  final fileList = File('${tempDir.path}/filelist.txt');
  final lines = mp3Files.map((n) =>
      "file ${n.path.replaceAll("'", r"\'").replaceAll(" ", r"\ ")}\n");
  await fileList.writeAsString(lines.sorted().join(''));

  // execute ffmpeg to concatenate the files in the list into a single mp3
  final results = await Process.run(
    'ffmpeg',
    [
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      fileList.path,
      '-c',
      'copy',
      'output.mp3',
    ],
    runInShell: true,
  );

  print(results.stderr);

  // delete the temp folder
  await tempDir.delete(recursive: true);
}
