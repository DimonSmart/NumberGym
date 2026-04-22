class TimeLexicon {
  final Set<String> quarterWords;
  final Set<String> halfWords;
  final Set<String> pastWords;
  final Set<String> toWords;
  final Set<String> oclockWords;
  final Set<String> connectorWords;
  final Set<String> fillerWords;
  final Set<String> specialTimeWords;

  const TimeLexicon({
    required this.quarterWords,
    required this.halfWords,
    required this.pastWords,
    required this.toWords,
    required this.oclockWords,
    required this.connectorWords,
    required this.fillerWords,
    this.specialTimeWords = const {},
  });

  bool isTimeWord(String word) {
    return quarterWords.contains(word) ||
        halfWords.contains(word) ||
        pastWords.contains(word) ||
        toWords.contains(word) ||
        oclockWords.contains(word) ||
        connectorWords.contains(word) ||
        fillerWords.contains(word) ||
        specialTimeWords.contains(word);
  }
}
