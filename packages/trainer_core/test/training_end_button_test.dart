import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  testWidgets('shows the shared end training button affordance', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrainingEndButton(
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('End training'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

    await tester.tap(find.byType(TrainingEndButton));

    expect(pressed, isTrue);
  });
}
