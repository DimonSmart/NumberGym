import 'package:hive/hive.dart';

class CardProgress {
  final bool learned;
  final List<bool> lastAttempts;
  final int totalAttempts;
  final int totalCorrect;

  const CardProgress({
    required this.learned,
    required this.lastAttempts,
    required this.totalAttempts,
    required this.totalCorrect,
  });

  CardProgress copyWith({
    bool? learned,
    List<bool>? lastAttempts,
    int? totalAttempts,
    int? totalCorrect,
  }) {
    return CardProgress(
      learned: learned ?? this.learned,
      lastAttempts: lastAttempts ?? this.lastAttempts,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      totalCorrect: totalCorrect ?? this.totalCorrect,
    );
  }

  static const CardProgress empty = CardProgress(
    learned: false,
    lastAttempts: <bool>[],
    totalAttempts: 0,
    totalCorrect: 0,
  );
}

class CardProgressAdapter extends TypeAdapter<CardProgress> {
  @override
  final int typeId = 0;

  @override
  CardProgress read(BinaryReader reader) {
    final learned = reader.readBool();
    final attempts = reader.readList().cast<bool>();
    var totalAttempts = attempts.length;
    var totalCorrect = attempts.where((value) => value).length;
    if (reader.availableBytes >= 16) {
      totalAttempts = reader.readInt();
      totalCorrect = reader.readInt();
    }
    if (totalCorrect > totalAttempts) {
      totalCorrect = totalAttempts;
    }
    return CardProgress(
      learned: learned,
      lastAttempts: attempts,
      totalAttempts: totalAttempts,
      totalCorrect: totalCorrect,
    );
  }

  @override
  void write(BinaryWriter writer, CardProgress obj) {
    writer.writeBool(obj.learned);
    writer.writeList(obj.lastAttempts);
    writer.writeInt(obj.totalAttempts);
    writer.writeInt(obj.totalCorrect);
  }
}
