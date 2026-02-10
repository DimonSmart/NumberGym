import 'learning_language.dart';
import '../languages/registry.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';
import 'training_task.dart';

typedef InternetCheck = Future<bool> Function({bool force});

class TaskAvailability {
  final bool isAvailable;
  final String? message;

  const TaskAvailability({required this.isAvailable, this.message});

  static const TaskAvailability available = TaskAvailability(isAvailable: true);

  static TaskAvailability unavailable(String message) {
    return TaskAvailability(isAvailable: false, message: message);
  }
}

class TaskAvailabilityContext {
  final LearningLanguage language;
  final bool premiumPronunciationEnabled;
  final InternetCheck? internetCheck;

  const TaskAvailabilityContext({
    required this.language,
    required this.premiumPronunciationEnabled,
    this.internetCheck,
  });
}

abstract interface class TaskAvailabilityProvider {
  LearningMethod get kind;

  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  });
}

class TaskAvailabilityRegistry {
  TaskAvailabilityRegistry({required List<TaskAvailabilityProvider> providers})
    : _providers = {for (final provider in providers) provider.kind: provider};

  final Map<LearningMethod, TaskAvailabilityProvider> _providers;

  Future<TaskAvailability> check(
    LearningMethod kind,
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    final provider = _providers[kind];
    if (provider == null) {
      return TaskAvailability.available;
    }
    return provider.check(context, force: force);
  }
}

class SpeechTaskAvailabilityProvider implements TaskAvailabilityProvider {
  SpeechTaskAvailabilityProvider(this._speechService);

  final SpeechServiceBase _speechService;

  @override
  LearningMethod get kind => LearningMethod.numberPronunciation;

  @override
  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    final result = await _speechService.initialize(
      onError: (_) {},
      onStatus: (_) {},
      requestPermission: false,
    );
    if (result.ready) {
      return TaskAvailability.available;
    }
    final message =
        result.errorMessage ??
        'Speech recognition is not available on this device.';
    return TaskAvailability.unavailable(message);
  }
}

class TtsTaskAvailabilityProvider implements TaskAvailabilityProvider {
  TtsTaskAvailabilityProvider(this._ttsService);

  final TtsServiceBase _ttsService;
  LearningLanguage _cachedLanguage = LearningLanguage.english;
  bool? _cachedAvailable;

  @override
  LearningMethod get kind => LearningMethod.listening;

  @override
  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    final language = context.language;
    if (!force && _cachedAvailable != null && _cachedLanguage == language) {
      return _cachedAvailable!
          ? TaskAvailability.available
          : TaskAvailability.unavailable(
              'Text-to-speech is not available for the selected language.',
            );
    }
    final available = await _ttsService.isLanguageAvailable(
      LanguageRegistry.of(language).locale,
    );
    _cachedLanguage = language;
    _cachedAvailable = available;
    if (available) {
      return TaskAvailability.available;
    }
    return TaskAvailability.unavailable(
      'Text-to-speech is not available for the selected language.',
    );
  }
}

class PhraseTaskAvailabilityProvider implements TaskAvailabilityProvider {
  @override
  LearningMethod get kind => LearningMethod.phrasePronunciation;

  @override
  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    if (!context.premiumPronunciationEnabled && !force) {
      return TaskAvailability.unavailable('Premium pronunciation is disabled.');
    }
    final internetCheck = context.internetCheck;
    if (internetCheck != null) {
      final hasInternet = await internetCheck(force: force);
      if (!hasInternet) {
        return TaskAvailability.unavailable(
          'Premium pronunciation requires an internet connection.',
        );
      }
    }
    return TaskAvailability.available;
  }
}
