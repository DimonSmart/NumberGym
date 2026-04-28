import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/src/training_ui/widgets/sound_waveform.dart';

void main() {
  testWidgets('fits narrow training card width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 301.4,
            child: SoundWaveform(values: <double>[], visible: true),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
