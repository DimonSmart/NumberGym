extension StringNormalization on String {
  String normalizeAnswer() {
    final trimmed = trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final withoutDiacritics = trimmed.stripDiacritics();
    final cleaned = withoutDiacritics.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String stripDiacritics() {
    return replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f1', 'n');
  }
}
