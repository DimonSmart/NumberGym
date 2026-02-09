import '../languages/registry.dart';
import 'language_router.dart';
import 'repositories.dart';
import 'runtimes/listening_runtime.dart';
import 'runtimes/multiple_choice_runtime.dart';
import 'runtimes/number_pronunciation_runtime.dart';
import 'runtimes/phrase_pronunciation_runtime.dart';
import 'task_registry.dart';
import 'task_runtime.dart';
import 'tasks/number_to_word_task.dart';
import 'time_value.dart';
import 'training_item.dart';
import 'training_task.dart';

class TaskRuntimeFactory {
  TaskRuntimeFactory({
    required SettingsRepositoryBase settingsRepository,
    required LanguageRouter languageRouter,
    required void Function(bool ready, String? errorMessage) onSpeechReady,
  }) : _settingsRepository = settingsRepository,
       _languageRouter = languageRouter,
       _onSpeechReady = onSpeechReady;

  static const int _optionPickMultiplier = 3;
  static const int _optionPickBaseAttempts = 5;

  final SettingsRepositoryBase _settingsRepository;
  final LanguageRouter _languageRouter;
  final void Function(bool ready, String? errorMessage) _onSpeechReady;

  TaskRegistry buildDefaultRegistry() {
    return TaskRegistry({
      LearningMethod.numberPronunciation: (context) {
        return NumberPronunciationRuntime(
          task: context.card,
          speechService: context.services.speech,
          soundWaveService: context.services.soundWave,
          cardTimer: context.services.timer,
          cardDuration: context.cardDuration,
          hintText: context.hintText,
          onSpeechReady: _onSpeechReady,
        );
      },
      LearningMethod.valueToText: _buildValueToTextRuntime,
      LearningMethod.textToValue: _buildTextToValueRuntime,
      LearningMethod.listening: _buildListeningRuntime,
      LearningMethod.phrasePronunciation: _buildPhrasePronunciationRuntime,
    });
  }

  TaskRuntime _buildValueToTextRuntime(TaskBuildContext context) {
    final spec = context.card.buildValueToTextSpec(context);
    return MultipleChoiceRuntime(
      kind: LearningMethod.valueToText,
      taskId: context.card.id,
      numberValue: spec.numberValue,
      prompt: spec.prompt,
      correctOption: spec.correctOption,
      options: spec.options,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildTextToValueRuntime(TaskBuildContext context) {
    final timeValue = context.card.timeValue;
    if (timeValue != null) {
      final correctWord = context.timeToWords(timeValue);
      final correctOption = timeValue.displayText;
      final options = <String>{correctOption};
      final candidateTimes = _candidateTimeValuesFor(context);
      final maxAttempts = _maxOptionAttempts(candidateTimes.length);
      var attempts = 0;
      while (options.length < valueToTextOptionCount &&
          attempts < maxAttempts) {
        final candidate =
            candidateTimes[context.random.nextInt(candidateTimes.length)];
        attempts += 1;
        if (candidate == timeValue) continue;
        options.add(candidate.displayText);
      }

      final shuffled = options.toList()..shuffle(context.random);
      return MultipleChoiceRuntime(
        kind: LearningMethod.textToValue,
        taskId: context.card.id,
        numberValue: null,
        prompt: correctWord,
        correctOption: correctOption,
        options: shuffled,
        cardDuration: context.cardDuration,
        cardTimer: context.services.timer,
      );
    }

    final numberValue = _requireNumberValue(context.card);
    final correctWord = context.toWords(numberValue);
    final correctOption = numberValue.toString();
    final options = <String>{correctOption};
    final candidateIds = _candidateIdsFor(context);
    final maxAttempts = _maxOptionAttempts(candidateIds.length);
    var attempts = 0;
    while (options.length < valueToTextOptionCount && attempts < maxAttempts) {
      final candidateId =
          candidateIds[context.random.nextInt(candidateIds.length)];
      attempts += 1;
      final candidateValue = candidateId.number;
      if (candidateValue == null || candidateValue == numberValue) continue;
      options.add(candidateValue.toString());
    }

    final shuffled = options.toList()..shuffle(context.random);
    return MultipleChoiceRuntime(
      kind: LearningMethod.textToValue,
      taskId: context.card.id,
      numberValue: numberValue,
      prompt: correctWord,
      correctOption: correctOption,
      options: shuffled,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
    );
  }

  TaskRuntime _buildListeningRuntime(TaskBuildContext context) {
    final card = context.card;
    final numberValue = card.numberValue;
    final timeValue = card.timeValue;

    String correctOption;
    String speechText;
    final options = <String>{};

    if (numberValue != null) {
      correctOption = numberValue.toString();
      options.add(correctOption);
      final candidateIds = _candidateIdsFor(context);
      final maxAttempts = _maxOptionAttempts(candidateIds.length);
      var attempts = 0;
      while (options.length < valueToTextOptionCount &&
          attempts < maxAttempts) {
        final candidateId =
            candidateIds[context.random.nextInt(candidateIds.length)];
        attempts += 1;
        final candidateValue = candidateId.number;
        if (candidateValue == null || candidateValue == numberValue) continue;
        options.add(candidateValue.toString());
      }

      try {
        speechText = context.toWords(numberValue);
      } catch (_) {
        speechText = correctOption;
      }
    } else if (timeValue != null) {
      correctOption = timeValue.displayText;
      options.add(correctOption);
      final candidateTimes = _candidateTimeValuesFor(context);
      final maxAttempts = _maxOptionAttempts(candidateTimes.length);
      var attempts = 0;
      while (options.length < valueToTextOptionCount &&
          attempts < maxAttempts) {
        final candidateTime =
            candidateTimes[context.random.nextInt(candidateTimes.length)];
        attempts += 1;
        if (candidateTime == timeValue) continue;
        options.add(candidateTime.displayText);
      }

      try {
        speechText = context.timeToWords(timeValue);
      } catch (_) {
        speechText = correctOption;
      }
    } else {
      throw StateError(
        'Expected either numberValue or timeValue for listening task.',
      );
    }

    final shuffled = options.toList()..shuffle(context.random);
    final voiceId = _settingsRepository.readTtsVoiceId(context.language);

    return ListeningRuntime(
      taskId: context.card.id,
      numberValue: numberValue,
      timeValue: timeValue,
      correctAnswer: correctOption,
      options: shuffled,
      speechText: speechText,
      cardDuration: context.cardDuration,
      cardTimer: context.services.timer,
      ttsService: context.services.tts,
      locale: LanguageRegistry.of(context.language).locale,
      voiceId: voiceId,
    );
  }

  TaskRuntime _buildPhrasePronunciationRuntime(TaskBuildContext context) {
    final numberValue = _requireNumberValue(context.card);
    final template = _languageRouter.pickTemplate(
      numberValue,
      language: context.language,
    );
    if (template == null) {
      return _buildFallbackPronunciationRuntime(context);
    }
    final task = template.toTask(value: numberValue, taskId: context.card.id);
    return PhrasePronunciationRuntime(
      task: task,
      language: context.language,
      audioRecorder: context.services.audioRecorder,
      soundWaveService: context.services.soundWave,
      azureSpeechService: context.services.azure,
    );
  }

  TaskRuntime _buildFallbackPronunciationRuntime(TaskBuildContext context) {
    return NumberPronunciationRuntime(
      task: context.card,
      speechService: context.services.speech,
      soundWaveService: context.services.soundWave,
      cardTimer: context.services.timer,
      cardDuration: context.cardDuration,
      hintText: context.hintText,
      onSpeechReady: _onSpeechReady,
    );
  }

  int _maxOptionAttempts(int candidatePoolSize) {
    final safePool = candidatePoolSize <= 0 ? 1 : candidatePoolSize;
    return safePool * _optionPickMultiplier + _optionPickBaseAttempts;
  }

  List<TrainingItemId> _candidateIdsFor(TaskBuildContext context) {
    final currentType = context.card.id.type;
    final values = context.cardIds
        .where((itemId) => itemId.type == currentType && itemId.number != null)
        .toList();
    if (values.isNotEmpty) return values;
    return <TrainingItemId>[context.card.id];
  }

  List<TimeValue> _candidateTimeValuesFor(TaskBuildContext context) {
    final currentType = context.card.id.type;
    final values = context.cardIds
        .where((itemId) => itemId.type == currentType && itemId.time != null)
        .map((itemId) => itemId.time!)
        .toList();
    if (values.isNotEmpty) return values;

    final hourOffset = context.random.nextInt(24);
    final minuteOffset = context.random.nextInt(60);
    return List<TimeValue>.generate(24, (index) {
      return TimeValue(
        hour: (hourOffset + index) % 24,
        minute: (minuteOffset + index * 13) % 60,
      );
    });
  }

  int _requireNumberValue(PronunciationTaskData card) {
    final numberValue = card.numberValue;
    if (numberValue == null) {
      throw StateError('Expected a number-based pronunciation card.');
    }
    return numberValue;
  }
}
