import '../../languages/language_pack.dart';
import '../../languages/number_lexicon.dart';
import '../../languages/registry.dart';
import '../../languages/time_lexicon.dart';
import '../learning_language.dart';
import '../time_value.dart';

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
  LanguagePack _pack = LanguageRegistry.of(LearningLanguage.english);
  bool _expectsTime = false;

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
    _pack = LanguageRegistry.of(language);
    final expected = _tokenizeExpected(prompt);
    _expectedTokens = expected.map((token) => token.display).toList();
    _expectedKeys = expected.map((token) => token.key).toList();
    _matchedTokens = List<bool>.filled(_expectedTokens.length, false);
    _matchedTokenCount = 0;
    final normalized = <String>{
      for (final answer in answers) _pack.normalizer(answer),
      if (prompt.isNotEmpty) _pack.normalizer(prompt),
    }..removeWhere((value) => value.isEmpty);
    _acceptedAnswers = normalized;
    _expectsTime = _looksLikeTime(prompt, answers);
  }

  void clear() {
    _expectedTokens = const [];
    _expectedKeys = const [];
    _matchedTokens = const [];
    _matchedTokenCount = 0;
    _acceptedAnswers = {};
    _pack = LanguageRegistry.of(LearningLanguage.english);
    _expectsTime = false;
  }

  MatchResult applyRecognition(String recognizedText) {
    final resolvedText = _maybeCanonicalizeTime(recognizedText);
    final normalizedText = _pack.normalizer(resolvedText);
    final tokenization = _tokenizeRecognition(resolvedText);
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

    if (_acceptedAnswers.contains(normalizedText)) {
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
    final resolvedText = _maybeCanonicalizeTime(recognizedText);
    final normalizedText = _pack.normalizer(resolvedText);
    final tokenization = _tokenizeRecognition(resolvedText);
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
      if (normalized.isEmpty || _pack.ignoredWords.contains(normalized)) {
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

    final lexicon = _pack.numberLexicon;
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
    NumberLexicon lexicon,
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
      final normalized = isOperator ? '' : _pack.normalizer(raw);
      return _RawToken(raw, normalized, isOperator);
    }).toList();
  }

  String _maybeCanonicalizeTime(String text) {
    if (!_expectsTime) return text;
    final parsed = _parseTimeText(text);
    if (parsed == null) return text;
    return _pack.timeWordsConverter(
      TimeValue(hour: parsed.hour, minute: parsed.minute),
    );
  }

  bool _looksLikeTime(String prompt, List<String> answers) {
    final lexicon = _pack.timeLexicon;
    if (_containsTimeDigits(prompt) ||
        _containsTimeWords(prompt, lexicon)) {
      return true;
    }
    for (final answer in answers) {
      if (_containsTimeDigits(answer) ||
          _containsTimeWords(answer, lexicon)) {
        return true;
      }
    }
    return false;
  }

  bool _containsTimeDigits(String text) {
    return _timeDigitsRegex.hasMatch(text) ||
        _timeDigitsLooseRegex.hasMatch(text);
  }

  bool _containsTimeWords(String text, TimeLexicon lexicon) {
    if (text.trim().isEmpty) return false;
    final tokens = _splitTokens(text);
    for (final token in tokens) {
      final normalized = token.normalized;
      if (normalized.isEmpty) continue;
      if (_isStrongTimeWord(normalized, lexicon)) {
        return true;
      }
    }
    return false;
  }

  bool _isStrongTimeWord(String word, TimeLexicon lexicon) {
    return lexicon.quarterWords.contains(word) ||
        lexicon.halfWords.contains(word) ||
        lexicon.pastWords.contains(word) ||
        lexicon.toWords.contains(word) ||
        lexicon.oclockWords.contains(word);
  }

  _TimeParseResult? _parseTimeText(String text) {
    final lexicon = _pack.timeLexicon;
    final tokens = _filterTimeTokens(text, lexicon);
    if (tokens.isEmpty) return null;

    for (var i = 0; i < tokens.length; i += 1) {
      final minutePhrase = _parseMinutePhrase(tokens, i, lexicon);
      if (minutePhrase == null) continue;
      var index = _skipTimeConnectors(tokens, i + minutePhrase.length, lexicon);
      if (index >= tokens.length) continue;
      final relation = tokens[index].normalized;
      final isPast = lexicon.pastWords.contains(relation);
      final isTo = lexicon.toWords.contains(relation);
      if (!isPast && !isTo) continue;
      index = _skipTimeConnectors(tokens, index + 1, lexicon);
      final hourParse = _parseHourSequence(tokens, index);
      if (hourParse == null) continue;
      final result = _buildTime(
        hour: hourParse.value,
        minute: minutePhrase.value,
        isTo: isTo,
      );
      if (result != null) return result;
    }

    for (var i = 0; i < tokens.length; i += 1) {
      final hourParse = _parseHourSequence(tokens, i);
      if (hourParse == null) continue;
      var index = _skipTimeConnectors(tokens, i + hourParse.length, lexicon);
      if (index >= tokens.length) {
        return _buildTime(hour: hourParse.value, minute: 0, isTo: false);
      }
      final relation = tokens[index].normalized;
      final isPast = lexicon.pastWords.contains(relation);
      final isTo = lexicon.toWords.contains(relation);
      if (isPast || isTo) {
        index = _skipTimeConnectors(tokens, index + 1, lexicon);
        final minutePhrase = _parseMinutePhrase(tokens, index, lexicon);
        if (minutePhrase == null) continue;
        final result = _buildTime(
          hour: hourParse.value,
          minute: minutePhrase.value,
          isTo: isTo,
        );
        if (result != null) return result;
        continue;
      }

      if (lexicon.oclockWords.contains(relation)) {
        final nextIndex = _skipTimeConnectors(tokens, index + 1, lexicon);
        final minutePhrase = _parseMinutePhrase(tokens, nextIndex, lexicon);
        if (minutePhrase != null) {
          final result = _buildTime(
            hour: hourParse.value,
            minute: minutePhrase.value,
            isTo: false,
          );
          if (result != null) return result;
        }
        return _buildTime(hour: hourParse.value, minute: 0, isTo: false);
      }

      final minutePhrase = _parseMinutePhrase(tokens, index, lexicon);
      if (minutePhrase != null) {
        final result = _buildTime(
          hour: hourParse.value,
          minute: minutePhrase.value,
          isTo: false,
        );
        if (result != null) return result;
      }
    }

    return null;
  }

  List<_RawToken> _filterTimeTokens(String text, TimeLexicon lexicon) {
    final rawTokens = _splitTokens(text);
    final tokens = <_RawToken>[];
    for (final token in rawTokens) {
      if (token.isOperatorSymbol) continue;
      final normalized = token.normalized;
      if (normalized.isEmpty) continue;
      if (_pack.ignoredWords.contains(normalized)) continue;
      if (lexicon.fillerWords.contains(normalized)) continue;
      tokens.add(token);
    }
    return tokens;
  }

  int _skipTimeConnectors(
    List<_RawToken> tokens,
    int start,
    TimeLexicon lexicon,
  ) {
    var index = start;
    while (index < tokens.length) {
      final word = tokens[index].normalized;
      if (word.isEmpty || lexicon.connectorWords.contains(word)) {
        index += 1;
        continue;
      }
      break;
    }
    return index;
  }

  _TimeMinuteParse? _parseMinutePhrase(
    List<_RawToken> tokens,
    int start,
    TimeLexicon lexicon,
  ) {
    if (start >= tokens.length) return null;
    final word = tokens[start].normalized;
    if (lexicon.quarterWords.contains(word)) {
      return const _TimeMinuteParse(value: 15, length: 1);
    }
    if (lexicon.halfWords.contains(word)) {
      return const _TimeMinuteParse(value: 30, length: 1);
    }
    final numberParse = _parseNumberSequence(tokens, start);
    if (numberParse == null) return null;
    if (numberParse.value < 0 || numberParse.value > 59) return null;
    return _TimeMinuteParse(
      value: numberParse.value,
      length: numberParse.length,
    );
  }

  _NumberParseResult? _parseHourSequence(List<_RawToken> tokens, int start) {
    final numberParse = _parseNumberSequence(tokens, start);
    if (numberParse == null) return null;
    if (numberParse.value < 0 || numberParse.value > 23) return null;
    return numberParse;
  }

  _TimeParseResult? _buildTime({
    required int hour,
    required int minute,
    required bool isTo,
  }) {
    if (minute < 0 || minute > 59) return null;
    var resolvedHour = hour;
    var resolvedMinute = minute;
    if (isTo) {
      if (minute == 0) return null;
      resolvedMinute = 60 - minute;
      resolvedHour = hour - 1;
    }
    if (resolvedMinute < 0 || resolvedMinute > 59) return null;
    resolvedHour = resolvedHour % 24;
    if (resolvedHour < 0) {
      resolvedHour += 24;
    }
    return _TimeParseResult(hour: resolvedHour, minute: resolvedMinute);
  }

  String? _operatorKeyFromWord(String word) {
    return _pack.operatorWords[word];
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

class _TimeParseResult {
  final int hour;
  final int minute;

  const _TimeParseResult({required this.hour, required this.minute});
}

class _TimeMinuteParse {
  final int value;
  final int length;

  const _TimeMinuteParse({required this.value, required this.length});
}


const _operatorSymbols = {
  '+': 'PLUS',
  '-': 'MINUS',
  '*': 'MULTIPLY',
  '/': 'DIVIDE',
  '=': 'EQUALS',
};

final _timeDigitsRegex = RegExp(r'\b\d{1,2}\s*[:.]\s*\d{2}\b');
final _timeDigitsLooseRegex = RegExp(r'\b\d{1,2}\s+\d{2}\b');


String? _operatorKeyFromSymbol(String symbol) {
  return _operatorSymbols[symbol];
}

String _numKey(int value) => 'NUM:$value';

String _wordKey(String value) => 'WORD:$value';
