import 'dart:io';

import 'package:flutter/material.dart';
import 'package:model_extractor/asr/asr_service.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

/// The main application
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

/// The home page of the application
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

/// The state of the home page
class _MyHomePageState extends State<MyHomePage> {
  final _textEditingController = TextEditingController();
  AsrService? _service;
  var _isRunning = false;

  /// Generate model from text field
  Future<void> buildModel() async {
    final text = _textEditingController.text;
    if (text.isEmpty) {
      return;
    }

    // init working directory
    final workingDir = Directory(p.join(
      Directory.current.path,
      'output',
    ));
    if (!workingDir.existsSync()) {
      workingDir.createSync(recursive: true);
    } else {
      workingDir.deleteSync(recursive: true);
      workingDir.createSync(recursive: true);
    }

    _service ??= AsrService(workingDir);
    setState(() {
      _isRunning = true;
    });
    try {
      // start to generate model
      final words = text.split(',');
      await _service?.build(words);
    } catch (e, stacktrace) {
      // ignore: avoid_print
      print('error: $e, $stacktrace');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Visibility(
                visible: _isRunning, child: const CircularProgressIndicator()),
            const SizedBox(height: 20),
            const Text(
              'Enter words here:',
            ),
            Container(
              margin: const EdgeInsets.all(20),
              child: TextField(
                controller: _textEditingController,
                decoration:
                    const InputDecoration(hintText: 'Word A, Word B, Word C'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: buildModel,
        tooltip: 'BuildModel',
        child: const Icon(Icons.build),
      ),
    );
  }
}
