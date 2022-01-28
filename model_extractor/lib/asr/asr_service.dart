// ignore_for_file: avoid_print

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:model_extractor/asr/text_cleaner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';

/// Service to extract kaldi model from given words
class AsrService {
  late Directory _workingDirectory;
  late Directory _binDir;
  late Directory _tempDir;
  late Directory _outputDir;
  late String _alignerPath;
  final _modelDir = 'id/model-id-id';
  final _cleaner = TextCleaner();
  var _isInitialized = false;

  Future<String> get alignerPath async =>
      p.join((await getApplicationSupportDirectory()).path, 'mfa_aligner');

  AsrService(Directory outputDir) {
    _outputDir = outputDir;
    // create a working directory where all temporary files will be written
    // this points to the "kaldi" subdirectory of the directory chosen on snapshot startup
    _tempDir = Directory(p.join(outputDir.path, '.temp'));
    _workingDirectory = Directory(p.join(_tempDir.path, "kaldi"));
    if (!_workingDirectory.existsSync()) {
      _workingDirectory.createSync(recursive: true);
    }

    // not all required binaries are present under the bin/ subdirectory
    // some are shipped/extracted with the MFA dependencies
    alignerPath.then((alignerPath) {
      _alignerPath = alignerPath;
      _binDir = Directory(p.join(alignerPath, "bin"));
    });
  }

  /// Initialize aligner service by copy zip asset into application dir
  Future<void> initialize() async {
    final alignerDir = Directory(await alignerPath);
    print('initializing aligner at ${alignerDir.path}');
    if (!alignerDir.existsSync()) {
      final tempPath = p.join(alignerDir.parent.path, "_mfa");
      final tempDir = Directory(tempPath)..createSync(recursive: true);
      final bytes = await rootBundle.load('assets/mfa_aligner.zip');
      final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
      for (ArchiveFile file in archive) {
        final filename = file.name;
        final decodePath = p.join(tempPath, filename);
        if (file.isFile) {
          List<int> data = file.content;
          File(decodePath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
          if (Platform.isMacOS) {
            await runExecutableArguments('chmod', [
              '+x',
              decodePath,
            ]);
          }
        } else {
          Directory(decodePath).createSync(recursive: true);
        }
      }

      tempDir.renameSync(alignerDir.path);
    }

    _isInitialized = true;
  }

  /// Build & extract kaldi model from given words
  Future build(List<String> words, {String language = 'id'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    // create a working directory for graph compilation
    final workDir = Directory(p.join(_workingDirectory.path, language));
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }

    final normalizedWords = words.map((e) => _cleaner.normalize(e)).toSet();

    // write all words to file
    final corpus = File(p.join(workDir.path, 'corpus.txt'));
    if (corpus.existsSync()) {
      corpus.deleteSync();
    }

    if (!corpus.parent.existsSync()) {
      corpus.parent.createSync(recursive: true);
    }

    final text = normalizedWords.map((word) => '$word\n').join();
    corpus.writeAsStringSync(text);

    // the build_graph.sh scripts will:
    // - build a 0-gram language model from the corpus
    // - create words.txt
    // - generate lexicon.txt from words.txt using gruut (precompiled into a standalone set of binaries with pyinstaller)
    // - create L.fst
    // - create Gr.fst
    // - merge into HCLr.fst

    final pResult = await Process.run(
        "kaldi/bin/build_graph.sh",
        [
          corpus.path,
          Directory(p.join("kaldi", _modelDir)).absolute.path,
          language,
          _alignerPath
        ],
        environment: {
          "LD_LIBRARY_PATH": "${_binDir.path}:${_binDir.path}/../",
          "PATH":
              "${_binDir.path}:${_binDir.path}/../:${Platform.environment["PATH"]}",
          "PYTHONIOENCODING": "utf-8"
        },
        runInShell: true);
    print(pResult.stdout);
    print(pResult.stderr);
    if (pResult.exitCode != 0) {
      throw Exception(pResult.stderr);
    }

    // copy to output
    final outputDir = Directory(p.join(_tempDir.path, 'kaldi/$language'));
    outputDir.renameSync(p.join(_outputDir.path, 'model-$language-$language'));
  }
}
