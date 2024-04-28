import 'dart:io';
import 'package:dartx/dartx_io.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  if (args.length != 2) {
    print('usage: audiobook_man <input file folder> <output file folder>');
    return;
  }

  final inputFoldername = args[0];
  final outputFoldername = args[1];

  // NOTE: part name wav files from:
  // https://console.cloud.google.com/vertex-ai/generative/speech/text-to-speech

  final ffmpeg = await Ffmpeg.init('audiobook_man');
  try {
    // concat mp3s into a single file
    final basename = path.basenameWithoutExtension(inputFoldername);
    final singleFilename = path.join(ffmpeg.workingDir.path, 'single.mp3');
    await ffmpeg.concatFolderOfMp3Files(
      inputFoldername: inputFoldername,
      outputFilename: singleFilename,
    );

    // split mp3s into a set of files 20 minutes long each
    final temp1Foldername = path.join(ffmpeg.workingDir.path, 'temp1');
    final duration = 20 * 60; // 20 minutes
    await ffmpeg.splitMp3File(
      inputFilename: singleFilename,
      duration: duration,
      basename: 'temp',
      outputFoldername: temp1Foldername,
    );

    // prepend a 'part x' prefix to each audio file
    final temp1Files = await Directory(temp1Foldername).list().toList();
    assert(temp1Files.all((o) => o is File));

    final temp1Filenames = temp1Files.map((f) => f.path).sorted();
    assert(temp1Filenames.all((fn) => path.extension(fn) == '.mp3'));

    final temp2Filenames = List<String>.empty(growable: true);
    final temp2Foldername = path.join(ffmpeg.workingDir.path, 'temp2');
    var part = 1;
    for (final temp1Filename in temp1Filenames) {
      final partFilename = path.absolute(
        path.join(
          'part_name_audio',
          'part_${part.toString().padLeft(2, '0')}.mp3',
        ),
      );

      // we may not have a 'part xx' file recorded yet that's high enough
      assert(await File(partFilename).exists());

      final temp2Filename = path.join(
        temp2Foldername,
        path.basename(temp1Filename),
      );

      await ffmpeg.concatAndNormalizeTwoMp3Files(
        inputFilename1: partFilename,
        inputFilename2: temp1Filename,
        outputFilename: temp2Filename,
      );

      temp2Filenames.add(temp2Filename);
      ++part;
    }

    // add 2 seconds of silence to the end of each audio file
    // TODO

    // move the files into the output folder
    await Directory(outputFoldername).create(recursive: true);
    var out = 1;
    for (final temp2Filename in temp2Filenames) {
      final outputFilename = path.join(
        outputFoldername,
        '$basename-${out.toString().padLeft(2, '0')}.mp3',
      );

      ffmpeg.log('renaming $temp2Filename -> $outputFilename');
      await File(temp2Filename).rename(outputFilename);
      ++out;
    }
  } finally {
    await ffmpeg.dispose();
  }
}

class Ffmpeg {
  Directory? _workingDir;

  Ffmpeg._(this._workingDir);

  static Future<Ffmpeg> init(String appName) async {
    // create a working folder to hold transient data
    return Ffmpeg._(await Directory.systemTemp.createTemp(appName));
  }

  Directory get workingDir => _workingDir!;

  Future<void> dispose() async {
    // delete the working folder
    if (_workingDir != null) {
      log('removing working directory: ${workingDir.path}');
      await _workingDir!.delete(recursive: true);
      _workingDir = null;
    }
  }

  // concatenate the mp3 files in the folder into a single mp3
  Future<void> concatFolderOfMp3Files({
    required String inputFoldername,
    required String outputFilename,
  }) async {
    log('concating folder of mp3 files: $inputFoldername -> $outputFilename\n');

    // create a list of mp3 files from the input folder
    final inputFiles = (await Directory(inputFoldername).list().toList())
        .where((f) => f.path.endsWith('.mp3'))
        .map((f) => f.path)
        .sorted();

    await concatMp3Files(
      inputFilenames: inputFiles,
      outputFilename: outputFilename,
    );
  }

  Future<void> concatAndNormalizeTwoMp3Files({
    required String inputFilename1,
    required String inputFilename2,
    required String outputFilename,
  }) async {
    log('concating 2x mp3 files: $inputFilename1, $inputFilename2 -> $outputFilename\n');

    // make sure the output file name's folder exists
    Directory(path.dirname(outputFilename)).create(recursive: true);

    // ffmpeg -i input.mp3 -i second.mp3 -filter_complex \
    //  "[0:a]atrim=end=10,aformat=sample_rates=44100:channel_layouts=stereo,asetpts=N/SR/TB[begin];[1:a]aformat=sample_rates=44100:channel_layouts=stereo[middle];[0:a]atrim=start=10,aformat=sample_rates=44100:channel_layouts=stereo,asetpts=N/SR/TB[end];[begin][middle][end]concat=n=3:v=0:a=1[a]" \
    //  -map "[a]"
    //   output.mp3
    await _execute([
      '-i',
      inputFilename1,
      '-i',
      inputFilename2,
      '-filter_complex',
      '[0:a]atrim=end=10,aformat=sample_rates=44100:channel_layouts=stereo,asetpts=N/SR/TB[begin];[1:a]aformat=sample_rates=44100:channel_layouts=stereo[middle];[0:a]atrim=start=10,aformat=sample_rates=44100:channel_layouts=stereo,asetpts=N/SR/TB[end];[begin][middle][end]concat=n=3:v=0:a=1[a]',
      '-map',
      '[a]',
      outputFilename,
    ]);
  }

  // execute ffmpeg to concatenate a list of files together into a single mp3
  Future<void> concatMp3Files({
    required Iterable<String> inputFilenames,
    required String outputFilename,
  }) async {
    log('concating mp3 files: $inputFilenames -> $outputFilename\n');

    // create a temp file to hold the file list
    final fileList = File(path.join(workingDir.path, 'filelist.txt'));
    final lines = inputFilenames.map(
        (f) => "file ${f.replaceAll("'", r"\'").replaceAll(" ", r"\ ")}\n");
    await fileList.writeAsString(lines.join(''));

    // make sure the output file name's folder exists
    Directory(path.dirname(outputFilename)).create(recursive: true);

    // ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.mp3
    await _execute([
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      fileList.path,
      '-c',
      'copy',
      outputFilename,
    ]);
  }

  Future<void> splitMp3File({
    required String inputFilename,
    required int duration, // in seconds
    required String basename,
    required String outputFoldername,
  }) async {
    log('splitting mp3 file: $inputFilename -> $outputFoldername');

    // ensure output folder exists
    await Directory(outputFoldername).create(recursive: true);

    // ffmpeg -i input.mp3 -f segment -segment_time <duration> -segment_start_number 1 -c copy f-%03d.mp3
    await _execute([
      '-i',
      inputFilename,
      '-f',
      'segment',
      '-segment_time',
      duration.toString(),
      '-segment_start_number',
      '1',
      '-c',
      'copy',
      path.join(outputFoldername, '$basename-%02d.mp3'),
    ]);
  }

  Future<void> _execute(List<String> args) async {
    final exe = 'ffmpeg';
    final results = await Process.run(exe, args);

    if (results.exitCode != 0) {
      throw ProcessException(
        exe,
        args,
        results.stderr.toString(),
        results.exitCode,
      );
    }
  }

  void log(String s) => print(s);
}
