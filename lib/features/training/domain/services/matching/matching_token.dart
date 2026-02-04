class MatchingToken {
  final String display;
  final String normalized;
  final int? numberValue;
  final String? operatorKey;

  const MatchingToken({
    required this.display,
    required this.normalized,
    this.numberValue,
    this.operatorKey,
  });
}
