import 'package:flutter/material.dart';
import 'package:speech_recognizer/speech_recognizer.dart';

void main() {
  runApp(const MyApp());
}

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

class _MyHomePageState extends State<MyHomePage> implements SpeechListener {
  var _isInitialized = false;
  var _speechText = '';

  @override
  void onResult(Map result) {
    final text = result['partial'] ?? result['text'] ?? '';
    if (text.isEmpty) return;
    // ignore: avoid_print
    print(text);
    setState(() {
      _speechText += '$text\n';
    });
  }

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
  }

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
