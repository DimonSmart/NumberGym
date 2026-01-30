String normalizeLatin(String text) {
  final trimmed = text.trim().toLowerCase();
  if (trimmed.isEmpty) return '';
  var normalized = trimmed;
  for (final entry in _latinReplacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  normalized = normalized.replaceAll(_nonWordRegex, ' ');
  return normalized.replaceAll(_whitespaceRegex, ' ').trim();
}

String normalizeHebrew(String text) {
  final trimmed = text.trim().toLowerCase();
  if (trimmed.isEmpty) return '';
  var normalized = trimmed.replaceAll(_hebrewDiacriticsRegex, '');
  normalized = normalized.replaceAll(_nonWordRegex, ' ');
  return normalized.replaceAll(_whitespaceRegex, ' ').trim();
}

final _nonWordRegex = RegExp(r"[^\p{L}\p{N}\s]", unicode: true);
final _whitespaceRegex = RegExp(r'\s+');
final _hebrewDiacriticsRegex =
    RegExp(r'[\u0591-\u05BD\u05BF\u05C1-\u05C2\u05C4-\u05C5\u05C7]');

const Map<String, String> _latinReplacements = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};
