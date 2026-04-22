import '../base_language_profile.dart';
import 'matcher_tokenizer.dart';

class MatchResult {
  const MatchResult({
    required this.normalizedText,
    required this.recognizedTokens,
    required this.matchedSegmentIndices,
    required this.acceptedAnswer,
  });

  final String normalizedText;
  final List<String> recognizedTokens;
  final List<int> matchedSegmentIndices;
  final bool acceptedAnswer;
}

class AnswerMatcher {
  AnswerMatcher({
    required TextNormalizer normalizer,
    required MatcherTokenizer tokenizer,
  }) : _normalizer = normalizer,
       _tokenizer = tokenizer;

  final TextNormalizer _normalizer;
  final MatcherTokenizer _tokenizer;

  List<List<String>> _expectedSegments = const <List<String>>[];
  List<bool> _matchedSegments = const <bool>[];
  Set<String> _acceptedAnswers = const <String>{};
  List<String> _expectedTokens = const <String>[];

  List<String> get expectedTokens => _expectedTokens;
  List<bool> get matchedTokens => _matchedSegments;

  bool get isComplete {
    return _matchedSegments.isNotEmpty &&
        _matchedSegments.every((matched) => matched);
  }

  void reset({
    required String prompt,
    required List<String> answers,
    required List<String> promptAliases,
  }) {
    final expectedSegments = <List<String>>[];
    final displayTokens = <String>[];
    for (final token in _tokenizer.tokenize(prompt)) {
      expectedSegments.add(<String>[token.normalized]);
      displayTokens.add(token.display);
    }
    _expectedSegments = List<List<String>>.unmodifiable(expectedSegments);
    _expectedTokens = List<String>.unmodifiable(displayTokens);
    _matchedSegments = List<bool>.filled(_expectedSegments.length, false);

    final accepted = <String>{
      for (final answer in answers)
        if (_normalizer(answer).isNotEmpty) _normalizer(answer),
      if (_normalizer(prompt).isNotEmpty) _normalizer(prompt),
      for (final alias in promptAliases)
        if (_normalizer(alias).isNotEmpty) _normalizer(alias),
    };
    _acceptedAnswers = Set<String>.unmodifiable(accepted);
  }

  void clear() {
    _expectedSegments = const <List<String>>[];
    _expectedTokens = const <String>[];
    _matchedSegments = const <bool>[];
    _acceptedAnswers = const <String>{};
  }

  bool isAcceptedAnswer(String recognizedText) {
    final normalized = _normalizer(recognizedText);
    if (normalized.isEmpty) {
      return false;
    }
    return _acceptedAnswers.contains(normalized);
  }

  MatchResult previewRecognition(String recognizedText) {
    final normalizedText = _normalizer(recognizedText);
    final tokens = _tokenizer.tokenize(recognizedText);
    final displays = tokens.map((token) => token.display).toList();
    final matchedIndices = _matchIndices(tokens, mutate: false);
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: displays,
      matchedSegmentIndices: matchedIndices,
      acceptedAnswer: _acceptedAnswers.contains(normalizedText),
    );
  }

  MatchResult applyRecognition(String recognizedText) {
    final normalizedText = _normalizer(recognizedText);
    final tokens = _tokenizer.tokenize(recognizedText);
    final displays = tokens.map((token) => token.display).toList();

    if (normalizedText.isNotEmpty && _acceptedAnswers.contains(normalizedText)) {
      final all = <int>[];
      for (var i = 0; i < _matchedSegments.length; i += 1) {
        if (!_matchedSegments[i]) {
          all.add(i);
          _matchedSegments[i] = true;
        }
      }
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: displays,
        matchedSegmentIndices: all,
        acceptedAnswer: true,
      );
    }

    final matchedIndices = _matchIndices(tokens, mutate: true);
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: displays,
      matchedSegmentIndices: matchedIndices,
      acceptedAnswer: false,
    );
  }

  List<int> _matchIndices(List<MatchingToken> tokens, {required bool mutate}) {
    if (_expectedSegments.isEmpty || tokens.isEmpty) {
      return const <int>[];
    }
    final normalized = tokens.map((token) => token.normalized).toList();
    final matched = <int>[];
    for (var segmentIndex = 0; segmentIndex < _expectedSegments.length; segmentIndex += 1) {
      if (_matchedSegments[segmentIndex]) {
        continue;
      }
      final segment = _expectedSegments[segmentIndex];
      if (_containsSequence(normalized, segment)) {
        matched.add(segmentIndex);
        if (mutate) {
          _matchedSegments[segmentIndex] = true;
        }
      }
    }
    return matched;
  }

  bool _containsSequence(List<String> haystack, List<String> needle) {
    if (needle.isEmpty || haystack.length < needle.length) {
      return false;
    }
    for (var start = 0; start <= haystack.length - needle.length; start += 1) {
      var matches = true;
      for (var offset = 0; offset < needle.length; offset += 1) {
        if (haystack[start + offset] != needle[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
  }
}
