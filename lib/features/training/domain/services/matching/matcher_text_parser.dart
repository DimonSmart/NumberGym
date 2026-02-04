import '../../../languages/language_pack.dart';
import '../../../languages/number_lexicon.dart';
import 'matching_token.dart';

class MatcherTextParser {
  MatcherTextParser(this._pack);

  final LanguagePack _pack;

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

      tokens.add(
        MatchingToken(display: rawToken.raw, normalized: normalized),
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
