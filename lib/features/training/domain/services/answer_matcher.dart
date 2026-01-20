import '../../../../core/utils/string_extensions.dart';

class AnswerMatcher {
  List<String> _expectedTokens = const [];
  List<bool> _matchedTokens = const [];
  int _matchedTokenCount = 0;
  Set<String> _acceptedAnswers = {};

  List<String> get expectedTokens => _expectedTokens;
  List<bool> get matchedTokens => _matchedTokens;

  bool get isComplete {
    return _expectedTokens.isNotEmpty &&
        _matchedTokenCount == _expectedTokens.length;
  }

  void reset({
    required String prompt,
    required List<String> answers,
  }) {
    _expectedTokens = _tokenize(prompt);
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
    _matchedTokens = const [];
    _matchedTokenCount = 0;
    _acceptedAnswers = {};
  }

  bool applyRecognition(String recognizedText) {
    final normalizedText = recognizedText.normalizeAnswer();
    if (normalizedText.isEmpty || _expectedTokens.isEmpty) {
      return false;
    }
    if (_acceptedAnswers.contains(normalizedText)) {
      if (_matchedTokenCount != _expectedTokens.length) {
        _matchedTokens = List<bool>.filled(_expectedTokens.length, true);
        _matchedTokenCount = _expectedTokens.length;
      }
      return true;
    }

    final recognizedTokens = _tokenize(normalizedText);
    if (recognizedTokens.isEmpty) {
      return false;
    }

    var matchedAny = false;
    for (final token in recognizedTokens) {
      final index = _firstUnmatchedIndex(token);
      if (index != -1) {
        _matchedTokens[index] = true;
        _matchedTokenCount += 1;
        matchedAny = true;
      }
    }
    return matchedAny;
  }

  List<String> _tokenize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return trimmed.split(RegExp(r'\s+'));
  }

  int _firstUnmatchedIndex(String token) {
    for (var i = 0; i < _expectedTokens.length; i++) {
      if (!_matchedTokens[i] && _expectedTokens[i] == token) {
        return i;
      }
    }
    return -1;
  }
}
