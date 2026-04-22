class PronunciationPhoneme {
  final String phoneme;
  final double accuracyScore;

  PronunciationPhoneme({
    required this.phoneme,
    required this.accuracyScore,
  });

  factory PronunciationPhoneme.fromJson(Map<String, dynamic> json) {
    return PronunciationPhoneme(
      phoneme: json['Phoneme']?.toString() ?? '',
      accuracyScore: (json['AccuracyScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PronunciationWord {
  final String word;
  final double accuracyScore;
  final String? errorType;
  final List<PronunciationPhoneme> phonemes;

  PronunciationWord({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
    required this.phonemes,
  });

  factory PronunciationWord.fromJson(Map<String, dynamic> json) {
    final phonemesJson = (json['Phonemes'] as List?) ?? const [];
    return PronunciationWord(
      word: json['Word']?.toString() ?? '',
      accuracyScore: (json['AccuracyScore'] as num?)?.toDouble() ?? 0.0,
      errorType: json['ErrorType']?.toString(),
      phonemes: phonemesJson
          .whereType<Map<String, dynamic>>()
          .map(PronunciationPhoneme.fromJson)
          .toList(),
    );
  }
}

class PronunciationNBest {
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double pronScore;
  final List<PronunciationWord> words;

  PronunciationNBest({
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.pronScore,
    required this.words,
  });

  factory PronunciationNBest.fromJson(Map<String, dynamic> json) {
    final wordsJson = (json['Words'] as List?) ?? const [];
    return PronunciationNBest(
      accuracyScore: (json['AccuracyScore'] as num?)?.toDouble() ?? 0.0,
      fluencyScore: (json['FluencyScore'] as num?)?.toDouble() ?? 0.0,
      completenessScore: (json['CompletenessScore'] as num?)?.toDouble() ?? 0.0,
      pronScore: (json['PronScore'] as num?)?.toDouble() ?? 0.0,
      words: wordsJson
          .whereType<Map<String, dynamic>>()
          .map(PronunciationWord.fromJson)
          .toList(),
    );
  }
}

class PronunciationAnalysisResult {
  final String? displayText;
  final List<PronunciationNBest> nBest;
  final Map<String, dynamic>? rawJson;

  PronunciationAnalysisResult({
    required this.displayText,
    required this.nBest,
    required this.rawJson,
  });

  PronunciationNBest? get best => nBest.isNotEmpty ? nBest.first : null;

  factory PronunciationAnalysisResult.fromJson(Map<String, dynamic> json) {
    final nBestJson = (json['NBest'] as List?) ?? const [];
    return PronunciationAnalysisResult(
      displayText: json['DisplayText']?.toString(),
      nBest: nBestJson
          .whereType<Map<String, dynamic>>()
          .map(PronunciationNBest.fromJson)
          .toList(),
      rawJson: json,
    );
  }
}

class AzureSpeechFailure implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  AzureSpeechFailure(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    final codePart = statusCode == null ? '' : ' (code: $statusCode)';
    return 'AzureSpeechFailure: $message$codePart';
  }
}
