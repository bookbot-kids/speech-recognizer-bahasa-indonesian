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
  var _speechText = '';

  /// listen to speech events and print result in UI
  @override
  void onResult(Map result, bool wasEndpoint) {
    List<List<String>> candidates = result.containsKey('partial')
        ? [result['partial'].trim().split(' ')]
        : result['alternatives']
            .map((x) => x['text'].trim().split(' ').cast<String>().toList())
            .toList()
            .cast<List<String>>();
    if (candidates.isEmpty) return;
    // ignore: avoid_print
    print(candidates);
    setState(() {
      _speechText += '${candidates.join(' ')}\n';
    });
  }

  /// Initialize the speech recognizer and start listening
  Future<void> _recognize() async {
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
      _isInitialized = true;
      SpeechController.shared.addListener(this);
    }

    await SpeechController.shared.listen();
    await SpeechController.shared.flushSpeech();
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
              child: Scrollbar(
                  isAlwaysShown: true,
                  child: SingleChildScrollView(
                    child: Text(_speechText),
                  )),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () => _recognize(),
              child: const Text('Start listening'),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () => _stopRecognize(),
              child: const Text('Stop listening'),
            ),
          ],
        ),
      ),
    );
  }
}
