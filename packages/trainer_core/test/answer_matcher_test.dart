import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_core/trainer_core.dart';

void main() {
  test('matches grouped phone chunks with semantic tokens', () {
    final matcher =
        AnswerMatcher(normalizer: _normalize, tokenizer: const _TestTokenizer())
          ..reset(
            prompt: '+34 555 22 11',
            answers: const <String>[],
            promptAliases: const <String>[],
          );

    final result = matcher.applyRecognition('plus thirty four 555 22 11');

    expect(
      matcher.expectedTokens,
      equals(const <String>['+34', '555', '22', '11']),
    );
    expect(result.matchedSegmentIndices, equals(const <int>[0, 1, 2, 3]));
    expect(matcher.isComplete, isTrue);
  });
}

String _normalize(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _TestTokenizer implements MatcherTokenizer {
  const _TestTokenizer();

  @override
  List<MatchingToken> tokenize(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return const <MatchingToken>[];
    }

    final rawParts = normalized.split(' ');
    final tokens = <MatchingToken>[];
    var index = 0;
    while (index < rawParts.length) {
      final part = rawParts[index];
      if (part.startsWith('+') && part.length > 1) {
        tokens.add(
          MatchingToken(display: part, normalized: '', operatorKey: 'PLUS'),
        );
        tokens.add(
          MatchingToken(
            display: part.substring(1),
            normalized: part.substring(1),
            numberValue: int.parse(part.substring(1)),
          ),
        );
        index += 1;
        continue;
      }
      if (part == 'plus') {
        tokens.add(
          const MatchingToken(
            display: 'plus',
            normalized: '',
            operatorKey: 'PLUS',
          ),
        );
        index += 1;
        continue;
      }
      if (part == 'thirty' &&
          index + 1 < rawParts.length &&
          rawParts[index + 1] == 'four') {
        tokens.add(
          const MatchingToken(
            display: 'thirty four',
            normalized: 'thirty four',
            numberValue: 34,
          ),
        );
        index += 2;
        continue;
      }
      final numeric = int.tryParse(part);
      if (numeric != null) {
        tokens.add(
          MatchingToken(display: part, normalized: part, numberValue: numeric),
        );
        index += 1;
        continue;
      }
      tokens.add(MatchingToken(display: part, normalized: part));
      index += 1;
    }
    return tokens;
  }
}
