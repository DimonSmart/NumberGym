import 'package:flutter/foundation.dart';

@immutable
class MatchingToken {
  const MatchingToken({
    required this.display,
    required this.normalized,
    this.numberValue,
    this.operatorKey,
  });

  final String display;
  final String normalized;
  final int? numberValue;
  final String? operatorKey;
}

abstract class MatcherTokenizer {
  List<MatchingToken> tokenize(String text);
}
