class NumberLexicon {
  final Map<String, int> units;
  final Map<String, int> tens;
  final Map<String, int> scales;
  final Set<String> conjunctions;

  const NumberLexicon({
    required this.units,
    required this.tens,
    required this.scales,
    required this.conjunctions,
  });

  bool isNumberWord(String word) {
    return units.containsKey(word) ||
        tens.containsKey(word) ||
        scales.containsKey(word);
  }
}
