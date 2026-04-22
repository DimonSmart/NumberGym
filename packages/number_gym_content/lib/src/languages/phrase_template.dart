class PhraseTemplate {
  final int id;
  final String templateText;
  final int minValue;
  final int maxValue;

  const PhraseTemplate({
    required this.id,
    required this.templateText,
    required this.minValue,
    required this.maxValue,
  });

  bool supports(int value) => value >= minValue && value <= maxValue;

  String materialize(int value) =>
      templateText.replaceAll('{X}', value.toString());
}
