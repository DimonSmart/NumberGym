import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trainer_core/trainer_core.dart';
import 'package:trainer_core/src/runtimes/review_pronunciation_runtime.dart';
import 'package:trainer_core/src/task_runtime.dart';

import 'helpers/training_fakes.dart';

final _family = ExerciseFamily(
  moduleId: 'test',
  id: 'review',
  label: 'Review',
  shortLabel: 'Review',
  difficultyTier: ExerciseDifficultyTier.easy,
  defaultDuration: const Duration(seconds: 1),
  supportedModes: const [ExerciseMode.reviewPronunciation],
);

ReviewPronunciationRuntime _buildRuntime(ControllableAudioRecorder recorder) {
  final card = ExerciseCard(
    id: const ExerciseId(moduleId: 'test', familyId: 'review', variantId: '1'),
    family: _family,
    language: LearningLanguage.english,
    displayText: 'one',
    promptText: 'one',
    acceptedAnswers: const ['one'],
    celebrationText: 'one',
    reviewPronunciation: const ReviewPronunciationSpec(expectedText: 'one'),
  );
  return ReviewPronunciationRuntime(
    card: card,
    spec: card.reviewPronunciation!,
    locale: 'en-US',
    audioRecorder: recorder,
    soundWaveService: FakeSoundWaveService(),
    azureSpeechService: AzureSpeechService(
      client: http.Client(),
      endpoint: Uri.parse('http://localhost'),
    ),
  );
}

void main() {
  test(
    'dispose during recorder start compensates with serialized cancel',
    () async {
      final recorder = ControllableAudioRecorder();
      final runtime = _buildRuntime(recorder);

      final start = runtime.handleAction(const StartRecordingAction());
      await Future<void>.delayed(Duration.zero);
      expect(recorder.startCalls, 1);

      final dispose = runtime.dispose();
      recorder.startGate.complete();
      await start;
      await dispose;

      expect(recorder.cancelCalls, 1);
      expect(recorder.isRecording, isFalse);
      expect(runtime.isDisposed, isTrue);
    },
  );
}
