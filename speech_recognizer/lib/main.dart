/*
Copyright 2022 [PT BOOKBOT INDONESIA](https://bookbot.id/)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:flutter/material.dart';
import 'package:speech_recognizer/speech_recognizer.dart';

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
      title: 'Demo speech recognize',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Demo speech recognize'),
    );
  }
}

/// The home page of the application
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> implements SpeechListener {
  var _isInitialized = false;
  var _listening = false;
  List<String> _decoded = [];

  /// listen to speech events and print result in UI
  @override
  void onResult(Map result, bool wasEndpoint) {
    List<List<String>> candidates = result.containsKey('partial')
        ? [result['partial'].trim().split(' ')]
        : result['alternatives']
            .map((x) => x['text'].trim().split(' ').cast<String>().toList())
            .toList()
            .cast<List<String>>();
    if (candidates.isEmpty ||
        !candidates
            .any((element) => element.any((element) => element.isNotEmpty))) {
      return;
    }
    // ignore: avoid_print
    print(candidates);
    setState(() {
      _decoded.insert(0, candidates.join(' '));
    });
  }

  /// Loads the speech recognition model
  void _load() async {
    // ask for permission
    final permissions = await SpeechController.shared.permissions();
    if (permissions == AudioSpeechPermission.undetermined) {
      await SpeechController.shared.authorize();
    }

    if (await SpeechController.shared.permissions() !=
        AudioSpeechPermission.authorized) {
      return;
    }

    if (!_isInitialized) {
      await SpeechController.shared.initSpeech('id');
      setState(() {
        _isInitialized = true;
      });

      SpeechController.shared.addListener(this);
    }
  }

  /// Initialize the speech recognizer and start listening
  Future<void> _recognize() async {
    // await SpeechController.shared
    //     .flushSpeech(grammar: "[\"halo dunia\",\"satu dua tiga\"]");
    await SpeechController.shared.flushSpeech();
    await SpeechController.shared.listen();
  }

  /// Stop the speech recognizer
  Future<void> _stopRecognize() async {
    if (_isInitialized) {
      await SpeechController.shared.stopListening();
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
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey.withOpacity(0.2),
              child: _decoded.length == 0
                  ? Container()
                  : SingleChildScrollView(
                      child: Column(
                          children: _decoded.map((d) => Text(d)).toList())),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: !_isInitialized ? _load : null,
              child: const Text('Load model'),
            ),
            ElevatedButton(
              onPressed: _isInitialized && !_listening ? _recognize : null,
              child: const Text('Start listening'),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: _listening ? _stopRecognize : null,
              child: const Text('Stop listening'),
            ),
          ],
        ),
      ),
    );
  }
}
