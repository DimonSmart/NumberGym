import 'exercise_models.dart';
import 'trainer_services.dart';
import 'training/domain/learning_language.dart';

class TaskAvailability {
  const TaskAvailability({required this.isAvailable, this.message});

  final bool isAvailable;
  final String? message;

  static const TaskAvailability available = TaskAvailability(isAvailable: true);

  static TaskAvailability unavailable(String message) {
    return TaskAvailability(isAvailable: false, message: message);
  }
}

class TaskAvailabilityContext {
  const TaskAvailabilityContext({
    required this.language,
    required this.locale,
  });

  final LearningLanguage language;
  final String locale;
}

abstract interface class TaskAvailabilityProvider {
  ExerciseMode get mode;

  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  });
}

class TaskAvailabilityRegistry {
  TaskAvailabilityRegistry({required List<TaskAvailabilityProvider> providers})
    : _providers = {for (final provider in providers) provider.mode: provider};

  final Map<ExerciseMode, TaskAvailabilityProvider> _providers;

  Future<TaskAvailability> check(
    ExerciseMode mode,
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    final provider = _providers[mode];
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
  ExerciseMode get mode => ExerciseMode.speak;

  @override
  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    final result = await _speechService.initialize(
      onError: (_) {},
      onStatus: (_) {},
      requestPermission: force,
    );
    if (result.ready) {
      return TaskAvailability.available;
    }
    return TaskAvailability.unavailable(
      result.errorMessage ??
          'Speech recognition is not available on this device.',
    );
  }
}

class TtsTaskAvailabilityProvider implements TaskAvailabilityProvider {
  TtsTaskAvailabilityProvider(this._ttsService);

  final TtsServiceBase _ttsService;
  String? _cachedLocale;
  bool? _cachedAvailable;

  @override
  ExerciseMode get mode => ExerciseMode.listenAndChoose;

  @override
  Future<TaskAvailability> check(
    TaskAvailabilityContext context, {
    bool force = false,
  }) async {
    if (!force && _cachedLocale == context.locale && _cachedAvailable != null) {
      return _cachedAvailable!
          ? TaskAvailability.available
          : TaskAvailability.unavailable(
              'Text-to-speech is not available for the selected language.',
            );
    }
    final available = await _ttsService.isLanguageAvailable(context.locale);
    _cachedLocale = context.locale;
    _cachedAvailable = available;
    if (available) {
      return TaskAvailability.available;
    }
    return TaskAvailability.unavailable(
      'Text-to-speech is not available for the selected language.',
    );
  }
}
