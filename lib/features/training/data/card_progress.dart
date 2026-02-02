import 'package:hive/hive.dart';

class CardCluster {
  final int lastAnswerAt;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;

  const CardCluster({
    required this.lastAnswerAt,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
  });

  int get totalAttempts => correctCount + wrongCount + skippedCount;

  double get accuracy {
    final total = totalAttempts;
    if (total == 0) return 0;
    return correctCount / total;
  }

  CardCluster copyWith({
    int? lastAnswerAt,
    int? correctCount,
    int? wrongCount,
    int? skippedCount,
  }) {
    return CardCluster(
      lastAnswerAt: lastAnswerAt ?? this.lastAnswerAt,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      skippedCount: skippedCount ?? this.skippedCount,
    );
  }
}

class CardProgress {
  final bool learned;
  final List<CardCluster> clusters;
  final double intervalDays;
  final int nextDue;
  final double ease;
  final int spacedSuccessCount;
  final int lastCountedSuccessDay;

  const CardProgress({
    required this.learned,
    required this.clusters,
    required this.intervalDays,
    required this.nextDue,
    required this.ease,
    required this.spacedSuccessCount,
    required this.lastCountedSuccessDay,
  });

  int get totalAttempts =>
      clusters.fold(0, (sum, cluster) => sum + cluster.totalAttempts);

  int get totalCorrect =>
      clusters.fold(0, (sum, cluster) => sum + cluster.correctCount);

  int get totalSkipped =>
      clusters.fold(0, (sum, cluster) => sum + cluster.skippedCount);

  CardCluster? get lastCluster => clusters.isEmpty ? null : clusters.last;

  CardProgress copyWith({
    bool? learned,
    List<CardCluster>? clusters,
    double? intervalDays,
    int? nextDue,
    double? ease,
    int? spacedSuccessCount,
    int? lastCountedSuccessDay,
  }) {
    return CardProgress(
      learned: learned ?? this.learned,
      clusters: clusters ?? this.clusters,
      intervalDays: intervalDays ?? this.intervalDays,
      nextDue: nextDue ?? this.nextDue,
      ease: ease ?? this.ease,
      spacedSuccessCount: spacedSuccessCount ?? this.spacedSuccessCount,
      lastCountedSuccessDay:
          lastCountedSuccessDay ?? this.lastCountedSuccessDay,
    );
  }

  static const CardProgress empty = CardProgress(
    learned: false,
    clusters: <CardCluster>[],
    intervalDays: 0,
    nextDue: 0,
    ease: 0,
    spacedSuccessCount: 0,
    lastCountedSuccessDay: -1,
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
    var intervalDays = CardProgress.empty.intervalDays;
    var nextDue = CardProgress.empty.nextDue;
    var ease = CardProgress.empty.ease;
    var spacedSuccessCount = CardProgress.empty.spacedSuccessCount;
    var lastCountedSuccessDay = CardProgress.empty.lastCountedSuccessDay;
    List<CardCluster> clusters = const [];
    if (reader.availableBytes >= 16) {
      totalAttempts = reader.readInt();
      totalCorrect = reader.readInt();
    }
    if (reader.availableBytes >= 8) {
      intervalDays = reader.readDouble();
    }
    if (reader.availableBytes >= 8) {
      nextDue = reader.readInt();
    }
    if (reader.availableBytes >= 8) {
      ease = reader.readDouble();
    }
    if (reader.availableBytes >= 8) {
      spacedSuccessCount = reader.readInt();
    }
    if (reader.availableBytes >= 8) {
      lastCountedSuccessDay = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      final clusterCount = reader.readInt();
      if (clusterCount > 0) {
        final items = <CardCluster>[];
        for (var i = 0; i < clusterCount; i += 1) {
          final lastAnswerAt = reader.readInt();
          final correctCount = reader.readInt();
          final wrongCount = reader.readInt();
          final skippedCount = reader.readInt();
          items.add(
            CardCluster(
              lastAnswerAt: lastAnswerAt,
              correctCount: correctCount,
              wrongCount: wrongCount,
              skippedCount: skippedCount,
            ),
          );
        }
        clusters = items;
      }
    }
    if (clusters.isEmpty && (totalAttempts > 0 || attempts.isNotEmpty)) {
      if (totalCorrect > totalAttempts) {
        totalCorrect = totalAttempts;
      }
      clusters = <CardCluster>[
        CardCluster(
          lastAnswerAt: 0,
          correctCount: totalCorrect,
          wrongCount: totalAttempts - totalCorrect,
          skippedCount: 0,
        ),
      ];
    }
    return CardProgress(
      learned: learned,
      clusters: clusters,
      intervalDays: intervalDays,
      nextDue: nextDue,
      ease: ease,
      spacedSuccessCount: spacedSuccessCount,
      lastCountedSuccessDay: lastCountedSuccessDay,
    );
  }

  @override
  void write(BinaryWriter writer, CardProgress obj) {
    writer.writeBool(obj.learned);
    writer.writeList(const <bool>[]);
    writer.writeInt(obj.totalAttempts);
    writer.writeInt(obj.totalCorrect);
    writer.writeDouble(obj.intervalDays);
    writer.writeInt(obj.nextDue);
    writer.writeDouble(obj.ease);
    writer.writeInt(obj.spacedSuccessCount);
    writer.writeInt(obj.lastCountedSuccessDay);
    writer.writeInt(obj.clusters.length);
    for (final cluster in obj.clusters) {
      writer.writeInt(cluster.lastAnswerAt);
      writer.writeInt(cluster.correctCount);
      writer.writeInt(cluster.wrongCount);
      writer.writeInt(cluster.skippedCount);
    }
  }
}
