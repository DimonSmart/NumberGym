import '../data/number_cards.dart';
import '../data/phone_cards.dart';
import '../data/time_cards.dart';
import 'learning_language.dart';
import 'training_task.dart';
import '../languages/registry.dart';

abstract class TrainingCardProvider {
  const TrainingCardProvider();

  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int)? toWords,
  });
}

class TrainingCatalog {
  TrainingCatalog({required List<TrainingCardProvider> providers})
    : _providers = List<TrainingCardProvider>.unmodifiable(providers);

  final List<TrainingCardProvider> _providers;

  factory TrainingCatalog.defaults() {
    return TrainingCatalog(
      providers: const [
        NumberTrainingCardProvider(),
        TimeTrainingCardProvider(),
        PhoneTrainingCardProvider(),
      ],
    );
  }

  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int)? toWords,
  }) {
    final cards = <PronunciationTaskData>[];
    for (final provider in _providers) {
      cards.addAll(provider.buildCards(language: language, toWords: toWords));
    }
    return cards;
  }
}

class NumberTrainingCardProvider extends TrainingCardProvider {
  const NumberTrainingCardProvider();

  @override
  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int)? toWords,
  }) {
    return buildNumberCards(language: language, toWords: toWords);
  }
}

class TimeTrainingCardProvider extends TrainingCardProvider {
  const TimeTrainingCardProvider();

  @override
  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int)? toWords,
  }) {
    final converter = LanguageRegistry.of(language).timeWordsConverter;
    return buildTimeCards(language: language, toWords: converter);
  }
}

class PhoneTrainingCardProvider extends TrainingCardProvider {
  const PhoneTrainingCardProvider();

  @override
  List<PronunciationTaskData> buildCards({
    required LearningLanguage language,
    String Function(int)? toWords,
  }) {
    return buildPhoneCards(language: language);
  }
}
