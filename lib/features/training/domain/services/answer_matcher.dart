import '../../languages/language_pack.dart';
import '../../languages/registry.dart';
import '../learning_language.dart';
import 'matching/matching_token.dart';
import 'matching/matcher_text_parser.dart';

class MatchResult {
  final String normalizedText;
  final List<String> recognizedTokens;
  final List<int> matchedSegmentIndices;
  final bool acceptedAnswer;

  const MatchResult({
    required this.normalizedText,
    required this.recognizedTokens,
    required this.matchedSegmentIndices,
    required this.acceptedAnswer,
  });

  bool get matchedAny => matchedSegmentIndices.isNotEmpty;
}

class AnswerMatcher {
  List<_EtalonAtom> _atoms = const [];
  List<String> _expectedTokens = const [];
  List<bool> _matchedTokens = const [];
  int _requiredAtomCount = 0;
  Set<String> _acceptedAnswers = {};
  LanguagePack _pack = LanguageRegistry.of(LearningLanguage.english);
  late MatcherTextParser _parser = MatcherTextParser(_pack);
  final _EtalonMatcher _matcher = const _EtalonMatcher();

  List<String> get expectedTokens => _expectedTokens;
  List<bool> get matchedTokens => _matchedTokens;

  bool get isComplete {
    if (_atoms.isEmpty || _requiredAtomCount == 0) {
      return false;
    }
    var matchedRequired = 0;
    for (var i = 0; i < _atoms.length; i += 1) {
      if (_atoms[i].isRequired && _matchedTokens[i]) {
        matchedRequired += 1;
        if (matchedRequired >= _requiredAtomCount) {
          return true;
        }
      }
    }
    return matchedRequired >= _requiredAtomCount;
  }

  bool isAcceptedAnswer(String recognizedText) {
    final normalizedText = _pack.normalizer(recognizedText);
    if (normalizedText.isEmpty) {
      return false;
    }
    return _acceptedAnswers.contains(normalizedText);
  }

  void reset({
    required String prompt,
    required List<String> answers,
    required LearningLanguage language,
  }) {
    _pack = LanguageRegistry.of(language);
    _parser = MatcherTextParser(_pack);
    _atoms = _EtalonParser(_parser).parse(prompt);
    if (!_hasEtalonSyntax(prompt) &&
        _atoms.length == 1 &&
        _atoms.first.isMatchable &&
        answers.isNotEmpty) {
      final extraVariants = _buildVariantsFromTexts(_parser, answers);
      if (extraVariants.isNotEmpty) {
        final merged = _mergeVariants(_atoms.first.variants, extraVariants);
        _atoms = <_EtalonAtom>[_atoms.first.copyWithVariants(merged)];
      }
    }
    _expectedTokens = _atoms.map((atom) => atom.displayText).toList();
    _matchedTokens = List<bool>.filled(_atoms.length, false);
    _requiredAtomCount = _atoms.where((atom) => atom.isRequired).length;
    final normalized = <String>{
      for (final answer in answers) _pack.normalizer(answer),
      if (prompt.isNotEmpty) _pack.normalizer(prompt),
      for (final alias in _buildPromptAliases(prompt, language))
        _pack.normalizer(alias),
    }..removeWhere((value) => value.isEmpty);
    _acceptedAnswers = normalized;
  }

  void clear() {
    _atoms = const [];
    _expectedTokens = const [];
    _matchedTokens = const [];
    _requiredAtomCount = 0;
    _acceptedAnswers = {};
    _pack = LanguageRegistry.of(LearningLanguage.english);
    _parser = MatcherTextParser(_pack);
  }

  MatchResult applyRecognition(String recognizedText) {
    final normalizedText = _pack.normalizer(recognizedText);
    final tokens = _parser.tokenize(recognizedText);
    final recognizedTokens = tokens.map((token) => token.display).toList();

    if (normalizedText.isEmpty || _atoms.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedSegmentIndices: const <int>[],
        acceptedAnswer: false,
      );
    }

    if (_acceptedAnswers.contains(normalizedText)) {
      final indices = _markAllMatched();
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedSegmentIndices: indices,
        acceptedAnswer: true,
      );
    }

    if (tokens.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedSegmentIndices: const <int>[],
        acceptedAnswer: false,
      );
    }

    final matchedIndices = _matcher.match(
      atoms: _atoms,
      tokens: tokens,
      matched: _matchedTokens,
    );
    if (matchedIndices.isNotEmpty) {
      _applyMatchedAtoms(matchedIndices);
    }
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: recognizedTokens,
      matchedSegmentIndices: matchedIndices,
      acceptedAnswer: false,
    );
  }

  MatchResult previewRecognition(String recognizedText) {
    final normalizedText = _pack.normalizer(recognizedText);
    final tokens = _parser.tokenize(recognizedText);
    final recognizedTokens = tokens.map((token) => token.display).toList();

    if (normalizedText.isEmpty || _atoms.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedSegmentIndices: const <int>[],
        acceptedAnswer: false,
      );
    }
    if (tokens.isEmpty) {
      return MatchResult(
        normalizedText: normalizedText,
        recognizedTokens: recognizedTokens,
        matchedSegmentIndices: const <int>[],
        acceptedAnswer: false,
      );
    }
    final matchedIndices = _matcher.match(
      atoms: _atoms,
      tokens: tokens,
      matched: _matchedTokens,
    );
    return MatchResult(
      normalizedText: normalizedText,
      recognizedTokens: recognizedTokens,
      matchedSegmentIndices: matchedIndices,
      acceptedAnswer: false,
    );
  }

  List<int> _markAllMatched() {
    if (_atoms.isEmpty) {
      return const <int>[];
    }
    final indices = <int>[];
    for (var i = 0; i < _matchedTokens.length; i += 1) {
      if (!_matchedTokens[i]) {
        indices.add(i);
      }
    }
    _matchedTokens = List<bool>.filled(_atoms.length, true);
    return indices;
  }

  void _applyMatchedAtoms(List<int> indices) {
    if (indices.isEmpty) return;
    for (final index in indices) {
      if (index >= 0 && index < _matchedTokens.length) {
        _matchedTokens[index] = true;
      }
    }
  }

  bool _hasEtalonSyntax(String text) {
    return text.contains('(') || text.contains('[') || text.contains('{');
  }

  List<String> _buildPromptAliases(String prompt, LearningLanguage language) {
    if (language != LearningLanguage.english) {
      return const <String>[];
    }
    final match = RegExp(r'^\s*(\d{1,2}):00\s*$').firstMatch(prompt);
    if (match == null) {
      return const <String>[];
    }
    final hourValue = int.tryParse(match.group(1) ?? '');
    if (hourValue == null) {
      return const <String>[];
    }
    return <String>['$hourValue o clock'];
  }

  List<_AtomVariant> _mergeVariants(
    List<_AtomVariant> base,
    List<_AtomVariant> extra,
  ) {
    final merged = <_AtomVariant>[];
    final seen = <String>{};

    void addAll(List<_AtomVariant> variants) {
      for (final variant in variants) {
        final signature = variant.signature();
        if (seen.add(signature)) {
          merged.add(variant);
        }
      }
    }

    addAll(base);
    addAll(extra);
    merged.sort((a, b) => b.tokens.length.compareTo(a.tokens.length));
    return merged;
  }
}

class _EtalonAtom {
  final String displayText;
  final List<_AtomVariant> variants;
  final bool isMatchable;
  final bool isOptional;

  const _EtalonAtom._({
    required this.displayText,
    required this.variants,
    required this.isMatchable,
    required this.isOptional,
  });

  bool get isRequired => isMatchable && !isOptional;

  factory _EtalonAtom.literal({
    required String displayText,
    required List<_AtomVariant> variants,
  }) {
    return _EtalonAtom._(
      displayText: displayText,
      variants: variants,
      isMatchable: true,
      isOptional: false,
    );
  }

  factory _EtalonAtom.optional({
    required String displayText,
    required List<_AtomVariant> variants,
  }) {
    return _EtalonAtom._(
      displayText: displayText,
      variants: variants,
      isMatchable: true,
      isOptional: true,
    );
  }

  factory _EtalonAtom.decorative(String displayText) {
    return _EtalonAtom._(
      displayText: displayText,
      variants: const <_AtomVariant>[],
      isMatchable: false,
      isOptional: true,
    );
  }

  _EtalonAtom copyWithVariants(List<_AtomVariant> variants) {
    return _EtalonAtom._(
      displayText: displayText,
      variants: variants,
      isMatchable: isMatchable,
      isOptional: isOptional,
    );
  }
}

class _AtomVariant {
  final List<_AtomToken> tokens;

  const _AtomVariant({required this.tokens});

  String signature() {
    return tokens.map((token) => token.signature()).join('|');
  }
}

class _AtomToken {
  final String normalized;
  final int? numberValue;
  final String? operatorKey;

  const _AtomToken({
    required this.normalized,
    this.numberValue,
    this.operatorKey,
  });

  factory _AtomToken.fromMatchingToken(MatchingToken token) {
    return _AtomToken(
      normalized: token.normalized,
      numberValue: token.numberValue,
      operatorKey: token.operatorKey,
    );
  }

  String signature() {
    if (operatorKey != null) return 'op:$operatorKey';
    if (numberValue != null) return 'num:$numberValue';
    return 'lit:$normalized';
  }

  static _AtomToken literal(String normalized) {
    return _AtomToken(normalized: normalized);
  }
}

class _EtalonParser {
  _EtalonParser(this._parser);

  final MatcherTextParser _parser;

  List<_EtalonAtom> parse(String pattern) {
    if (pattern.trim().isEmpty) return const <_EtalonAtom>[];

    final atoms = <_EtalonAtom>[];
    final literal = StringBuffer();

    void flushLiteral() {
      if (literal.isEmpty) return;
      atoms.addAll(_atomsFromLiteral(literal.toString()));
      literal.clear();
    }

    for (var i = 0; i < pattern.length; i += 1) {
      final ch = pattern[i];

      if (ch == '(') {
        flushLiteral();
        final end = pattern.indexOf(')', i + 1);
        if (end < 0) {
          literal.write(ch);
          continue;
        }
        final inner = pattern.substring(i + 1, end).trim();
        if (inner.isNotEmpty) {
          atoms.add(_EtalonAtom.decorative(inner));
        }
        i = end;
        continue;
      }

      if (ch == '[') {
        flushLiteral();
        final end = pattern.indexOf(']', i + 1);
        if (end < 0) {
          literal.write(ch);
          continue;
        }
        final inner = pattern.substring(i + 1, end);
        final atom = _buildVariantAtom(inner, isOptional: false);
        if (atom != null) {
          atoms.add(atom);
        }
        i = end;
        continue;
      }

      if (ch == '{') {
        flushLiteral();
        final end = pattern.indexOf('}', i + 1);
        if (end < 0) {
          literal.write(ch);
          continue;
        }
        final inner = pattern.substring(i + 1, end);
        final atom = _buildVariantAtom(inner, isOptional: true);
        if (atom != null) {
          atoms.add(atom);
        }
        i = end;
        continue;
      }

      literal.write(ch);
    }

    flushLiteral();
    return atoms;
  }

  List<_EtalonAtom> _atomsFromLiteral(String text) {
    final atoms = <_EtalonAtom>[];
    for (final part in _splitLiteral(text)) {
      if (part.trim().isEmpty) continue;
      if (_containsLettersOrDigits(part)) {
        final variants = _buildVariantsFromTexts(_parser, [part]);
        if (variants.isEmpty) {
          continue;
        }
        atoms.add(_EtalonAtom.literal(displayText: part, variants: variants));
        continue;
      }
      atoms.add(_EtalonAtom.decorative(part));
    }
    return atoms;
  }

  _EtalonAtom? _buildVariantAtom(String raw, {required bool isOptional}) {
    final options = raw
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (options.isEmpty) {
      return null;
    }
    final variants = _buildVariantsFromTexts(_parser, options);
    if (variants.isEmpty) {
      return null;
    }
    final display = options.first;
    return isOptional
        ? _EtalonAtom.optional(displayText: display, variants: variants)
        : _EtalonAtom.literal(displayText: display, variants: variants);
  }

  List<String> _splitLiteral(String text) {
    final matches = _literalChunkRegex.allMatches(text);
    if (matches.isEmpty) return const <String>[];
    return matches
        .map((match) => match.group(0) ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
  }

  bool _containsLettersOrDigits(String text) {
    return _letterDigitRegex.hasMatch(text);
  }
}

class _EtalonMatcher {
  const _EtalonMatcher();

  List<int> match({
    required List<_EtalonAtom> atoms,
    required List<MatchingToken> tokens,
    required List<bool> matched,
  }) {
    if (atoms.isEmpty || tokens.isEmpty) {
      return const <int>[];
    }

    final used = List<bool>.filled(tokens.length, false);
    final matchedNow = <int>[];
    final matchedLocal = List<bool>.from(matched);

    while (true) {
      _MatchCandidate? best;

      for (var atomIndex = 0; atomIndex < atoms.length; atomIndex += 1) {
        final atom = atoms[atomIndex];
        if (!atom.isMatchable || matchedLocal[atomIndex]) continue;

        for (final variant in atom.variants) {
          final consumed = _tryMatch(tokens, used, variant.tokens);
          if (consumed == null) continue;

          final candidate = _MatchCandidate(atomIndex, consumed);
          if (best == null ||
              candidate.consumed.length > best.consumed.length) {
            best = candidate;
          }
        }
      }

      if (best == null) break;
      if (matchedLocal[best.atomIndex]) break;

      matchedLocal[best.atomIndex] = true;
      for (final index in best.consumed) {
        used[index] = true;
      }
      matchedNow.add(best.atomIndex);
    }

    matchedNow.sort();
    return matchedNow;
  }

  List<int>? _tryMatch(
    List<MatchingToken> tokens,
    List<bool> used,
    List<_AtomToken> needTokens,
  ) {
    if (needTokens.isEmpty) return null;

    final need = <String, int>{};
    for (final token in needTokens) {
      final key = token.signature();
      need[key] = (need[key] ?? 0) + 1;
    }

    final picked = <int>[];
    for (var i = tokens.length - 1; i >= 0; i -= 1) {
      if (used[i]) continue;
      final key = _AtomToken.fromMatchingToken(tokens[i]).signature();
      final count = need[key];
      if (count == null || count <= 0) continue;
      need[key] = count - 1;
      picked.add(i);
    }

    for (final count in need.values) {
      if (count > 0) {
        return null;
      }
    }

    picked.sort();
    return picked;
  }
}

class _MatchCandidate {
  final int atomIndex;
  final List<int> consumed;

  const _MatchCandidate(this.atomIndex, this.consumed);
}

final _literalChunkRegex = RegExp(r'\s+|[^\s]+', unicode: true);
final _letterDigitRegex = RegExp(r'[\p{L}\p{N}]', unicode: true);

List<_AtomVariant> _buildVariantsFromTexts(
  MatcherTextParser parser,
  Iterable<String> texts,
) {
  final variants = <_AtomVariant>[];
  final seen = <String>{};
  for (final text in texts) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;
    final tokens = parser.tokenize(trimmed);
    if (tokens.isEmpty) continue;
    final variantTokens = _variantTokensForText(trimmed, tokens);
    final variant = _AtomVariant(tokens: variantTokens);
    final signature = variant.signature();
    if (seen.add(signature)) {
      variants.add(variant);
    }
  }
  variants.sort((a, b) => b.tokens.length.compareTo(a.tokens.length));
  return variants;
}

List<_AtomToken> _variantTokensForText(
  String text,
  List<MatchingToken> tokens,
) {
  if (tokens.length == 1) {
    final token = tokens.first;
    if (token.numberValue != null &&
        text.trim().contains(' ') &&
        token.normalized.contains(' ')) {
      return <_AtomToken>[_AtomToken.literal(token.normalized)];
    }
  }
  return tokens.map(_AtomToken.fromMatchingToken).toList();
}
