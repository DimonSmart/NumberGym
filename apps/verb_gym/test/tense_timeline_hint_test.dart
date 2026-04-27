import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym/tense_timeline_hint.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

void main() {
  test('present indicative compares simple, continuous, and perfect', () {
    final cards = buildVerbTenseTimelineCards(
      currentTenseId: VerbTenseIds.presentIndicative,
      labels: VerbTenseTimelineLabels.english,
    );

    expect(cards, hasLength(3));
    expect(cards[0].tenseId, VerbTenseIds.presentIndicative);
    expect(cards[0].isSelected, isTrue);
    expect(cards[0].region, VerbTimelineRegion.present);
    expect(cards[0].aspect, VerbTimelineAspect.simple);

    expect(cards[1].title, 'Present continuous');
    expect(cards[1].aspect, VerbTimelineAspect.continuous);

    expect(cards[2].tenseId, VerbTenseIds.presentPerfect);
    expect(cards[2].aspect, VerbTimelineAspect.perfect);
  });

  test('spanish labels are used when base language is spanish', () {
    final labels = VerbTenseTimelineLabels.forLanguage(
      LearningLanguage.spanish,
    );
    final cards = buildVerbTenseTimelineCards(
      currentTenseId: VerbTenseIds.presentIndicative,
      labels: labels,
    );

    expect(labels.now, 'AHORA');
    expect(cards[0].title, 'Presente de indicativo');
  });

  test('unknown tense produces no hint cards', () {
    final cards = buildVerbTenseTimelineCards(
      currentTenseId: 'unknownTense',
      labels: VerbTenseTimelineLabels.english,
    );

    expect(cards, isEmpty);
  });

  testWidgets('renders three cards at compact width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VerbTenseTimelineHint(
                currentTenseId: VerbTenseIds.presentIndicative,
                labels: VerbTenseTimelineLabels.english,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Present indicative'), findsOneWidget);
    expect(find.text('Present continuous'), findsOneWidget);
    expect(find.text('Present perfect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
