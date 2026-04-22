import '../../../languages/language_pack.dart';
import 'matching_token.dart';

class MatcherTextParser {
  MatcherTextParser(this._pack)
    : _numberPhraseLexicon = _resolveNumberPhraseLexicon(_pack);

  final LanguagePack _pack;
  final _NumberPhraseLexicon _numberPhraseLexicon;

  static final Map<String, _NumberPhraseLexicon> _phraseLexiconCache =
      <String, _NumberPhraseLexicon>{};

  static const int _generatedPhraseMaxValue = 10000;

  List<MatchingToken> tokenize(String text) {
    if (text.trim().isEmpty) {
      return const <MatchingToken>[];
    }
    final rawTokens = _splitTokens(text);
    final tokens = <MatchingToken>[];
    var index = 0;
    while (index < rawTokens.length) {
      final rawToken = rawTokens[index];
      if (rawToken.isOperatorSymbol) {
        final key = _operatorKeyFromSymbol(rawToken.raw);
        if (key != null) {
          tokens.add(
            MatchingToken(
              display: rawToken.raw,
              normalized: '',
              operatorKey: key,
            ),
          );
        }
        index += 1;
        continue;
      }

      final normalized = rawToken.normalized;
      if (normalized.isEmpty || _pack.ignoredWords.contains(normalized)) {
        index += 1;
        continue;
      }

      final operatorKey = _pack.operatorWords[normalized];
      if (operatorKey != null) {
        tokens.add(
          MatchingToken(
            display: rawToken.raw,
            normalized: '',
            operatorKey: operatorKey,
          ),
        );
        index += 1;
        continue;
      }

      final numberParse = _parseNumberSequence(rawTokens, index);
      if (numberParse != null) {
        final display = rawTokens
            .sublist(index, index + numberParse.length)
            .map((token) => token.raw)
            .join(' ');
        final normalizedDisplay = rawTokens
            .sublist(index, index + numberParse.length)
            .map((token) => token.normalized)
            .where((value) => value.isNotEmpty)
            .join(' ');
        tokens.add(
          MatchingToken(
            display: display,
            normalized: normalizedDisplay,
            numberValue: numberParse.value,
          ),
        );
        index += numberParse.length;
        continue;
      }

      tokens.add(MatchingToken(display: rawToken.raw, normalized: normalized));
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

    final phraseLimit = tokens.length - start;
    final maxLength = phraseLimit < _numberPhraseLexicon.maxWordCount
        ? phraseLimit
        : _numberPhraseLexicon.maxWordCount;
    for (var length = maxLength; length >= 1; length -= 1) {
      final phraseWords = <String>[];
      var valid = true;
      for (var offset = 0; offset < length; offset += 1) {
        final token = tokens[start + offset];
        if (token.isOperatorSymbol) {
          valid = false;
          break;
        }
        final word = token.normalized;
        if (word.isEmpty ||
            _pack.ignoredWords.contains(word) ||
            _pack.operatorWords.containsKey(word) ||
            int.tryParse(word) != null) {
          valid = false;
          break;
        }
        phraseWords.add(word);
      }
      if (!valid || phraseWords.isEmpty) continue;
      final phrase = phraseWords.join(' ');
      final value = _numberPhraseLexicon.phraseToValue[phrase];
      if (value != null) {
        return _NumberParseResult(value: value, length: length);
      }
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

  static _NumberPhraseLexicon _resolveNumberPhraseLexicon(LanguagePack pack) {
    return _phraseLexiconCache.putIfAbsent(
      pack.code,
      () => _buildNumberPhraseLexicon(pack),
    );
  }

  static _NumberPhraseLexicon _buildNumberPhraseLexicon(LanguagePack pack) {
    final phraseToValue = <String, int>{};
    final lexicon = pack.numberLexicon;

    void addPhrase(String phrase, int value) {
      final normalized = phrase.trim();
      if (normalized.isEmpty) return;
      phraseToValue.putIfAbsent(normalized, () => value);
    }

    for (var value = 0; value <= _generatedPhraseMaxValue; value += 1) {
      String words;
      try {
        words = pack.numberWordsConverter(value);
      } catch (_) {
        continue;
      }
      final normalized = pack.normalizer(words);
      if (normalized.isEmpty) continue;
      addPhrase(normalized, value);

      final withoutConjunction = normalized
          .split(_whitespaceRegex)
          .where(
            (word) => word.isNotEmpty && !lexicon.conjunctions.contains(word),
          )
          .join(' ');
      if (withoutConjunction.isNotEmpty && withoutConjunction != normalized) {
        addPhrase(withoutConjunction, value);
      }
    }

    for (final entry in lexicon.units.entries) {
      addPhrase(pack.normalizer(entry.key), entry.value);
    }
    for (final entry in lexicon.tens.entries) {
      addPhrase(pack.normalizer(entry.key), entry.value);
    }
    for (final entry in lexicon.scales.entries) {
      addPhrase(pack.normalizer(entry.key), entry.value);
    }

    var maxWordCount = 1;
    for (final phrase in phraseToValue.keys) {
      final words = phrase
          .split(_whitespaceRegex)
          .where((word) => word.isNotEmpty);
      final count = words.length;
      if (count > maxWordCount) {
        maxWordCount = count;
      }
    }

    return _NumberPhraseLexicon(
      phraseToValue: Map<String, int>.unmodifiable(phraseToValue),
      maxWordCount: maxWordCount,
    );
  }
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

class _NumberPhraseLexicon {
  final Map<String, int> phraseToValue;
  final int maxWordCount;

  const _NumberPhraseLexicon({
    required this.phraseToValue,
    required this.maxWordCount,
  });
}

const _operatorSymbols = {
  '+': 'PLUS',
  '-': 'MINUS',
  '*': 'MULTIPLY',
  '/': 'DIVIDE',
  '=': 'EQUALS',
};

String? _operatorKeyFromSymbol(String symbol) {
  return _operatorSymbols[symbol];
}

final _whitespaceRegex = RegExp(r'\s+');
