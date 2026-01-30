enum TrainingItemType {
  digits,
  base,
  hundreds,
  thousands,
}

class TrainingItemId implements Comparable<TrainingItemId> {
  const TrainingItemId({
    required this.type,
    required this.number,
  });

  final TrainingItemType type;
  final int? number;

  String get storageKey {
    final suffix = number == null ? '*' : number.toString();
    return '${type.name}:$suffix';
  }

  @override
  String toString() => storageKey;

  @override
  bool operator ==(Object other) {
    return other is TrainingItemId &&
        other.type == type &&
        other.number == number;
  }

  @override
  int get hashCode => Object.hash(type, number);

  @override
  int compareTo(TrainingItemId other) {
    final typeCompare = type.index.compareTo(other.type.index);
    if (typeCompare != 0) return typeCompare;
    final left = number ?? -1;
    final right = other.number ?? -1;
    return left.compareTo(right);
  }
}
