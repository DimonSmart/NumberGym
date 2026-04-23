import 'package:trainer_core/trainer_core.dart'
    show ReviewPronunciationState, ReviewFlow, PronunciationAnalysisResult;

class PhrasePronunciationViewModel {
  const PhrasePronunciationViewModel({
    required this.title,
    required this.displayText,
    required this.result,
    required this.flow,
    required this.hasRecording,
    required this.isWaveVisible,
    required this.helperText,
    required this.showRecordButton,
    required this.showStopButton,
    required this.showRecordAgainButton,
    required this.showSendButton,
    required this.showNextButton,
    required this.disableSend,
    required this.sendLabel,
    required this.showSendProgress,
  });

  final String title;
  final String displayText;
  final PronunciationAnalysisResult? result;
  final ReviewFlow flow;
  final bool hasRecording;
  final bool isWaveVisible;
  final String helperText;
  final bool showRecordButton;
  final bool showStopButton;
  final bool showRecordAgainButton;
  final bool showSendButton;
  final bool showNextButton;
  final bool disableSend;
  final String sendLabel;
  final bool showSendProgress;

  bool get isRecording => flow == ReviewFlow.recording;
  bool get isReviewing => flow == ReviewFlow.reviewing;
  bool get isSending => flow == ReviewFlow.sending;
  bool get isRecorded => flow == ReviewFlow.recorded;

  factory PhrasePronunciationViewModel.fromState({
    required ReviewPronunciationState task,
  }) {
    final flow = task.flow;
    final waiting = flow == ReviewFlow.waiting;
    final isRecording = flow == ReviewFlow.recording;
    final isReviewing = flow == ReviewFlow.reviewing;
    final isSending = flow == ReviewFlow.sending;
    final isRecorded = flow == ReviewFlow.recorded;
    final hasRecording = task.hasRecording;

    final showRecordButton = !isRecording && !hasRecording && !isReviewing;
    final showStopButton = isRecording;
    final showRecordAgainButton = isRecorded;
    final showSendButton = !isRecording && hasRecording && !isReviewing;
    final showNextButton = !isRecording && isReviewing;

    return PhrasePronunciationViewModel(
      title: 'Pronounce the phrase',
      displayText: task.displayText,
      result: task.result,
      flow: flow,
      hasRecording: hasRecording,
      isWaveVisible: task.isWaveVisible,
      helperText: _buildHelperText(
        waiting: waiting,
        isRecording: isRecording,
        hasRecording: hasRecording,
        isReviewing: isReviewing,
        isSending: isSending,
      ),
      showRecordButton: showRecordButton,
      showStopButton: showStopButton,
      showRecordAgainButton: showRecordAgainButton,
      showSendButton: showSendButton,
      showNextButton: showNextButton,
      disableSend: isSending,
      sendLabel: isSending ? 'Sending...' : 'Send',
      showSendProgress: isSending,
    );
  }

  static String _buildHelperText({
    required bool waiting,
    required bool isRecording,
    required bool hasRecording,
    required bool isReviewing,
    required bool isSending,
  }) {
    if (isRecording) {
      return 'Recording... tap Stop when done.';
    }
    if (isReviewing) {
      return 'Review your pronunciation and tap Next to continue.';
    }
    if (hasRecording) {
      return isSending
          ? 'Uploading for scoring...'
          : 'Review or send your recording for scoring.';
    }
    if (waiting) {
      return 'Tap Record and read the phrase aloud.';
    }
    return 'Waiting to start the next phrase.';
  }
}
