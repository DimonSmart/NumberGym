import 'package:flutter/foundation.dart';

@immutable
class MatchingToken {
  const MatchingToken({
    required this.display,
    required this.normalized,
  });

  final String display;
  final String normalized;
}

abstract class MatcherTokenizer {
  List<MatchingToken> tokenize(String text);
}
