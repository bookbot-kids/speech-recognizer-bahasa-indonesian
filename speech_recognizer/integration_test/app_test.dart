import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_recognizer/main.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('test speech recognizer on audio', (tester) async {
    // Load app widget.
    await tester.pumpWidget(const MyApp(isTesting: true));

    // tap on load model button
    await tester.tap(find.byKey(const Key('loadModel')));

    // Trigger a frame.
    await tester.pumpAndSettle();

    // wait for few seconds
    await waitFor(tester, 3);

    // tap on recognize audio button
    await tester.tap(find.byKey(const Key('recognizeAudio')));

    await waitFor(tester, 3);

    // Verify the result
    Finder textFinder = find.byType(Text);

    // if any text widget has recognized data
    bool hasNonEmptyText = textFinder.evaluate().any((widget) {
      final Text textWidget = widget.widget as Text;
      final String data = textWidget.data ?? '';
      return data.isNotEmpty;
    });

    // Use the `expect` function to verify the condition.
    expect(hasNonEmptyText, isTrue);
  });
}

Future<void> waitFor(WidgetTester tester, int seconds,
    {int stepInMs = 200}) async {
  await tester.runAsync(() async {
    final total = seconds * (1000 / stepInMs);
    var runningTime = 0;
    for (var i = 0; i < total; i++) {
      // print only second
      final seconds = runningTime / 1000;
      if (runningTime % 1000 == 0) {
        debugPrint('waiting for ${seconds.toInt()}s');
      }

      await tester.pump(Duration(milliseconds: stepInMs));
      runningTime += stepInMs;
    }
  });
}
