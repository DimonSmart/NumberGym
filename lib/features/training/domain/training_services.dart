import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'services/audio_recorder_service.dart';
import 'services/azure_speech_service.dart';
import 'services/card_timer.dart';
import 'services/internet_checker.dart';
import 'services/keep_awake_service.dart';
import 'services/sound_wave_service.dart';
import 'services/speech_service.dart';

typedef InternetChecker = Future<bool> Function();

class TrainingServices {
  TrainingServices({
    required this.speech,
    required this.soundWave,
    required this.timer,
    required this.keepAwake,
    required this.audioRecorder,
    required this.azure,
    required this.internet,
  });

  factory TrainingServices.defaults({stt.SpeechToText? speech}) {
    return TrainingServices(
      speech: SpeechService(speech: speech),
      soundWave: SoundWaveService(),
      timer: CardTimer(),
      keepAwake: KeepAwakeService(),
      audioRecorder: AudioRecorderService(),
      azure: AzureSpeechService(),
      internet: hasInternet,
    );
  }

  final SpeechServiceBase speech;
  final SoundWaveServiceBase soundWave;
  final CardTimerBase timer;
  final KeepAwakeServiceBase keepAwake;
  final AudioRecorderServiceBase audioRecorder;
  final AzureSpeechService azure;
  final InternetChecker internet;

  void dispose() {
    speech.dispose();
    soundWave.dispose();
    timer.dispose();
    keepAwake.dispose();
    audioRecorder.dispose();
  }
}
