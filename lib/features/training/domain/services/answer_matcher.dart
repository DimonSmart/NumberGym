import '../../../../core/utils/string_extensions.dart';
import '../learning_language.dart';

class MatchResult {
  final String normalizedText;
  final List<String> recognizedTokens;
  final List<int> matchedIndices;
  final bool acceptedAnswer;

  const MatchResult({
    required this.normalizedText,
    required this.recognizedTokens,
    required this.matchedIndices,
    required this.acceptedAnswer,
  });

  bool get matchedAny => matchedIndices.isNotEmpty;
}

class AnswerMatcher {
  List<String> _expectedTokens = const [];
  List<String> _expectedKeys = const [];
  List<bool> _matchedTokens = const [];
  int _matchedTokenCount = 0;
  Set<String> _acceptedAnswers = {};
  LearningLanguage _language = LearningLanguage.english;

  List<String> get expectedTokens => _expectedTokens;
  List<bool> get matchedTokens => _matchedTokens;

  bool get isComplete {
    return _expectedTokens.isNotEmpty &&
        _matchedTokenCount == _expectedTokens.length;
  }

  void reset({
    required String prompt,
    required List<String> answers,
    required LearningLanguage language,
  }) {
    _language = language;
    final expected = _tokenizeExpected(prompt);
    _expectedTokens = expected.map((token) => token.display).toList();
    _expectedKeys = expected.map((token) => token.key).toList();
    _matchedTokens = List<bool>.filled(_expectedTokens.length, false);
    _matchedTokenCount = 0;
    final normalized = <String>{
      for (final answer in answers) answer.normalizeAnswer(),
      if (prompt.isNotEmpty) prompt.normalizeAnswer(),
    }..removeWhere((value) => value.isEmpty);
    _acceptedAnswers = normalized;
  }

  void clear() {
    _expectedTokens = const [];
    _expectedKeys = const [];
    _matchedTokens = const [];
    _matchedTokenCount = 0;
    _acceptedAnswers = {};
    _language = LearningLanguage.english;
  }

  MatchResult applyRecognition(String recognizedText) {
    final normalizedText = recognizedText.normalizeAnswer();
    final tokenization = _tokenizeRecognition(recognizedText);
    final recognizedTokens = tokenization.displayTokens;
    final recognizedKeys = tokenization.keys;

    if (normalizedText.isEmpty || _expectedKeys.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedIndices: const <int>[],
        acceptedAnswer: false,
      );
    }

    if (_expectedKeys.length <= 1 &&
        _acceptedAnswers.contains(normalizedText)) {
      final indices = _markAllMatched();
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedIndices: indices,
        acceptedAnswer: true,
      );
    }

    if (recognizedKeys.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedIndices: const <int>[],
        acceptedAnswer: false,
      );
    }

    final matchedIndices = _matchRemainingSlots(recognizedKeys);
    for (final index in matchedIndices) {
      if (!_matchedTokens[index]) {
        _matchedTokens[index] = true;
        _matchedTokenCount += 1;
      }
    }
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: recognizedTokens,
      matchedIndices: matchedIndices,
      acceptedAnswer: false,
    );
  }

  MatchResult previewRecognition(String recognizedText) {
    final normalizedText = recognizedText.normalizeAnswer();
    final tokenization = _tokenizeRecognition(recognizedText);
    final recognizedTokens = tokenization.displayTokens;
    final recognizedKeys = tokenization.keys;

    if (normalizedText.isEmpty || _expectedKeys.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedIndices: const <int>[],
        acceptedAnswer: false,
      );
    }
    if (recognizedKeys.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedIndices: const <int>[],
        acceptedAnswer: false,
      );
    }
    final matchedIndices = _matchRemainingSlots(recognizedKeys);
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: recognizedTokens,
      matchedIndices: matchedIndices,
      acceptedAnswer: false,
    );
  }

  List<int> _markAllMatched() {
    if (_expectedTokens.isEmpty) {
      return const <int>[];
    }
    final indices = <int>[];
    for (var i = 0; i < _matchedTokens.length; i += 1) {
      if (!_matchedTokens[i]) {
        _matchedTokens[i] = true;
        indices.add(i);
      }
    }
    _matchedTokenCount = _expectedTokens.length;
    return indices;
  }

  List<int> _matchRemainingSlots(List<String> recognizedKeys) {
    final remainingIndices = <int>[];
    final remainingKeys = <String>[];
    for (var i = 0; i < _expectedKeys.length; i += 1) {
      if (!_matchedTokens[i]) {
        remainingIndices.add(i);
        remainingKeys.add(_expectedKeys[i]);
      }
    }
    if (recognizedKeys.isEmpty || remainingKeys.isEmpty) {
      return const <int>[];
    }
    final matchedInRemaining = _lcsMatches(recognizedKeys, remainingKeys);
    return [for (final index in matchedInRemaining) remainingIndices[index]];
  }

  List<int> _lcsMatches(List<String> left, List<String> right) {
    final m = left.length;
    final n = right.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = m - 1; i >= 0; i -= 1) {
      for (var j = n - 1; j >= 0; j -= 1) {
        if (left[i] == right[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }
    final matches = <int>[];
    var i = 0;
    var j = 0;
    while (i < m && j < n) {
      if (left[i] == right[j]) {
        matches.add(j);
        i += 1;
        j += 1;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        i += 1;
      } else {
        j += 1;
      }
    }
    return matches;
  }

  List<_SemanticToken> _tokenizeExpected(String text) {
    return _tokenizeToSemanticTokens(text);
  }

  _TokenizationResult _tokenizeRecognition(String text) {
    final tokens = _tokenizeToSemanticTokens(text);
    return _TokenizationResult(tokens);
  }

  List<_SemanticToken> _tokenizeToSemanticTokens(String text) {
    if (text.trim().isEmpty) {
      return const <_SemanticToken>[];
    }
    final rawTokens = _splitTokens(text);
    final tokens = <_SemanticToken>[];
    var index = 0;
    while (index < rawTokens.length) {
      final rawToken = rawTokens[index];
      if (rawToken.isOperatorSymbol) {
        final key = _operatorKeyFromSymbol(rawToken.raw);
        if (key != null) {
          tokens.add(_SemanticToken(display: rawToken.raw, key: key));
        }
        index += 1;
        continue;
      }

      final normalized = rawToken.normalized;
      if (normalized.isEmpty || _ignoredWords.contains(normalized)) {
        index += 1;
        continue;
      }

      final operatorKey = _operatorKeyFromWord(normalized);
      if (operatorKey != null) {
        tokens.add(_SemanticToken(display: rawToken.raw, key: operatorKey));
        index += 1;
        continue;
      }

      final numberParse = _parseNumberSequence(rawTokens, index);
      if (numberParse != null) {
        final display = rawTokens
            .sublist(index, index + numberParse.length)
            .map((token) => token.raw)
            .join(' ');
        tokens.add(
          _SemanticToken(display: display, key: _numKey(numberParse.value)),
        );
        index += numberParse.length;
        continue;
      }

      tokens.add(
        _SemanticToken(display: rawToken.raw, key: _wordKey(normalized)),
      );
      index += 1;
    }
    return tokens;
  }

  _NumberParseResult? _parseNumberSequence(List<_RawToken> tokens, int start) {
    if (start >= tokens.length) return null;
    final first = tokens[start];
    if (first.isOperatorSymbol) return null;
    final firstNormalized = first.normalized;
    if (firstNormalized.isEmpty) return null;

    final direct = int.tryParse(firstNormalized);
    if (direct != null) {
      return _NumberParseResult(value: direct, length: 1);
    }

    final lexicon = _lexiconForLanguage(_language);
    if (!lexicon.isNumberWord(firstNormalized)) {
      return null;
    }

    var total = 0;
    var current = 0;
    var index = start;
    var consumed = false;
    while (index < tokens.length) {
      final token = tokens[index];
      if (token.isOperatorSymbol) break;
      final word = token.normalized;
      if (word.isEmpty) {
        index += 1;
        continue;
      }
      if (lexicon.conjunctions.contains(word)) {
        final nextWord = _nextNumberWord(tokens, index + 1, lexicon);
        if (nextWord == null || !consumed) {
          break;
        }
        index += 1;
        continue;
      }
      final unit = lexicon.units[word];
      if (unit != null) {
        current += unit;
        consumed = true;
        index += 1;
        continue;
      }
      final tens = lexicon.tens[word];
      if (tens != null) {
        current += tens;
        consumed = true;
        index += 1;
        continue;
      }
      final scale = lexicon.scales[word];
      if (scale != null) {
        consumed = true;
        if (scale == 100) {
          if (current == 0) {
            current = 1;
          }
          current *= scale;
        } else {
          if (current == 0) {
            current = 1;
          }
          total += current * scale;
          current = 0;
        }
        index += 1;
        continue;
      }
      break;
    }
    if (!consumed) return null;
    return _NumberParseResult(value: total + current, length: index - start);
  }

  String? _nextNumberWord(
    List<_RawToken> tokens,
    int start,
    _NumberLexicon lexicon,
  ) {
    for (var i = start; i < tokens.length; i += 1) {
      final token = tokens[i];
      if (token.isOperatorSymbol) return null;
      final word = token.normalized;
      if (word.isEmpty) {
        continue;
      }
      if (lexicon.isNumberWord(word)) {
        return word;
      }
      return null;
    }
    return null;
  }

  List<_RawToken> _splitTokens(String text) {
    final tokenRegex = RegExp(r"[\p{L}\p{N}']+|[=+\-*/]", unicode: true);
    return tokenRegex.allMatches(text).map((match) {
      final raw = match.group(0) ?? '';
      final isOperator = _operatorSymbols.containsKey(raw);
      final normalized = isOperator ? '' : raw.normalizeAnswer();
      return _RawToken(raw, normalized, isOperator);
    }).toList();
  }

  _NumberLexicon _lexiconForLanguage(LearningLanguage language) {
    switch (language) {
      case LearningLanguage.spanish:
        return _spanishLexicon;
      case LearningLanguage.english:
        return _englishLexicon;
    }
  }
}

class _TokenizationResult {
  final List<_SemanticToken> tokens;

  const _TokenizationResult(this.tokens);

  List<String> get keys => [for (final token in tokens) token.key];

  List<String> get displayTokens => [for (final token in tokens) token.display];
}

class _SemanticToken {
  final String display;
  final String key;

  const _SemanticToken({required this.display, required this.key});
}

class _RawToken {
  final String raw;
  final String normalized;
  final bool isOperatorSymbol;

  const _RawToken(this.raw, this.normalized, this.isOperatorSymbol);
}

class _NumberParseResult {
  final int value;
  final int length;

  const _NumberParseResult({required this.value, required this.length});
}

class _NumberLexicon {
  final Map<String, int> units;
  final Map<String, int> tens;
  final Map<String, int> scales;
  final Set<String> conjunctions;

  const _NumberLexicon({
    required this.units,
    required this.tens,
    required this.scales,
    required this.conjunctions,
  });

  bool isNumberWord(String word) {
    return units.containsKey(word) ||
        tens.containsKey(word) ||
        scales.containsKey(word);
  }
}

const _operatorSymbols = {
  '+': 'PLUS',
  '-': 'MINUS',
  '*': 'MULTIPLY',
  '/': 'DIVIDE',
  '=': 'EQUALS',
};

const _operatorWords = {
  'plus': 'PLUS',
  'add': 'PLUS',
  'added': 'PLUS',
  'sum': 'PLUS',
  'mas': 'PLUS',
  'menos': 'MINUS',
  'minus': 'MINUS',
  'subtract': 'MINUS',
  'subtracted': 'MINUS',
  'times': 'MULTIPLY',
  'multiply': 'MULTIPLY',
  'multiplied': 'MULTIPLY',
  'por': 'MULTIPLY',
  'divide': 'DIVIDE',
  'divided': 'DIVIDE',
  'dividido': 'DIVIDE',
  'over': 'DIVIDE',
  'equal': 'EQUALS',
  'equals': 'EQUALS',
  'is': 'EQUALS',
  'igual': 'EQUALS',
  'es': 'EQUALS',
  'x': 'MULTIPLY',
};

const _ignoredWords = {
  'um',
  'uh',
  'erm',
  'ah',
  'eh',
  'please',
  'porfavor',
  'favor',
};

const _englishLexicon = _NumberLexicon(
  units: {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  },
  tens: {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  },
  scales: {'hundred': 100, 'thousand': 1000, 'million': 1000000},
  conjunctions: {'and'},
);

const _spanishLexicon = _NumberLexicon(
  units: {
    'cero': 0,
    'uno': 1,
    'un': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidos': 22,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
  },
  tens: {
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  },
  scales: {
    'cien': 100,
    'ciento': 100,
    'mil': 1000,
    'millon': 1000000,
    'millones': 1000000,
  },
  conjunctions: {'y'},
);

String? _operatorKeyFromSymbol(String symbol) {
  return _operatorSymbols[symbol];
}

String? _operatorKeyFromWord(String word) {
  return _operatorWords[word];
}

String _numKey(int value) => 'NUM:$value';

String _wordKey(String value) => 'WORD:$value';
