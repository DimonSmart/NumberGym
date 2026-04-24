import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym_content/number_gym_content.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  final module = NumberGymModule();

  group('family defaultDuration', () {
    late Map<String, ExerciseFamily> byId;

    setUpAll(() {
      byId = {
        for (final f in module.buildFamilies(LearningLanguage.spanish)) f.id: f,
      };
    });

    test('digits family has 10 second duration', () {
      expect(byId['digits']!.defaultDuration, const Duration(seconds: 10));
    });

    test('base family has 15 second duration', () {
      expect(byId['base']!.defaultDuration, const Duration(seconds: 15));
    });

    test('timeRandom family has 15 second duration', () {
      expect(byId['timeRandom']!.defaultDuration, const Duration(seconds: 15));
    });

    test('phone33x3 family has 30 second duration', () {
      expect(byId['phone33x3']!.defaultDuration, const Duration(seconds: 30));
    });

    test('phone3222 family has 30 second duration', () {
      expect(byId['phone3222']!.defaultDuration, const Duration(seconds: 30));
    });

    test('phone2322 family has 30 second duration', () {
      expect(byId['phone2322']!.defaultDuration, const Duration(seconds: 30));
    });
  });
}
