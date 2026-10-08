import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'services/card_timer.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';

class TrainingServices {
  TrainingServices({
    required this.speech,
    required this.soundWave,
    required this.timer,
    required this.keepAwake,
    required this.tts,
  });

  factory TrainingServices.defaults({stt.SpeechToText? speech}) {
    return TrainingServices(
      speech: SpeechService(speech: speech),
      soundWave: SoundWaveService(),
      timer: CardTimer(),
      keepAwake: KeepAwakeService(),
      tts: TtsService(),
    );
  }

  final SpeechServiceBase speech;
  final SoundWaveServiceBase soundWave;
  final CardTimerBase timer;
  final KeepAwakeServiceBase keepAwake;
  final TtsServiceBase tts;

  void dispose() {
    speech.dispose();
    soundWave.dispose();
    timer.dispose();
    keepAwake.dispose();
    tts.dispose();
  }
}
