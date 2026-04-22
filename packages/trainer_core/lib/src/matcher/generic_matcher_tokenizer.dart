import 'matcher_tokenizer.dart';

class GenericMatcherTokenizer implements MatcherTokenizer {
  GenericMatcherTokenizer(this._normalizer);

  final String Function(String text) _normalizer;

  static final RegExp _tokenRegex = RegExp(r"[\p{L}\p{N}'+:.-]+", unicode: true);

  @override
  List<MatchingToken> tokenize(String text) {
    if (text.trim().isEmpty) {
      return const <MatchingToken>[];
    }
    final matches = _tokenRegex.allMatches(text);
    if (matches.isEmpty) {
      return const <MatchingToken>[];
    }
    final tokens = <MatchingToken>[];
    for (final match in matches) {
      final display = match.group(0) ?? '';
      final normalized = _normalizer(display);
      if (normalized.isEmpty) {
        continue;
      }
      tokens.add(MatchingToken(display: display, normalized: normalized));
    }
    return tokens;
  }
}
